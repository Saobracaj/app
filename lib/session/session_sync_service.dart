import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/data/graphql_client.dart';
import '../auth/data/token_storage.dart';

/// The user's active session as stored on the back-end: the location (an opaque
/// app route URL such as `/quest?q=1,2,3&subcategory=B`) they last opened, and
/// the id of the device that wrote it.
@immutable
class RemoteSession {
  const RemoteSession({required this.location, this.deviceId, this.updatedAt});

  final String location;
  final String? deviceId;
  final DateTime? updatedAt;
}

/// Auth/profile routes are never mirrored across devices — resuming a login
/// screen (or the home tab) on another device is noise, not continuity. Anything
/// else (quiz, exam simulation, law viewer, …) is worth resuming.
bool isResumableLocation(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  if (path.isEmpty || path == '/') return false;
  const excluded = ['/login', '/register', '/resetPassword', '/confirmCode', '/profile'];
  return !excluded.any((p) => path == p || path.startsWith('$p/'));
}

/// Mirrors the user's current app location across their devices via the
/// `saobracaj_backend` active-session API, so they can put one device down and
/// continue on another.
///
/// Two directions:
///   * **push** — [pushLocation] uploads the current route (debounced,
///     fire-and-forget) through the `setActiveSession` mutation whenever the
///     user navigates while signed in;
///   * **pull** — [fetchResumable] reads the `activeSession` query (e.g. right
///     after login on a new device) and returns it only when it was written by a
///     *different* device, so the app can offer to continue there.
///
/// Like statistics sync, this only runs while authenticated, is best-effort, and
/// never throws.
class SessionSyncService {
  SessionSyncService(this._client, this._storage);

  final GraphqlClient _client;
  final TokenStorage _storage;

  static const _pushDebounce = Duration(milliseconds: 800);

  static const _setMutation = r'''
    mutation SetActiveSession($location: String!) {
      setActiveSession(location: $location) { location deviceId updatedAt }
    }''';

  static const _getQuery = r'''
    query ActiveSession {
      activeSession { location deviceId updatedAt }
    }''';

  Timer? _debounce;
  String? _pendingLocation;
  // The last location we successfully pushed, to skip redundant uploads.
  String? _lastPushed;

  /// Queue [location] to be uploaded as the active session. Coalesces rapid
  /// navigation into a single request and drops no-op repeats. Safe to call from
  /// anywhere; never throws.
  void pushLocation(String location) {
    if (!isResumableLocation(location)) return;
    if (location == _lastPushed) return;
    _pendingLocation = location;
    _debounce?.cancel();
    _debounce = Timer(_pushDebounce, _flush);
  }

  Future<void> _flush() async {
    final location = _pendingLocation;
    if (location == null) return;
    _pendingLocation = null;

    final token = await _storage.accessToken;
    if (token == null || token.isEmpty) return; // signed out — nothing to do.

    try {
      await _client.run(
        _setMutation,
        variables: {'location': location},
        authenticated: true,
      );
      _lastPushed = location;
    } catch (e) {
      debugPrint('Active-session push failed: $e');
    }
  }

  /// The stored active session if it was last written by another device (so it
  /// is worth offering to resume here); `null` when signed out, when nothing is
  /// stored, or when this same device wrote it. Never throws.
  Future<RemoteSession?> fetchResumable() async {
    final token = await _storage.accessToken;
    if (token == null || token.isEmpty) return null;

    try {
      final data = await _client.run(_getQuery, authenticated: true);
      final raw = data['activeSession'];
      if (raw is! Map<String, dynamic>) return null;

      final location = raw['location'] as String?;
      if (location == null || !isResumableLocation(location)) return null;

      final deviceId = raw['deviceId'] as String?;
      final myDeviceId = await _storage.deviceId();
      if (deviceId != null && deviceId == myDeviceId) return null; // written here.

      // Remember it so our own resume-navigation isn't re-pushed as a change.
      _lastPushed = location;

      final updatedAtRaw = raw['updatedAt'] as String?;
      return RemoteSession(
        location: location,
        deviceId: deviceId,
        updatedAt: updatedAtRaw != null ? DateTime.tryParse(updatedAtRaw)?.toLocal() : null,
      );
    } catch (e) {
      debugPrint('Active-session fetch failed: $e');
      return null;
    }
  }
}
