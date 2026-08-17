import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../di.dart';
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

/// Usage analytics, backed by Firebase Analytics (Google Analytics 4).
///
/// The Firebase project is the one already used for social sign-in and push;
/// the web app config carries a `measurementId`, so all three platforms report
/// to the same GA property with nothing to provision.
///
/// Every call is fire-and-forget and fail-soft, in line with `initFirebase()`:
/// analytics must never break a user-facing flow, and when Firebase failed to
/// initialise (or the platform has no config) events are silently dropped.
@lazySingleton
class AnalyticsService {
  String? _lastScreen;

  FirebaseAnalytics? get _firebase =>
      Firebase.apps.isEmpty ? null : FirebaseAnalytics.instance;

  /// Records a `screen_view` for a routemaster path. The path is reduced to
  /// its route template (see [analyticsScreenName]); a repeat of the current
  /// screen — routemaster notifies on every navigation state change — is not
  /// re-sent.
  void logScreenView(String path) {
    final name = analyticsScreenName(path);
    if (name == _lastScreen) return;
    _lastScreen = name;
    _send(() => _firebase?.logScreenView(screenName: name));
  }

  /// A quiz run began: [questionCount] questions, [subcategory] when the run
  /// was started from a subcategory (exam-style runs; null for custom sets and
  /// single questions opened by deep link).
  void logTestStarted({required int questionCount, String? subcategory}) {
    _send(
      () => _firebase?.logEvent(
        name: 'test_started',
        parameters: {
          'question_count': questionCount,
          'subcategory': ?subcategory,
        },
      ),
    );
  }

  /// The user pressed "finish" on a quiz run.
  void logTestFinished({
    required int questionCount,
    required int rightAnswers,
    required int score,
    required int possibleScore,
    String? subcategory,
  }) {
    _send(
      () => _firebase?.logEvent(
        name: 'test_finished',
        parameters: {
          'question_count': questionCount,
          'right_answers': rightAnswers,
          'score': score,
          'possible_score': possibleScore,
          'subcategory': ?subcategory,
        },
      ),
    );
  }

  /// A successful sign-in; [method] is `password` or `firebase` (Google/Apple).
  void logLogin(String method) =>
      _send(() => _firebase?.logLogin(loginMethod: method));

  /// A successful registration; [method] as in [logLogin].
  void logSignUp(String method) =>
      _send(() => _firebase?.logSignUp(signUpMethod: method));

  /// The user shared one of their question lists for the first time (a
  /// re-share of an already shared list is not counted again).
  void logQuestionListShared({required int questionCount}) {
    _send(
      () => _firebase?.logEvent(
        name: 'question_list_shared',
        parameters: {'question_count': questionCount},
      ),
    );
  }

  /// Somebody opened a share link. [outcome] is `ok`, `link_invalid`,
  /// `list_deleted` or `failed`; [questionCount] and [viewerIsOwner] only for
  /// `ok`.
  void logSharedListOpened({
    required String outcome,
    int? questionCount,
    bool? viewerIsOwner,
  }) {
    _send(
      () => _firebase?.logEvent(
        name: 'shared_list_opened',
        parameters: {
          'outcome': outcome,
          'question_count': ?questionCount,
          if (viewerIsOwner != null) 'viewer_is_owner': viewerIsOwner ? 1 : 0,
        },
      ),
    );
  }

  /// The recipient saved a shared list as their own.
  void logSharedListImported({required int questionCount}) {
    _send(
      () => _firebase?.logEvent(
        name: 'shared_list_imported',
        parameters: {'question_count': questionCount},
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
