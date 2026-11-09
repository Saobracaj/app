import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/graphql_client.dart';
import '../../auth/data/token_storage.dart';
import '../../core/analytics/analytics_service.dart';
import '../domain/app_feature.dart';
import 'feature_flags_snapshot.dart';

/// Source of truth for feature availability on the client.
///
/// It combines three inputs into a [FeatureFlagsSnapshot]:
///   * the code-owned tier of each [AppFeature],
///   * the set of **premium grants** fetched from the backend `featureFlags`
///     query (cached in shared preferences so premium survives an offline
///     launch), and
///   * the user's **local toggles** (also in shared preferences).
///
/// [AppFeature.russianContent] is the one feature the user is asked about
/// explicitly — see [_russianDefault] and [shouldAskRussianContent].
///
/// Mirrors the cross-cutting-service pattern of `StatisticsSyncService`
/// (constructed as a global in `lib/db/dependencies.dart`, driven from
/// `AuthBloc` on session changes). Widgets consume it through
/// `FeatureFlagsBloc`.
///
/// ## The cached grants are a guess the backend keeps correcting
///
/// The lock on paid content is drawn from the cached grants, so a stale cache
/// shows a paying user the paywall (that happened: a pass bought a week
/// earlier, and the konspekt tab still asking for one). The backend is the
/// authority — it serves full or cut content on its own check — and the cache
/// is kept honest by asking it again whenever there is a reason to doubt:
///
///   * a **guest-shaped answer** to a request that carried a token is never
///     taken for «no grants» ([_looksLikeGuest]): the server treats a rejected
///     access token as an anonymous request instead of an error, so the token
///     is renewed and the question asked again, and failing that the cache is
///     left alone;
///   * the app **returning from the background**, a **lock being shown** and
///     the connection coming back all re-ask ([refreshIfStale], throttled by
///     [staleAfter]);
///   * a content answer that **disagrees with the cache** — the server sent
///     the full explanation where the cache said locked, or a preview where
///     the cache said granted — re-asks at once ([reconcileContentLock]).
class FeatureFlagsRepository {
  FeatureFlagsRepository(
    this._client,
    this._storage, {
    String? deviceLanguage,
    DateTime Function()? clock,
  }) : _deviceLanguage =
           deviceLanguage ?? PlatformDispatcher.instance.locale.languageCode,
       _now = clock ?? DateTime.now;

  final GraphqlClient _client;
  final TokenStorage _storage;

  /// The clock behind the refresh throttle; injectable so a test can move it.
  final DateTime Function() _now;

  /// The device's primary language (`ru`, `sr`, `en`, …). Only decides whether
  /// the Russian-content question is asked at all; injectable for tests.
  final String _deviceLanguage;

  static const _localPrefix = 'feature.';
  static const _localSuffix = '.enabled';
  static const _grantsKey = 'feature_grants';
  static const _russianAskedKey = 'russian_content_asked';
  static const _russianTrialUsedKey = 'russian_translation_trial_used';

  /// How long an answer from the backend counts as fresh for the opportunistic
  /// re-asks ([refreshIfStale]). Short enough that a paywall shown by mistake
  /// corrects itself within the same screen, long enough that swiping through
  /// a dozen locked questions or flipping between apps costs one request.
  static const staleAfter = Duration(seconds: 30);

  /// The window for a re-ask prompted by a content answer that contradicts
  /// the cache ([reconcileContentLock]). Much shorter than [staleAfter]: that
  /// is evidence the cache is wrong, not a hunch — it only has to stop a
  /// screen that loads several documents at once from asking several times.
  static const mismatchStaleAfter = Duration(seconds: 5);

  static const _flagsQuery =
      'query FeatureFlags { featureFlags { flags { key access enabled } } }';

  final StreamController<FeatureFlagsSnapshot> _controller =
      StreamController<FeatureFlagsSnapshot>.broadcast();

  Map<String, bool> _localOverrides = {};
  Set<String> _grants = {};
  bool _authenticated = false;
  bool _russianAsked = false;

  /// How many free showings of the «РУ» translation on locked questions have
  /// been spent on this device — see [russianTranslationTrialUses].
  int _russianTrialUsed = 0;
  FeatureFlagsSnapshot _snapshot = FeatureFlagsSnapshot.initial();

  /// When the backend was last asked for the grants (whatever the outcome) —
  /// the clock [refreshIfStale] throttles on.
  DateTime? _lastAttemptAt;

  /// Whether the device runs in Russian. Such a user is never asked — Russian
  /// materials are simply on for them.
  bool get _deviceIsRussian => _deviceLanguage == 'ru';

  /// The value [AppFeature.russianContent] takes while the user has not
  /// answered the question: **off** for everyone but a Russian device. The
  /// backend grant alone never shows Russian content — the answer does.
  bool get _russianDefault => _deviceIsRussian;

  /// Whether the Russian-content dialog still has to be shown: no stored
  /// answer and a non-Russian device language. Mirrored into the snapshot as
  /// `shouldAskRussianContent`.
  bool get shouldAskRussianContent => !_russianAsked && !_deviceIsRussian;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// The current snapshot, replayed to each new listener followed by every
  /// subsequent change. Consumed by `FeatureFlagsBloc`.
  Stream<FeatureFlagsSnapshot> get changes async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  /// The latest resolved snapshot (synchronous read).
  FeatureFlagsSnapshot get snapshot => _snapshot;

  /// Load persisted local toggles and cached grants, publish an initial
  /// snapshot, then refresh premium grants from the backend if a session
  /// exists. Call once from `main()` after DI is configured.
  Future<void> bootstrap() async {
    final prefs = await _prefs;
    _localOverrides = _readLocalOverrides(prefs);
    _grants = prefs.getStringList(_grantsKey)?.toSet() ?? {};
    _russianAsked = prefs.getBool(_russianAskedKey) ?? false;
    _russianTrialUsed = prefs.getInt(_russianTrialUsedKey) ?? 0;
    _authenticated = (await _storage.accessToken)?.isNotEmpty ?? false;
    _recompute();
    if (_authenticated) {
      unawaited(refreshFromBackend(reason: 'startup'));
    }
  }

  /// Pull the caller's resolved catalog from the backend and cache the premium
  /// grants. Called on startup and after login. Network/transient failures are
  /// swallowed — the cached snapshot stays in effect.
  ///
  /// Single-flight: `main()` asks for the grants as soon as a stored session is
  /// found, and `AuthBloc` asks again the moment that session is published —
  /// two calls a few milliseconds apart that would fetch the very same answer.
  /// The second one joins the first instead of spending a second request.
  ///
  /// [reason] names the trigger for analytics (`startup`, `login`, `purchase`,
  /// `resume`, `locked_content`, …): a refresh that *changes* the grants
  /// outside the purchase flow means the cache had been wrong, and how often
  /// that happens is worth knowing.
  Future<void> refreshFromBackend({String reason = 'session'}) =>
      _refreshInFlight ??= _refreshFromBackend(reason).whenComplete(() {
        _refreshInFlight = null;
      });

  Future<void>? _refreshInFlight;

  /// Re-ask the backend for the grants unless it was asked within [maxAge]
  /// (default [staleAfter]) — the cheap, opportunistic refresh behind the app
  /// coming back from the background, a paywall being shown and a content
  /// answer that disagrees with the cache. Nothing for a guest: there are no
  /// grants to fetch. Joins a refresh already in flight.
  Future<void> refreshIfStale({
    required String reason,
    Duration maxAge = staleAfter,
  }) {
    if (!_authenticated) return Future.value();
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final last = _lastAttemptAt;
    if (last != null && _now().difference(last) < maxAge) {
      return Future.value();
    }
    return refreshFromBackend(reason: reason);
  }

  /// The backend answered a request for premium content attached to a
  /// question of [categoryId] with [locked] (a preview) or not (the full
  /// text). The decision it took is the one the cached grants should have
  /// predicted — see [FeatureFlagsSnapshot.expectsLockedContent]; when the two
  /// disagree the cache is stale in one direction or the other (a pass bought
  /// since, or one that ran out) and is refreshed right away.
  ///
  /// This is what makes the system self-correcting without a restart: the
  /// moment a screen shows content, the lock on it is re-derived from what the
  /// server actually did.
  Future<void> reconcileContentLock(
    AppFeature feature,
    String? categoryId, {
    required bool locked,
  }) {
    if (categoryId == null) return Future.value();
    if (_snapshot.expectsLockedContent(feature, categoryId) == locked) {
      return Future.value();
    }
    return refreshIfStale(
      reason: 'content_mismatch',
      maxAge: mismatchStaleAfter,
    );
  }

  Future<void> _refreshFromBackend(String reason) async {
    _lastAttemptAt = _now();
    try {
      final tokenSent = (await _storage.accessToken)?.isNotEmpty ?? false;
      var flags = await _fetchFlags();
      if (flags == null) return;

      if (tokenSent && _looksLikeGuest(flags)) {
        // The server did not recognise the session behind our token (a clock
        // skew the local `exp` check cannot see, a token it stopped trusting)
        // and answered as to a guest. That is not «no grants»: taking it for
        // one wiped the cache and locked a paying user out until a restart.
        // Renew the token and ask again; if the server still does not know us,
        // keep what we have — the content resolvers enforce the entitlement
        // on their own, so a stale «granted» can show nothing it should not.
        final renewed = await _client.refreshSession();
        analytics.logGrantsSessionRejected(renewed: renewed);
        if (!renewed) return;
        flags = await _fetchFlags();
        if (flags == null || _looksLikeGuest(flags)) return;
      }

      final granted = _grantedKeys(flags);
      final before = _grants;
      _grants = granted;
      _authenticated = true;
      (await _prefs).setStringList(_grantsKey, granted.toList());
      _recompute();
      if (!_sameKeys(before, granted)) {
        analytics.logFeatureGrantsChanged(
          reason: reason,
          gained: granted.difference(before).length,
          lost: before.difference(granted).length,
        );
      }
    } catch (_) {
      // Offline / transient — keep the cached snapshot.
    }
  }

  /// The raw `flags` list of one `featureFlags` answer, or `null` when the
  /// payload is not what the query asked for.
  Future<List<Map>?> _fetchFlags() async {
    final data = await _client.run(_flagsQuery, authenticated: true);
    final flags = (data['featureFlags'] as Map?)?['flags'];
    if (flags is! List) return null;
    return flags.whereType<Map>().toList();
  }

  /// Premium keys the backend resolved as enabled. Only premium flags carry a
  /// per-user grant; the backend already folded tier + grant into `enabled`,
  /// so an enabled premium flag means "granted".
  static Set<String> _grantedKeys(List<Map> flags) => {
    for (final raw in flags)
      if (raw['enabled'] == true &&
          AppFeature.fromKey(raw['key']?.toString() ?? '')?.access ==
              FeatureAccess.premium)
        raw['key'].toString(),
  };

  /// Whether the backend resolved this catalog for a **guest**: the features
  /// of the signed-in tier are the tell — they are on for every signed-in user
  /// and off for a guest, grants or no grants. Undecidable (the answer lists
  /// no such feature) counts as «not a guest», so the answer is trusted as it
  /// always was.
  static bool _looksLikeGuest(List<Map> flags) {
    var sawSignedInTier = false;
    for (final raw in flags) {
      final feature = AppFeature.fromKey(raw['key']?.toString() ?? '');
      if (feature?.access != FeatureAccess.authenticated) continue;
      sawSignedInTier = true;
      if (raw['enabled'] == true) return false;
    }
    return sawSignedInTier;
  }

  static bool _sameKeys(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  /// Drop premium grants when the session ends. Guest/authenticated tiers and
  /// local toggles are unaffected.
  Future<void> onLoggedOut() async {
    _grants = {};
    _authenticated = false;
    _lastAttemptAt = null;
    (await _prefs).remove(_grantsKey);
    _recompute();
  }

  /// Turn a feature's local toggle on/off (persisted). This only removes a
  /// feature the user opted out of — it can't unlock a tier the user lacks.
  ///
  /// Answering the Russian-content dialog goes through here too: any explicit
  /// choice for [AppFeature.russianContent] also records that the question has
  /// been answered, so it is never asked again.
  Future<void> setLocalEnabled(AppFeature feature, bool enabled) async {
    _localOverrides = {..._localOverrides, feature.key: enabled};
    final prefs = await _prefs;
    await prefs.setBool('$_localPrefix${feature.key}$_localSuffix', enabled);
    if (feature == AppFeature.russianContent) {
      _russianAsked = true;
      await prefs.setBool(_russianAskedKey, true);
    }
    _recompute();
  }

  /// Free showings of the «РУ» translation still left on locked questions.
  int get russianTranslationTriesLeft =>
      (russianTranslationTrialUses - _russianTrialUsed).clamp(
        0,
        russianTranslationTrialUses,
      );

  /// Spend one free showing of the «РУ» translation (persisted). The count
  /// lives on the device, not on the account: it is a taste of the feature,
  /// and a subscription makes it moot — with the grant the toggle never asks.
  Future<void> consumeRussianTranslationTrial() async {
    if (russianTranslationTriesLeft == 0) return;
    _russianTrialUsed += 1;
    await (await _prefs).setInt(_russianTrialUsedKey, _russianTrialUsed);
    _recompute();
  }

  Map<String, bool> _readLocalOverrides(SharedPreferences prefs) {
    final overrides = <String, bool>{};
    for (final f in AppFeature.values) {
      final value = prefs.getBool('$_localPrefix${f.key}$_localSuffix');
      if (value != null) overrides[f.key] = value;
    }
    return overrides;
  }

  void _recompute() {
    // Unanswered Russian-content question → the feature behaves as locally
    // switched off (unless the device speaks Russian), whatever the backend
    // granted.
    final russianKey = AppFeature.russianContent.key;
    final overrides = _localOverrides.containsKey(russianKey)
        ? _localOverrides
        : {..._localOverrides, russianKey: _russianDefault};
    _snapshot = FeatureFlagsSnapshot.resolve(
      localOverrides: overrides,
      grants: _grants,
      authenticated: _authenticated,
      askRussianContent: shouldAskRussianContent,
      russianTranslationTriesLeft: russianTranslationTriesLeft,
    );
    _controller.add(_snapshot);
  }
}
