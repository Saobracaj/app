// Одноразовый превью-рендер просмотрщика дорожного знака в PNG (не тест):
//   flutter test tool/preview_road_sign_test.dart
// Скриншоты: build/road_sign_preview/*.png
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
import 'package:saobracaj/zakon/domain/road_sign_index.dart';
import 'package:saobracaj/zakon/presentation/road_sign_viewer.dart';
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
    Directory('build/road_sign_preview').createSync(recursive: true);
  });

  // ignore: invalid_use_of_visible_for_testing_member
  setUp(RoadSignIndex.reset);

  for (final (name, sign, ru) in [
    ('ii-2', 'ii-2', false),
    ('i-1_ru', 'i-1', true),
    ('iv-1', 'iv-1', false),
    ('iii-11-2017', 'iii-11-2017', false),
    ('iii-28', 'iii-28', false),
    ('iv-5', 'iv-5', false),
    ('ii-45.2', 'ii-45.2', false),
    ('iii-53', 'iii-53', false),
  ]) {
    testWidgets('превью просмотрщика знака $name', (tester) async {
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
            builder: (context) => BlocProvider.value(
              value: flags,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: RepaintBoundary(
                  key: const ValueKey('shot'),
                  child: RoadSignViewer(sign: sign, onOpenPravilnik: (_) {}),
                ),
              ),
            ),
          ),
        ),
      );
      // Реальные кадры: SVG декодируются асинхронно.
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
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
      File('build/road_sign_preview/$name.png')
          .writeAsBytesSync(image!.buffer.asUint8List(), flush: true);
      // ignore: avoid_print
      print('PREVIEW build/road_sign_preview/$name.png');
    });
  }
}
