// Одноразовый превью-рендер экрана правилника в PNG (не тест поведения):
//   flutter test tool/preview_pravilnik_test.dart
// Скриншоты: build/pravilnik_preview/*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  _StubFeatureFlagsRepository({this.russianContent = false})
    : super(GraphqlClient(TokenStorage()), TokenStorage());

  final bool russianContent;

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: {'russian_content': russianContent},
    grants: russianContent ? const {'russian_content'} : const {},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

Future<void> _loadFonts() async {
  final data = File('assets/fonts/Inter-400.ttf').readAsBytesSync();
  final bold = File('assets/fonts/Inter-700.ttf').readAsBytesSync();
  for (final family in ['Inter', 'Roboto', 'FlutterTest', 'Ahem']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(data)))
      ..addFont(Future.value(ByteData.sublistView(bold)));
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await _loadFonts();
    Directory('build/pravilnik_preview').createSync(recursive: true);
  });

  for (final (name, chlan, paragraph, ru) in [
    ('chlan104', '104', null, false),
    ('chlan48', '48', null, false),
    ('chlan13', '13', '2', false),
    ('chlan20_znak43', '20', '19', false),
    ('chlan13_ru', '13', null, true),
    ('chlan26_ru', '26', null, true),
    ('chlan104_ru', '104', null, true),
  ]) {
    testWidgets('превью правилника $name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Данные читаются заранее в настоящем async: rootBundle.loadString
      // больших файлов не возвращается в fake async тестовой среды.
      await tester.runAsync(() => pravilnikDataSource.paragraphs);

      final flags = FeatureFlagsBloc(
        _StubFeatureFlagsRepository(russianContent: ru),
      );
      await tester.pumpWidget(
        EasyLocalization(
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
              debugShowCheckedModeBanner: false,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: BlocProvider.value(
                value: flags,
                child: RepaintBoundary(
                  key: const ValueKey('shot'),
                  child: Zakon(
                    document: LawDocument.pravilnik,
                    chlan: chlan,
                    paragraph: paragraph,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // Реальные кадры: SVG декодируются асинхронно.
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (ru) {
        await tester.tap(find.text('РУ'));
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('shot')),
      );
      final image = await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 2);
        return img.toByteData(format: ui.ImageByteFormat.png);
      });
      File('build/pravilnik_preview/$name.png')
          .writeAsBytesSync(image!.buffer.asUint8List(), flush: true);
      // ignore: avoid_print
      print('PREVIEW build/pravilnik_preview/$name.png');
    });
  }
}
