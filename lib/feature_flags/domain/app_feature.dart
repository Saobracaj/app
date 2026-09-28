/// The product feature catalog, mirrored from the backend
/// (`saobracaj_backend/src/feature_flags/model.rs`) — see the repo-root
/// `FEATURE_FLAGS.md` for the authoritative table.
///
/// Every feature is gated by an [FeatureAccess] tier *and* an optional local
/// on/off toggle stored in shared preferences. Keys are stable strings shared
/// verbatim with the backend — never rename one without migrating both sides.
library;

/// Question categories that are open to everybody in full — explanations,
/// konspekts, analytics, key phrases and the Russian content alike. Mirrors
/// `FREE_CATEGORY_IDS` in `saobracaj_backend/src/billing/model.rs`; the server
/// enforces the same rule, this list only keeps the UI from offering a lock
/// where there is none.
///
/// Deliberately **not** "the first three": 27 («Трајање управљања») is paid.
const freeCategoryIds = <String>{'25', '26', '28'};

/// Whether premium content attached to a question of [categoryId] is free for
/// everybody. Unknown/absent category → not free (fall back to the flag).
bool isFreeCategory(String? categoryId) =>
    categoryId != null && freeCategoryIds.contains(categoryId.trim());

/// How many times the «РУ» translation of a question from a *paid* category
/// opens for free before the toggle starts leading to the paywall. A taste of
/// the feature rather than a demo mode: each switch-on on a locked question
/// spends one, the count is kept on the device
/// (`FeatureFlagsRepository.consumeRussianTranslationTrial`).
const russianTranslationTrialUses = 3;

/// How a feature becomes available to the user.
enum FeatureAccess {
  /// Available to everyone, even signed-out guests.
  guest,

  /// Available to any signed-in user.
  authenticated,

  /// Available to a signed-in user only when the backend granted it
  /// (subscription/entitlement).
  premium,
}

/// A product feature. `key` matches the backend catalog entry; `access` is the
/// tier that gates it.
enum AppFeature {
  // 1. Statistics
  individualQuestionStats('individual_question_stats', FeatureAccess.guest),
  aggregateQuestionStats('aggregate_question_stats', FeatureAccess.guest),
  // 2. Per-question features
  questionComments('question_comments', FeatureAccess.premium),
  // Гостевой тир: обсуждение вопроса читают все, в том числе без входа;
  // писать и ставить реакции гость всё равно не может — композер заменяется
  // приглашением войти, а бэкенд держит записи за RequireAuth.
  publicQuestionComments('public_question_comments', FeatureAccess.guest),
  questionAnalysis('question_analysis', FeatureAccess.premium),
  // The live AI chat is the one premium feature the free categories do *not*
  // open: it is the only function with a variable cost per message, so it has
  // no demo mode (`freeInFreeCategories: false`).
  askAi('ask_ai', FeatureAccess.premium, freeInFreeCategories: false),
  lawDefinitionsHighlight('law_definitions_highlight', FeatureAccess.guest),
  questionFeedback('question_feedback', FeatureAccess.guest),
  // 3. Category summaries ("Конспекты")
  categorySummaries('category_summaries', FeatureAccess.premium),
  // 4. Groups
  groups('groups', FeatureAccess.authenticated),
  // 5. Search
  questionSearch('question_search', FeatureAccess.guest),
  // 6/7. Sharing
  shareQuestion('share_question', FeatureAccess.guest),
  shareMultipleQuestions('share_multiple_questions', FeatureAccess.guest),
  // 8. Question lists — free for everybody and without a count limit.
  autoQuestionLists('auto_question_lists', FeatureAccess.guest),
  customQuestionLists('custom_question_lists', FeatureAccess.guest),
  // 9. Support chat
  supportChat('support_chat', FeatureAccess.authenticated),
  // Standalone option: Russian materials & translations.
  russianContent('russian_content', FeatureAccess.premium),
  // 10. Home-screen cards. Every one of them is built from what the device
  // already holds (the local answer history, the bundled question bank and
  // its exam blueprint, the road-sign index), so they are guest-tier and
  // **client-only**: the backend catalog does not list them and nothing has
  // to be granted. Each card is its own flag so the operator — and the user,
  // on the «Функции» screen — can switch them one by one.
  homeReadiness('home_readiness', FeatureAccess.guest, homeCard: true),
  homeExamTrend('home_exam_trend', FeatureAccess.guest, homeCard: true),
  homeActivity('home_activity', FeatureAccess.guest, homeCard: true),
  homeWeakTopics('home_weak_topics', FeatureAccess.guest, homeCard: true),
  homeCategoryCoverage(
    'home_category_coverage',
    FeatureAccess.guest,
    homeCard: true,
  ),
  homeDailyQuestion('home_daily_question', FeatureAccess.guest, homeCard: true),
  homeExamCountdown('home_exam_countdown', FeatureAccess.guest, homeCard: true),
  homeDailySign('home_daily_sign', FeatureAccess.guest, homeCard: true),
  homeContinueKonspekt(
    'home_continue_konspekt',
    FeatureAccess.guest,
    homeCard: true,
  ),
  homeSummary('home_summary', FeatureAccess.guest, homeCard: true);

  const AppFeature(
    this.key,
    this.access, {
    this.freeInFreeCategories = true,
    this.homeCard = false,
  });

  /// Stable identifier shared with the backend.
  final String key;

  /// The tier that gates this feature.
  final FeatureAccess access;

  /// Whether a question from one of the [freeCategoryIds] unlocks this feature
  /// for everybody. True for the content features (explanation, konspekt,
  /// analysis, Russian materials); false for the live AI chat.
  final bool freeInFreeCategories;

  /// Whether this feature is one of the home-screen cards (listed in their own
  /// section of the «Функции» screen, rendered by `HomeInsightsSection`).
  final bool homeCard;

  /// The home-screen cards in the order they stand on the screen.
  static List<AppFeature> get homeCards =>
      values.where((f) => f.homeCard).toList();

  /// The catalog entry with this [key], or `null` if unknown (e.g. a key the
  /// backend added that this client build doesn't know yet).
  static AppFeature? fromKey(String key) {
    for (final f in AppFeature.values) {
      if (f.key == key) return f;
    }
    return null;
  }
}
