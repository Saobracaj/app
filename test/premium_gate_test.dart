import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';

/// Гейт — свойство ВОПРОСА, а не экрана: премиум-контент доступен, если
/// категория вопроса бесплатная (25/26/28) либо у пользователя активна
/// подписка. Ровно то же правило действует на бэкенде.
void main() {
  FeatureFlagsSnapshot snapshot({
    Set<String> grants = const {},
    Map<String, bool> locals = const {},
    bool authenticated = true,
  }) => FeatureFlagsSnapshot.resolve(
    localOverrides: locals,
    grants: grants,
    authenticated: authenticated,
  );

  test('бесплатные категории — ровно 25, 26 и 28', () {
    expect(isFreeCategory('25'), isTrue);
    expect(isFreeCategory('26'), isTrue);
    expect(isFreeCategory('28'), isTrue);
    // 27 «Трајање управљања» платная — список не сплошной.
    expect(isFreeCategory('27'), isFalse);
    expect(isFreeCategory(null), isFalse);
  });

  test(
    'без подписки контент открыт в бесплатной категории и закрыт в платной',
    () {
      final flags = snapshot();
      for (final feature in [
        AppFeature.questionComments,
        AppFeature.categorySummaries,
        AppFeature.questionAnalysis,
        AppFeature.russianContent,
      ]) {
        expect(
          flags.isEnabledForCategory(feature, '26'),
          isTrue,
          reason: '${feature.key} должен быть открыт в бесплатной категории',
        );
        expect(
          flags.isEnabledForCategory(feature, '27'),
          isFalse,
          reason: '${feature.key} должен быть закрыт в платной категории',
        );
      }
    },
  );

  test('подписка открывает контент в любой категории', () {
    final flags = snapshot(
      grants: {AppFeature.questionAnalysis.key, AppFeature.askAi.key},
    );
    expect(
      flags.isEnabledForCategory(AppFeature.questionAnalysis, '27'),
      isTrue,
    );
    expect(flags.isEnabledForCategory(AppFeature.askAi, '27'), isTrue);
  });

  test('у AI-чата демо-режима нет даже в бесплатной категории', () {
    expect(snapshot().isEnabledForCategory(AppFeature.askAi, '25'), isFalse);
  });

  // Заперто ≠ выключено: запертая вкладка остаётся на экране с превью и
  // предложением пропуска, выключенная исчезает.
  test(
    'без подписки премиум-контент в платной категории заперт, а не выключен',
    () {
      final flags = snapshot();
      expect(
        flags.isLockedForCategory(AppFeature.questionComments, '27'),
        isTrue,
      );
      expect(
        flags.isLockedForCategory(AppFeature.questionComments, '25'),
        isFalse,
      );
      // AI заперт везде: демо-режима у него нет.
      expect(flags.isLockedForCategory(AppFeature.askAi, '25'), isTrue);
      // Не премиум — не запирается, каким бы ни был тир.
      expect(flags.isLockedForCategory(AppFeature.groups, '27'), isFalse);
    },
  );

  test('подписка снимает замок, а локальный тумблер его не ставит', () {
    final granted = snapshot(grants: {AppFeature.questionComments.key});
    expect(
      granted.isLockedForCategory(AppFeature.questionComments, '27'),
      isFalse,
    );
    final off = snapshot(locals: {AppFeature.questionComments.key: false});
    expect(off.isLockedForCategory(AppFeature.questionComments, '27'), isFalse);
    expect(
      off.isEnabledForCategory(AppFeature.questionComments, '27'),
      isFalse,
    );
  });

  test('гостю премиум-контент заперт — пейволл зовёт войти и оформить', () {
    final guest = snapshot(authenticated: false);
    expect(guest.isLockedForCategory(AppFeature.russianContent, '30'), isTrue);
  });

  test('локальный тумблер выключает контент и в бесплатной категории', () {
    final flags = snapshot(locals: {AppFeature.russianContent.key: false});
    expect(
      flags.isEnabledForCategory(AppFeature.russianContent, '25'),
      isFalse,
    );
  });

  test('гостю бесплатная категория не выдаёт то, что требует входа', () {
    final flags = snapshot(authenticated: false);
    // groups — тир «нужен вход», а не премиум: бесплатная категория его не
    // открывает.
    expect(flags.isEnabledForCategory(AppFeature.groups, '25'), isFalse);
    // А списки вопросов бесплатны всем и без лимита.
    expect(flags.isEnabled(AppFeature.customQuestionLists), isTrue);
  });

  test('обсуждение вопроса гость читает в любой категории', () {
    final flags = snapshot(authenticated: false);
    // Тир guest: вкладка видна и без входа — писать не даст сам экран
    // (композер заменяется приглашением войти) и RequireAuth на бэкенде.
    for (final category in ['25', '27']) {
      expect(
        flags.isEnabledForCategory(AppFeature.publicQuestionComments, category),
        isTrue,
        reason: 'обсуждение открыто гостю в категории $category',
      );
    }
  });
}
