import 'package:injectable/injectable.dart';

import '../di.dart';
import 'analytics_event_sink.dart';
import 'screen_name.dart';

/// The app-wide [AnalyticsService], for the places that live outside the DI
/// graph (the hand-built blocs and globals in `lib/db/dependencies.dart`).
/// Injectable code should take the service through its constructor instead.
///
/// Falls back to a detached instance when the DI container is empty — widget
/// tests build blocs without `configureDependencies()`, and analytics must
/// never be the reason a screen cannot be constructed.
AnalyticsService get analytics => getIt.isRegistered<AnalyticsService>()
    ? getIt<AnalyticsService>()
    : _fallback;
final AnalyticsService _fallback = AnalyticsService();

/// Usage analytics, reported to **PostHog** (EU cloud) — the single sink, at
/// the operator's request; Firebase Analytics and the backend journal are gone.
///
/// Every call is fire-and-forget and fail-soft: analytics must never break a
/// user-facing flow. Without a sink attached (tests, and the app before
/// `main()` wires one) every event is silently dropped.
@lazySingleton
class AnalyticsService {
  String? _lastScreen;
  AnalyticsEventSink? _sink;

  /// Point the pipeline at PostHog. Called once from `main()`, after DI is
  /// configured.
  void attachSink(AnalyticsEventSink sink) => _sink = sink;

  /// Ties every following event to the signed-in backend account and merges
  /// the install's guest history into that person (`$identify`). `null` on
  /// sign-out: a guest's events stay device-scoped.
  void setUser({String? id, String? email}) {
    if (id == null) {
      _sink?.clearUser();
      _sink?.flush();
    } else {
      _sink?.identify(id, set: {'email': ?email});
    }
  }

  /// The user is now looking at question [questionId] — fired for the first
  /// question of a run and on every page change within it.
  void logQuestionViewed({required int questionId}) =>
      _track('question_viewed', {'question_id': questionId});

  /// A feature tab under the question was opened by hand; [tab] is the
  /// [AppFeature] key (`public_question_comments`, `category_summaries`, …).
  void logQuestionTabOpened({required String tab, int? questionId}) =>
      _track('question_tab_opened', {
        'tab': tab,
        'question_id': ?questionId,
      });

  /// The user scrolled the question page down to the feature tabs (the phone
  /// layout; on the wide screen the tabs are always on screen). Once per
  /// question shown.
  void logQuestionTabsViewed({int? questionId}) =>
      _track('question_tabs_viewed', {'question_id': ?questionId});

  /// An answer was given; [secondsSinceShown] counts from the moment the
  /// question appeared on screen.
  void logQuestionAnswered({
    required int questionId,
    required bool correct,
    int? secondsSinceShown,
  }) => _track('question_answered', {
    'question_id': questionId,
    'correct': correct,
    'seconds_since_shown': ?secondsSinceShown,
  });

  /// A dictionary definition sheet was shown; [term] is the term's dictionary
  /// title (a closed, low-cardinality list bundled with the app).
  void logDefinitionOpened({required String term}) =>
      _track('definition_opened', {'term': term});

  /// The «РУ» translation chip on the question screen; [enabled] is the state
  /// after the tap (the chip resets on every question change, so each `true`
  /// is one question read with the translation).
  void logTranslationToggled({required bool enabled}) =>
      _track('translation_toggled', {'enabled': enabled});

  /// A category konspekt was successfully loaded and shown.
  void logKonspektOpened({required String categoryId}) =>
      _track('konspekt_opened', {'category': categoryId});

  /// A subcategory was picked on the categories screen (that is how a
  /// category's questions are opened — the screen has no whole-category
  /// entry).
  void logCategoryOpened({
    required String subcategory,
    required int questionCount,
  }) => _track('category_opened', {
    'subcategory': subcategory,
    'question_count': questionCount,
  });

  /// One of the user's own question lists was opened.
  void logQuestionListOpened({int? questionCount}) =>
      _track('question_list_opened', {'question_count': ?questionCount});

  /// The law was opened from a link (route on the phone, side panel on the
  /// wide screen — the panel raises no screen event, hence its own event).
  void logZakonOpened({String? chlan, String? paragraph, String? chapter}) =>
      _track('zakon_opened', {
        'chlan': ?chlan,
        'paragraph': ?paragraph,
        'chapter': ?chapter,
      });

  /// Records a screen change for a routemaster path. The path is reduced to
  /// its route template plus a readable name (see [analyticsScreenName] /
  /// [analyticsScreenTitle]); a repeat of the current screen — routemaster
  /// notifies on every navigation state change — is not re-sent.
  void logScreenView(String path) {
    final name = analyticsScreenName(path);
    if (name == _lastScreen) return;
    _lastScreen = name;
    // The screen is also the context every following event is stamped with.
    _sink?.setScreen(name, title: analyticsScreenTitle(name));
    _sink?.addScreenView();
  }

  /// A quiz run began: [questionCount] questions, [subcategory] when the run
  /// was started from a subcategory (exam-style runs; null for custom sets and
  /// single questions opened by deep link).
  void logTestStarted({required int questionCount, String? subcategory}) =>
      _track('test_started', {
        'question_count': questionCount,
        'subcategory': ?subcategory,
      });

  /// The user pressed "finish" on a quiz run; [durationSeconds] counts from
  /// the start of the run.
  void logTestFinished({
    required int questionCount,
    required int rightAnswers,
    required int score,
    required int possibleScore,
    String? subcategory,
    int? durationSeconds,
  }) => _track('test_finished', {
    'question_count': questionCount,
    'right_answers': rightAnswers,
    'score': score,
    'possible_score': possibleScore,
    'subcategory': ?subcategory,
    'duration_seconds': ?durationSeconds,
  });

  /// The 41-question exam simulation began.
  void logSimulationStarted() => _track('simulation_started', const {});

  /// The exam simulation ended (by hand or by the 45-minute timer);
  /// [durationSeconds] counts from its start.
  void logSimulationFinished({
    required int durationSeconds,
    required int points,
    required int mistakes,
  }) => _track('simulation_finished', {
    'duration_seconds': durationSeconds,
    'points': points,
    'mistakes': mistakes,
  });

  /// A successful sign-in; [method] is `password` or `firebase` (Google/Apple).
  void logLogin(String method) => _track('login', {'method': method});

  /// A successful registration; [method] as in [logLogin].
  void logSignUp(String method) => _track('sign_up', {'method': method});

  /// A group was created; the creator is its owner.
  void logGroupCreated() => _track('group_created', const {});

  /// The user accepted an invite and became a group member.
  void logGroupJoined() => _track('group_joined', const {});

  /// The link to a single question was shared (copied or handed to the
  /// system share sheet).
  void logQuestionShared({required int questionId}) =>
      _track('question_shared', {'question_id': questionId});

  /// The user shared one of their question lists for the first time (a
  /// re-share of an already shared list is not counted again).
  void logQuestionListShared({required int questionCount}) =>
      _track('question_list_shared', {'question_count': questionCount});

  /// Somebody opened a share link. [outcome] is `ok`, `link_invalid`,
  /// `list_deleted` or `failed`; [questionCount] and [viewerIsOwner] only for
  /// `ok`.
  void logSharedListOpened({
    required String outcome,
    int? questionCount,
    bool? viewerIsOwner,
  }) => _track('shared_list_opened', {
    'outcome': outcome,
    'question_count': ?questionCount,
    'viewer_is_owner': ?viewerIsOwner,
  });

  /// The recipient saved a shared list as their own.
  void logSharedListImported({required int questionCount}) =>
      _track('shared_list_imported', {'question_count': questionCount});

  /// The web-only money conversation reached a step: `tariffs_opened`,
  /// `subscription_opened`, `order_created`, `order_cancelled` — everything
  /// after that (payment, activation) happens outside the app.
  void logCheckoutStep({required String step, String? sku}) =>
      _track('checkout_step', {'step': step, 'sku': ?sku});

  /// The «русскоязычный контент» add-on checkbox on the tariffs screen. Also
  /// updates the person, so "кто включал русский контент" is one filter.
  void logRussianAddonToggled({required bool enabled}) =>
      _track('russian_addon_toggled', {
        'enabled': enabled,
        r'$set': {'russian_addon_chosen': enabled},
      });

  /// A promo code was submitted on the tariffs screen; [valid] — whether the
  /// backend accepted it. The code itself is not reported.
  void logPromoCodeApplied({required bool valid}) =>
      _track('promo_code_applied', {'valid': valid});

  /// A question search was run; only the length of the query is reported —
  /// what exactly a person types is theirs.
  void logQuestionSearch({required int queryLength, required int results}) =>
      _track('question_search', {
        'query_length': queryLength,
        'results': results,
      });

  /// The user asked the AI something in the live chat (not the pre-generated
  /// explanation); [scope] is `question`, `practice` or `category` and
  /// [scopeId] the thing being asked about.
  void logAskAiQuestion({required String scope, required String scopeId}) =>
      _track('ask_ai_question', {'scope': scope, 'scope_id': scopeId});

  /// A message was sent in a chat; [kind] is `support`, `question` (the public
  /// discussion under a question), `group`, `thread` or `chat`.
  void logChatMessageSent({required String kind}) =>
      _track('chat_message_sent', {'kind': kind});

  /// Queues one event; dropped silently when no sink is attached (tests).
  void _track(String name, Map<String, Object> params) =>
      _sink?.add(name, params);
}
