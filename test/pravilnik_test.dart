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
  _StubFeatureFlagsRepository()
    : super(GraphqlClient(TokenStorage()), TokenStorage());

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: const {'russian_content': false},
    grants: const {},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

/// Правилник собирается скриптом tool/parse_pravilnik.py; тесты стерегут
/// целостность собранного: схему строк, адреса членов и сами файлы знаков.
/// JSON читается с диска, а не через rootBundle: большие строки в тестовой
/// среде не возвращаются из `loadString` (см. zakon_page_test.dart).
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
      for (final path in images) {
        expect(path, startsWith('assets/pravilnik/'));
        expect(File(path).existsSync(), isTrue, reason: path);
      }
      // И обратно: в assets/pravilnik нет файлов, на которые никто не ссылается.
      final onDisk = Directory('assets/pravilnik')
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .toSet();
      expect(onDisk, images);
    });

    test('знаки в главе о знаках опасности действительно с изображениями', () {
      // Члан 13 перечисляет знаки опасности — у него обязаны быть векторные
      // изображения (первые знаки правилника, I-1 и далее).
      final withImages = rows
          .where((r) => r.chlan == '13' && r.images.isNotEmpty)
          .toList();
      expect(withImages, isNotEmpty);
      expect(withImages.first.images.first, endsWith('.svg'));
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
    });

    Widget wrap(Widget child) {
      final flags = FeatureFlagsBloc(_StubFeatureFlagsRepository());
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

    testWidgets('открывается с заголовком правилника и без кнопки «РУ»', (
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
      // У правилника нет русского перевода — переключателя быть не должно.
      expect(find.text('РУ'), findsNothing);
    });
  });
}
