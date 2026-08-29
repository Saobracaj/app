import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/zakon/domain/law_document.dart';
import 'package:saobracaj/zakon/zakon.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository({required this.russianContent})
    : super(GraphqlClient(TokenStorage()), TokenStorage());

  final bool russianContent;

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: {'russian_content': russianContent},
    // russian_content — премиальная фича: без гранта локальный тумблер
    // ничего не включает.
    grants: russianContent ? const {'russian_content'} : const {},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

/// Правилник собирается скриптом tool/parse_pravilnik.py; тесты стерегут
/// целостность собранного: схему строк, адреса членов и сами файлы знаков.
/// JSON читается с диска, а не через rootBundle: большие строки в тестовой
/// среде не возвращаются из `loadString` (см. zakon_page_test.dart).
/// Коды знаков (I-1, II-43.2, …) — одинаковы в обоих языках.
final _signCodeRe = RegExp(r'\b[IVX]{1,3}-\d+(?:\.\d+)*\b');

List<String> _signCodes(String s) =>
    _signCodeRe.allMatches(s).map((m) => m[0]!).toList()..sort();

/// Числа вне кодов знаков: размеры, расстояния, номера статей и пунктов.
List<String> _numbers(String s) =>
    RegExp(r'\d+(?:[.,]\d+)?')
        .allMatches(s.replaceAll(_signCodeRe, ' '))
        .map((m) => m[0]!)
        .toList()
      ..sort();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final rows =
      (jsonDecode(File('assets/parsed_pravilnik.json').readAsStringSync())
              as List)
          .map((e) => BezbParagraph.fromJson(e as Map<String, dynamic>))
          .toList();

  group('parsed_pravilnik.json', () {
    test('строки разбираются в модель закона и содержат все 121 член', () {
      expect(rows, isNotEmpty);
      final chlans = rows
          .where((r) => r.paragraph == '0')
          .map((r) => r.chlan)
          .toList();
      expect(chlans.length, 121);
      // Члены идут подряд с 1 по 121 — потерянный заголовок «Члан N.» ломает
      // и оглавление, и ссылки на членов.
      expect(chlans, List.generate(121, (i) => '${i + 1}'));
    });

    test('у каждого члана абзацы нумеруются подряд с 1', () {
      final byChlan = <String, List<int>>{};
      for (final r in rows) {
        if (r.chlan == null || r.paragraph == null || r.paragraph == '0') {
          continue;
        }
        byChlan.putIfAbsent(r.chlan!, () => []).add(int.parse(r.paragraph!));
      }
      for (final entry in byChlan.entries) {
        expect(
          entry.value,
          List.generate(entry.value.length, (i) => i + 1),
          reason: 'члан ${entry.key}',
        );
      }
    });

    test('каждая ссылка на изображение указывает на существующий ассет', () {
      final images = rows.expand((r) => r.images).toSet();
      expect(images, isNotEmpty);
      for (final image in images) {
        // Официальные знаки — из общего с конспектами assets/signs/ (их
        // подставляет дедупликация в tool/parse_pravilnik.py), остальное —
        // извлечённое из docx.
        expect(
          image.src,
          anyOf(startsWith('assets/pravilnik/'), startsWith('assets/signs/')),
        );
        expect(File(image.src).existsSync(), isTrue, reason: image.src);
        // Размер страницы docx обязателен: официальные SVG в собственных
        // координатах огромны и без него раздули бы колонку.
        expect(image.w, greaterThan(0), reason: image.src);
        expect(image.h, greaterThan(0), reason: image.src);
      }
      // И обратно: в assets/pravilnik нет файлов, на которые никто не ссылается.
      final onDisk = Directory('assets/pravilnik')
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .toSet();
      expect(
        onDisk,
        images
            .map((i) => i.src)
            .where((s) => s.startsWith('assets/pravilnik/'))
            .toSet(),
      );
    });

    test('знак с официальным SVG показывается из assets/signs', () {
      // Дедупликация: у знака один файл на всё приложение — извлечённой из
      // docx копии I-1 (первого знака правилника) быть не должно.
      final srcs = rows.expand((r) => r.images).map((i) => i.src).toSet();
      expect(srcs, contains('assets/signs/i-1.svg'));
      expect(srcs, contains('assets/signs/ii-2.svg'));
    });

    test('у каждой строки есть русский перевод с той же разметкой', () {
      // Перевод собран tool/pravilnik_ru/merge_ru.py; пустой или потерявший
      // жирность ru ломает режим «РУ» — стережём весь файл.
      for (final r in rows) {
        final sr = r.sr ?? '';
        final ru = r.ru ?? '';
        // Строки-контейнеры для картинок текста не несут ни на одном языке.
        if (sr.trim().isEmpty) {
          expect(ru.trim(), isEmpty);
          continue;
        }
        expect(ru.trim(), isNotEmpty, reason: sr);
        expect(
          '**'.allMatches(ru).length,
          '**'.allMatches(sr).length,
          reason: sr,
        );
        // Коды знаков и числа (размеры, расстояния, номера статей) перевод
        // обязан донести один в один — это ссылки на сам документ.
        expect(_signCodes(ru), _signCodes(sr), reason: sr);
        expect(_numbers(ru), _numbers(sr), reason: sr);
      }
    });

    test('знаки в главе о знаках опасности действительно с изображениями', () {
      // Члан 13 перечисляет знаки опасности — у него обязаны быть векторные
      // изображения (первые знаки правилника, I-1 и далее).
      final withImages = rows
          .where((r) => r.chlan == '13' && r.images.isNotEmpty)
          .toList();
      expect(withImages, isNotEmpty);
      expect(withImages.first.images.first.src, endsWith('.svg'));
    });
  });

  test('каждый SVG правилника разбирается flutter_svg без ошибок', () async {
    final svgs = Directory('assets/pravilnik')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.svg'))
        .toList();
    expect(svgs, isNotEmpty);
    for (final f in svgs) {
      final info = await vg.loadPicture(
        SvgStringLoader(f.readAsStringSync()),
        null,
      );
      expect(info.size.width, greaterThan(0), reason: f.path);
      expect(info.size.height, greaterThan(0), reason: f.path);
      info.picture.dispose();
    }
  });

  group('экран правилника', () {
    setUpAll(() async {
      await EasyLocalization.ensureInitialized();
      // Прогреваем источник данных: внутри widget-теста ассет из rootBundle
      // не дочитывается (фейковый event loop), и список остаётся пустым.
      await pravilnikDataSource.paragraphs;
    });

    Widget wrap(Widget child, {bool russianContent = false}) {
      final flags = FeatureFlagsBloc(
        _StubFeatureFlagsRepository(russianContent: russianContent),
      );
      return EasyLocalization(
        useOnlyLangCode: true,
        ignorePluralRules: false,
        supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
        fallbackLocale: const Locale('ru'),
        startLocale: const Locale('ru'),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: const CodegenLoader(),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: BlocProvider.value(value: flags, child: child),
          ),
        ),
      );
    }

    testWidgets('без russian_content открывается по-сербски и без «РУ»', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(const Zakon(document: LawDocument.pravilnik)),
      );
      await tester.pumpAndSettle();

      expect(find.text('ПРАВИЛНИК о саобраћајној сигнализацији'), findsOneWidget);
      // Шапка документа — обычный Text: markdown-звёздочки в ней не должны
      // просачиваться на экран.
      expect(find.text('ПРАВИЛНИК'), findsOneWidget);
      // Кнопка «РУ» стоит за фича-флагом russian_content — без него её нет.
      expect(find.text('РУ'), findsNothing);
    });

    testWidgets('с russian_content кнопка «РУ» переключает на перевод', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          const Zakon(document: LawDocument.pravilnik),
          russianContent: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('РУ'), findsOneWidget);
      // До переключения — сербский текст вводной строки.
      expect(
        find.textContaining('На основу члана', findRichText: true),
        findsWidgets,
      );

      await tester.tap(find.text('РУ'));
      await tester.pumpAndSettle();

      // После переключения та же строка показана по-русски.
      expect(
        find.textContaining('На основании статьи', findRichText: true),
        findsWidgets,
      );
      expect(
        find.textContaining('На основу члана', findRichText: true),
        findsNothing,
      );
    });
  });
}
