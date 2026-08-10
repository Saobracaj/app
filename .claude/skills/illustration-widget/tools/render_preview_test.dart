// Рендерит иллюстрацию/анимацию из animations_map.dart в PNG-файлы, чтобы её
// можно было посмотреть глазами, не запуская приложение.
//
// Это не тест поведения: он всегда зелёный, его результат — картинки.
//
//   SLUG=kategorije-stablo \
//   flutter test .claude/skills/illustration-widget/tools/render_preview_test.dart
//
// Переменные окружения:
//   SLUG    — ключ в animations_map.dart (обязательно)
//   FRAMES  — моменты времени в мс через запятую (по умолчанию 0 —
//             для анимации имеет смысл 0,1500,3000,4500)
//   THEMES  — light,dark (по умолчанию обе)
//   OUT     — каталог для PNG (по умолчанию build/illustration_preview)
//   WIDTH   — ширина поверхности в логических пикселях (по умолчанию 390)
//   HEIGHT  — высота поверхности (по умолчанию 844)
//   LOCALE  — ru|sr|en (по умолчанию ru)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/test/animations/animations_map.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _env(String key, String fallback) {
  final value = Platform.environment[key];
  return (value == null || value.trim().isEmpty) ? fallback : value.trim();
}

const _boundaryKey = ValueKey('illustration-preview-boundary');

/// Настоящий шрифт вместо тестовой заглушки с квадратными глифами: иначе на
/// картинке не прочитать ни одной подписи.
Future<void> _loadFonts() async {
  final data = File('assets/fonts/Inter-400.ttf').readAsBytesSync();
  final bold = File('assets/fonts/Inter-700.ttf').readAsBytesSync();
  // Inter — шрифт темы. Остальные имена — те, под которыми в тестовой среде
  // живёт шрифт по умолчанию: им рисует TextPainter, когда стиль не задаёт
  // fontFamily (типично для CustomPainter).
  for (final family in [
    'Inter',
    'Roboto',
    'FlutterTest',
    'Ahem',
    '.SF UI Text',
    '.SF UI Display',
  ]) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(data)))
      ..addFont(Future.value(ByteData.sublistView(bold)));
    await loader.load();
  }
}

Widget _app({
  required Widget child,
  required Brightness brightness,
  required Locale locale,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: brightness,
  );
  return EasyLocalization(
    key: ValueKey('$locale-$brightness'),
    useOnlyLangCode: true,
    // Сербские правила множественного числа ломают easy_localization в тестах.
    ignorePluralRules: false,
    supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
    fallbackLocale: const Locale('ru'),
    startLocale: locale,
    saveLocale: false,
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: buildAppTheme(scheme),
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              child: RepaintBoundary(
                key: _boundaryKey,
                // Фон экрана внутри снимка: иначе тёмная тема выходит на
                // прозрачном (в просмотрщике — белом) фоне.
                child: ColoredBox(
                  color: scheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  final slug = _env('SLUG', '');
  final outDir = _env('OUT', 'build/illustration_preview');
  final frames = _env('FRAMES', '0')
      .split(',')
      .map((it) => int.parse(it.trim()))
      .toList();
  final themes = _env('THEMES', 'light,dark')
      .split(',')
      .map((it) => it.trim())
      .where((it) => it.isNotEmpty)
      .toList();
  final locale = Locale(_env('LOCALE', 'ru'));
  final size = Size(
    double.parse(_env('WIDTH', '390')),
    double.parse(_env('HEIGHT', '844')),
  );

  setUpAll(() async {
    // Файл лежит вне test/, поэтому анализатор не считает его тестом и ругается
    // на тестовое API — здесь это ровно оно и есть.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await _loadFonts();
    Directory(outDir).createSync(recursive: true);
  });

  // Каждая тема — отдельный тест: повторный монтаж EasyLocalization в одном
  // тесте зависает на загрузке делегата.
  for (final theme in themes) {
    testWidgets('$slug · $theme', (tester) async {
      expect(slug, isNotEmpty, reason: 'не задана переменная окружения SLUG');

      final brightness = theme == 'dark' ? Brightness.dark : Brightness.light;
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _app(
          child: getAnimation(slug),
          brightness: brightness,
          locale: locale,
        ),
      );
      // Несколько кадров вместо pumpAndSettle: у бесконечной анимации
      // pumpAndSettle никогда не завершится.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      var elapsed = 80;
      for (final frame in frames) {
        if (frame > elapsed) {
          await tester.pump(Duration(milliseconds: frame - elapsed));
          elapsed = frame;
        }
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_boundaryKey),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final name = frames.length == 1
            ? '$slug-$theme.png'
            : '$slug-$theme-${frame}ms.png';
        File('$outDir/$name')
            .writeAsBytesSync(bytes!.buffer.asUint8List(), flush: true);
        // ignore: avoid_print
        print('PREVIEW $outDir/$name');
      }

      expect(tester.takeException(), isNull);
    });
  }
}
