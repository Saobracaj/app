import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

/// Usage analytics, reported to **two** places at once.
///
/// * **Firebase Analytics (GA4)** — the project already used for social sign-in
///   and push; the web config carries a `measurementId`, so all three platforms
///   report to the same GA property. GA answers the aggregate questions:
///   audience, retention, acquisition.
/// * **Our own backend** ([AnalyticsEventSink], the `trackEvents` mutation) —
///   the same events in our Postgres, keyed by our own user id. That is what
///   makes "взять пользователя и посмотреть, чем он пользовался" possible at
///   all: GA knows people under a pseudonymous client id, samples its reports
///   and offers no join to the `users` table.
///
/// Every call is fire-and-forget and fail-soft, in line with `initFirebase()`:
/// analytics must never break a user-facing flow. Without Firebase the GA half
/// is silently dropped; without a sink attached (tests, and the app before
/// `main()` wires one) so is the backend half.
@lazySingleton
class AnalyticsService {
  String? _lastScreen;
  AnalyticsEventSink? _sink;

  FirebaseAnalytics? get _firebase =>
      Firebase.apps.isEmpty ? null : FirebaseAnalytics.instance;

  /// Point the second half of the pipeline at the backend. Called once from
  /// `main()`, after DI is configured.
  void attachSink(AnalyticsEventSink sink) => _sink = sink;

  /// Ties every following event to the signed-in backend account (the GA4
  /// User-ID feature — per-user drill-down in "Обзор пользователей" and in the
  /// BigQuery export). `null` on sign-out: a guest's events stay device-scoped.
  ///
  /// The backend half needs no id — the server stamps every event with the
  /// account behind the request token — but the queue is flushed here anyway,
  /// so that what happened before the switch travels with the identity it
  /// happened under.
  void setUserId(String? id) {
    _send(() => _firebase?.setUserId(id: id));
    _sink?.flush();
  }

  /// Reports the running build as the `app_version` user property. Firebase
  /// fills the version in automatically on Android/iOS but not on the web, and
  /// a user property makes the dimension uniform across all three platforms.
  /// (The backend half carries the version on every single event.)
  void reportAppVersion() {
    _send(() async {
      final info = await PackageInfo.fromPlatform();
      await _firebase?.setUserProperty(
        name: 'app_version',
        value: '${info.version}+${info.buildNumber}',
      );
    });
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

  /// A dictionary definition sheet was shown; [term] is the term's dictionary
  /// title (a closed, low-cardinality list bundled with the app).
  void logDefinitionOpened({required String term}) =>
      _track('definition_opened', {'term': term});

  /// The «РУ» translation chip on the question screen; [enabled] is the state
  /// after the tap (the chip resets on every question change, so each `true`
  /// is one question read with the translation).
  void logTranslationToggled({required bool enabled}) =>
      _track('translation_toggled', {'enabled': enabled ? 1 : 0});

  /// A category konspekt was successfully loaded and shown.
  void logKonspektOpened({required String categoryId}) =>
      _track('konspekt_opened', {'category': categoryId});

  /// The law was opened from a link (route on the phone, side panel on the
  /// wide screen — the panel raises no `screen_view`, hence its own event).
  void logZakonOpened({String? chlan, String? paragraph, String? chapter}) =>
      _track('zakon_opened', {
        'chlan': ?chlan,
        'paragraph': ?paragraph,
        'chapter': ?chapter,
      });

  /// Records a `screen_view` for a routemaster path. The path is reduced to
  /// its route template (see [analyticsScreenName]); a repeat of the current
  /// screen — routemaster notifies on every navigation state change — is not
  /// re-sent.
  void logScreenView(String path) {
    final name = analyticsScreenName(path);
    if (name == _lastScreen) return;
    _lastScreen = name;
    // The screen is also the context every following event is stamped with.
    _sink?.setScreen(name);
    _sink?.add('screen_view', {'screen': name});
    _send(() => _firebase?.logScreenView(screenName: name));
  }

  /// A quiz run began: [questionCount] questions, [subcategory] when the run
  /// was started from a subcategory (exam-style runs; null for custom sets and
  /// single questions opened by deep link).
  void logTestStarted({required int questionCount, String? subcategory}) =>
      _track('test_started', {
        'question_count': questionCount,
        'subcategory': ?subcategory,
      });

  /// The user pressed "finish" on a quiz run.
  void logTestFinished({
    required int questionCount,
    required int rightAnswers,
    required int score,
    required int possibleScore,
    String? subcategory,
  }) => _track('test_finished', {
    'question_count': questionCount,
    'right_answers': rightAnswers,
    'score': score,
    'possible_score': possibleScore,
    'subcategory': ?subcategory,
  });

  /// A successful sign-in; [method] is `password` or `firebase` (Google/Apple).
  void logLogin(String method) {
    _sink?.add('login', {'method': method});
    _send(() => _firebase?.logLogin(loginMethod: method));
  }

  /// A successful registration; [method] as in [logLogin].
  void logSignUp(String method) {
    _sink?.add('sign_up', {'method': method});
    _send(() => _firebase?.logSignUp(signUpMethod: method));
  }

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
    if (viewerIsOwner != null) 'viewer_is_owner': viewerIsOwner ? 1 : 0,
  });

  /// The recipient saved a shared list as their own.
  void logSharedListImported({required int questionCount}) =>
      _track('shared_list_imported', {'question_count': questionCount});

  /// The web-only money conversation reached a step: `tariffs_opened`,
  /// `subscription_opened`, `order_created`, `order_cancelled` — everything
  /// after that (payment, activation) happens outside the app.
  void logCheckoutStep({required String step, String? sku}) =>
      _track('checkout_step', {'step': step, 'sku': ?sku});

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

  /// A message was sent in a chat; [kind] is `support`, `question` or `group`.
  void logChatMessageSent({required String kind}) =>
      _track('chat_message_sent', {'kind': kind});

  /// Sends one event down both pipelines. GA4 accepts only scalar parameters,
  /// which is exactly what every call site passes.
  void _track(String name, Map<String, Object> params) {
    _sink?.add(name, params);
    _send(
      () => _firebase?.logEvent(
        name: name,
        parameters: params.isEmpty ? null : Map<String, Object>.of(params),
      ),
    );
  }

  /// Runs one analytics call, swallowing both sync and async failures — a
  /// missing Firebase app, an ad blocker on the web, a broken transport.
  void _send(Future<void>? Function() call) {
    try {
      call()?.catchError((Object e) => debugPrint('Analytics: $e'));
    } catch (e) {
      debugPrint('Analytics: $e');
    }
  }
}
