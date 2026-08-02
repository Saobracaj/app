/// The product feature catalog, mirrored from the backend
/// (`saobracaj_backend/src/feature_flags/model.rs`) — see the repo-root
/// `FEATURE_FLAGS.md` for the authoritative table.
///
/// Every feature is gated by an [FeatureAccess] tier *and* an optional local
/// on/off toggle stored in shared preferences. Keys are stable strings shared
/// verbatim with the backend — never rename one without migrating both sides.
library;

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
  publicQuestionComments(
    'public_question_comments',
    FeatureAccess.authenticated,
  ),
  questionAnalysis('question_analysis', FeatureAccess.premium),
  askAi('ask_ai', FeatureAccess.premium),
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
  // 8. Question lists
  autoQuestionLists('auto_question_lists', FeatureAccess.guest),
  customQuestionLists('custom_question_lists', FeatureAccess.premium),
  // 9. Support chat
  supportChat('support_chat', FeatureAccess.authenticated),
  // Standalone option: Russian materials & translations.
  russianContent('russian_content', FeatureAccess.premium);

  const AppFeature(this.key, this.access);

  /// Stable identifier shared with the backend.
  final String key;

  /// The tier that gates this feature.
  final FeatureAccess access;

  /// The catalog entry with this [key], or `null` if unknown (e.g. a key the
  /// backend added that this client build doesn't know yet).
  static AppFeature? fromKey(String key) {
    for (final f in AppFeature.values) {
      if (f.key == key) return f;
    }
    return null;
  }
}
