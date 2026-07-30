import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the auth tokens and a stable per-install device id in
/// [SharedPreferences]. The device id is sent as the `X-Device-Id` header so the
/// back-end can register push devices per install.
class TokenStorage {
  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';
  static const _deviceKey = 'auth_device_id';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> get accessToken async => (await _prefs).getString(_accessKey);

  Future<String?> get refreshToken async =>
      (await _prefs).getString(_refreshKey);

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await _prefs;
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  /// A stable device id, generated once and reused for the life of the install.
  Future<String> deviceId() async {
    final prefs = await _prefs;
    var id = prefs.getString(_deviceKey);
    if (id == null || id.isEmpty) {
      id = _generateId();
      await prefs.setString(_deviceKey, id);
    }
    return id;
  }

  String _generateId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
