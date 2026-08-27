import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/test/animations/interactive_animation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Обёртка `InteractiveAnimation`: пауза/продолжение и переключение кадров.
///
/// Сцена в тестах — пустой квадрат: проверяется не рисование, а управление
/// временем — то, ради чего обёртка и существует.

Widget _host(Widget child) => EasyLocalization(
      useOnlyLangCode: true,
      ignorePluralRules: false,
      supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
      fallbackLocale: const Locale('ru'),
      startLocale: const Locale('ru'),
      path: 'assets/translations',
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );

const _sceneKey = Key('scene');

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('кнопка ставит анимацию на паузу и продолжает с того же места',
      (tester) async {
    late Animation<double> animation;
    await tester.pumpWidget(_host(InteractiveAnimation(
      cycle: const Duration(seconds: 1),
      builder: (context, a) {
        animation = a;
        return const SizedBox(key: _sceneKey, width: 100, height: 100);
      },
    )));
    // Первый кадр строит приложение (EasyLocalization асинхронный), второй —
    // базовый кадр тикера (elapsed = 0), движение видно со следующего.
    await tester.pump();
    final before = animation.value;
    await tester.pump(const Duration(milliseconds: 100));
    expect(animation.value, isNot(before), reason: 'анимация должна идти');

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    final paused = animation.value;
    await tester.pump(const Duration(milliseconds: 300));
    expect(animation.value, paused, reason: 'на паузе время не идёт');

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(); // базовый кадр нового тикера
    await tester.pump(const Duration(milliseconds: 100));
    expect(animation.value, isNot(paused), reason: 'после ▶ анимация идёт');
  });

  testWidgets('тап по самой сцене — тоже пауза', (tester) async {
    late Animation<double> animation;
    await tester.pumpWidget(_host(InteractiveAnimation(
      cycle: const Duration(seconds: 1),
      builder: (context, a) {
        animation = a;
        return const SizedBox(key: _sceneKey, width: 100, height: 100);
      },
    )));
    await tester.pump();
    await tester.tap(find.byKey(_sceneKey));
    await tester.pump();
    final paused = animation.value;
    await tester.pump(const Duration(milliseconds: 300));
    expect(animation.value, paused);
  });

  testWidgets('номер кадра проигрывает кадр и замирает в его конце',
      (tester) async {
    late Animation<double> animation;
    await tester.pumpWidget(_host(InteractiveAnimation(
      cycle: const Duration(seconds: 1),
      stepStarts: const [0, 0.5],
      builder: (context, a) {
        animation = a;
        return const SizedBox(key: _sceneKey, width: 100, height: 100);
      },
    )));
    await tester.pump();

    await tester.tap(find.text('2'));
    await tester.pump();
    expect(animation.value, moreOrLessEquals(0.5, epsilon: 0.01),
        reason: 'кадр начинается с его начала');

    // Кадр играет с обычной скоростью…
    await tester.pump(const Duration(milliseconds: 250));
    expect(animation.value, moreOrLessEquals(0.75, epsilon: 0.02));

    // …и замирает в конце, не перескакивая на следующий цикл.
    await tester.pump(const Duration(milliseconds: 500));
    final held = animation.value;
    expect(held, moreOrLessEquals(0.999, epsilon: 0.01));
    await tester.pump(const Duration(milliseconds: 300));
    expect(animation.value, held);

    // Обёртка при этом в состоянии паузы — кнопка предлагает продолжить.
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('pauseOnly глушит тикеры сцены через TickerMode',
      (tester) async {
    await tester.pumpWidget(_host(const InteractiveAnimation.pauseOnly(
      child: SizedBox(key: _sceneKey, width: 100, height: 100),
    )));
    await tester.pump();

    TickerMode mode() => tester.widget<TickerMode>(find.ancestor(
          of: find.byKey(_sceneKey),
          matching: find.byType(TickerMode),
        ).first);
    expect(mode().enabled, isTrue);

    await tester.tap(find.byKey(_sceneKey));
    await tester.pump();
    expect(mode().enabled, isFalse);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(mode().enabled, isTrue);
  });
}
