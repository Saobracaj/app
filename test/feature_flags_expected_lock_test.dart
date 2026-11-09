import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';

/// `expectsLockedContent` — предсказание того, что бэкенд ответит про замок
/// на платном контенте: по нему репозиторий замечает, что кэш грантов отстал.
void main() {
  FeatureFlagsSnapshot snapshot({
    Set<String> grants = const {},
    bool authenticated = true,
    Map<String, bool> locals = const {},
  }) => FeatureFlagsSnapshot.resolve(
    localOverrides: locals,
    grants: grants,
    authenticated: authenticated,
  );

  test('без гранта в платной категории ждём превью', () {
    expect(
      snapshot().expectsLockedContent(AppFeature.categorySummaries, '30'),
      isTrue,
    );
    // Гость — тем более.
    expect(
      snapshot(
        authenticated: false,
      ).expectsLockedContent(AppFeature.questionComments, '30'),
      isTrue,
    );
  });

  test('с грантом ждём полный текст', () {
    expect(
      snapshot(
        grants: {'category_summaries'},
      ).expectsLockedContent(AppFeature.categorySummaries, '30'),
      isFalse,
    );
    // Грант без сессии бэкенд не применит.
    expect(
      snapshot(
        grants: {'category_summaries'},
        authenticated: false,
      ).expectsLockedContent(AppFeature.categorySummaries, '30'),
      isTrue,
    );
  });

  test('бесплатные категории открыты всем', () {
    for (final category in freeCategoryIds) {
      expect(
        snapshot(
          authenticated: false,
        ).expectsLockedContent(AppFeature.questionComments, category),
        isFalse,
        reason: category,
      );
    }
  });

  test('локальный тумблер на предсказание не влияет — сервер о нём не знает', () {
    final s = snapshot(
      grants: {'category_summaries'},
      locals: {AppFeature.categorySummaries.key: false},
    );
    // Для экрана функция заперта не считается (выключена), а бэкенд всё равно
    // отдаст полный текст — и это не расхождение.
    expect(s.isLockedForCategory(AppFeature.categorySummaries, '30'), isFalse);
    expect(s.expectsLockedContent(AppFeature.categorySummaries, '30'), isFalse);
  });

  test('непремиальная функция замка не имеет', () {
    expect(
      snapshot(
        authenticated: false,
      ).expectsLockedContent(AppFeature.publicQuestionComments, '30'),
      isFalse,
    );
  });
}
