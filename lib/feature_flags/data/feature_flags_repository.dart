import 'dart:async';

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
/// Mirrors the cross-cutting-service pattern of `StatisticsSyncService` /
/// `SessionSyncService` (constructed as a global in `lib/db/dependencies.dart`,
/// driven from `AuthBloc` on session changes). Widgets consume it through
/// `FeatureFlagsBloc`.
class FeatureFlagsRepository {
  FeatureFlagsRepository(this._client, this._storage);

  final GraphqlClient _client;
  final TokenStorage _storage;

  static const _localPrefix = 'feature.';
  static const _localSuffix = '.enabled';
  static const _grantsKey = 'feature_grants';

  final StreamController<FeatureFlagsSnapshot> _controller =
      StreamController<FeatureFlagsSnapshot>.broadcast();

  Map<String, bool> _localOverrides = {};
  Set<String> _grants = {};
  bool _authenticated = false;
  FeatureFlagsSnapshot _snapshot = FeatureFlagsSnapshot.initial();

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
  Future<void> setLocalEnabled(AppFeature feature, bool enabled) async {
    _localOverrides = {..._localOverrides, feature.key: enabled};
    (await _prefs).setBool('$_localPrefix${feature.key}$_localSuffix', enabled);
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
    _snapshot = FeatureFlagsSnapshot.resolve(
      localOverrides: _localOverrides,
      grants: _grants,
      authenticated: _authenticated,
    );
    _controller.add(_snapshot);
  }
}
