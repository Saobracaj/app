import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/graphql_client.dart';
import '../../auth/data/token_storage.dart';
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
class FeatureFlagsRepository {
  FeatureFlagsRepository(this._client, this._storage, {String? deviceLanguage})
    : _deviceLanguage =
          deviceLanguage ?? PlatformDispatcher.instance.locale.languageCode;

  final GraphqlClient _client;
  final TokenStorage _storage;

  /// The device's primary language (`ru`, `sr`, `en`, …). Only decides whether
  /// the Russian-content question is asked at all; injectable for tests.
  final String _deviceLanguage;

  static const _localPrefix = 'feature.';
  static const _localSuffix = '.enabled';
  static const _grantsKey = 'feature_grants';
  static const _russianAskedKey = 'russian_content_asked';

  final StreamController<FeatureFlagsSnapshot> _controller =
      StreamController<FeatureFlagsSnapshot>.broadcast();

  Map<String, bool> _localOverrides = {};
  Set<String> _grants = {};
  bool _authenticated = false;
  bool _russianAsked = false;
  FeatureFlagsSnapshot _snapshot = FeatureFlagsSnapshot.initial();

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
    _authenticated = (await _storage.accessToken)?.isNotEmpty ?? false;
    _recompute();
    if (_authenticated) {
      unawaited(refreshFromBackend());
    }
  }

  /// Pull the caller's resolved catalog from the backend and cache the premium
  /// grants. Called on startup and after login. Network/transient failures are
  /// swallowed — the cached snapshot stays in effect.
  Future<void> refreshFromBackend() async {
    try {
      final data = await _client.run(
        'query FeatureFlags { featureFlags { flags { key access enabled } } }',
        authenticated: true,
      );
      final flags = (data['featureFlags'] as Map?)?['flags'];
      if (flags is! List) return;

      final granted = <String>{};
      for (final raw in flags) {
        if (raw is! Map) continue;
        final key = raw['key']?.toString();
        final enabled = raw['enabled'] == true;
        // Only premium flags carry a per-user grant; the backend already
        // folded tier + grant into `enabled`, so an enabled premium flag means
        // "granted".
        if (key != null &&
            enabled &&
            AppFeature.fromKey(key)?.access == FeatureAccess.premium) {
          granted.add(key);
        }
      }
      _grants = granted;
      _authenticated = true;
      (await _prefs).setStringList(_grantsKey, granted.toList());
      _recompute();
    } catch (_) {
      // Offline / transient — keep the cached snapshot.
    }
  }

  /// Drop premium grants when the session ends. Guest/authenticated tiers and
  /// local toggles are unaffected.
  Future<void> onLoggedOut() async {
    _grants = {};
    _authenticated = false;
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
    );
    _controller.add(_snapshot);
  }
}
