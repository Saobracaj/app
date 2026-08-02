import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/data/auth_status.dart';

/// Keeps the device's FCM push token registered with `saobracaj_backend`.
///
/// A token is (re)registered whenever:
///   * the session becomes authenticated — this covers both app start with a
///     stored session and a fresh login, since both surface as an
///     [AuthStatus.authenticated] transition on [AuthRepository.sessionStatus];
///   * Firebase rotates the token (`onTokenRefresh`), while authenticated.
///
/// Every Firebase call is best-effort: a device without native FCM config, a web
/// build without a VAPID key, or an unsupported platform must never crash the
/// app — failures are logged and swallowed.
@lazySingleton
class PushTokenService {
  PushTokenService(this._repository);

  final AuthRepository _repository;

  StreamSubscription<AuthStatus>? _sessionSub;
  StreamSubscription<String>? _refreshSub;
  bool _authenticated = false;
  bool _started = false;

  /// Begin listening for session and token changes. Idempotent — safe to call
  /// once from `main()` after Firebase and DI are set up.
  void start() {
    if (_started) return;
    _started = true;

    _sessionSub = _repository.sessionStatus.distinct().listen((status) {
      _authenticated = status == AuthStatus.authenticated;
      if (_authenticated) unawaited(syncToken());
    });

    try {
      _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        if (_authenticated && token.isNotEmpty) unawaited(_register(token));
      });
    } catch (e) {
      debugPrint('PushTokenService.onTokenRefresh subscribe failed: $e');
    }
  }

  /// Fetch the current FCM token and register the device with the backend.
  Future<void> syncToken() async {
    final token = await _currentToken();
    if (token == null || token.isEmpty) return;
    await _register(token);
  }

  Future<String?> _currentToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      // iOS / web only issue a token once notification permission is granted.
      await messaging.requestPermission();
      return await messaging.getToken();
    } catch (e) {
      debugPrint('FirebaseMessaging.getToken failed: $e');
      return null;
    }
  }

  Future<void> _register(String token) async {
    try {
      await _repository.registerDevice(pushToken: token, platform: _platform());
    } catch (e) {
      debugPrint('PushTokenService.registerDevice failed: $e');
    }
  }

  String _platform() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  @disposeMethod
  Future<void> dispose() async {
    await _sessionSub?.cancel();
    await _refreshSub?.cancel();
  }
}
