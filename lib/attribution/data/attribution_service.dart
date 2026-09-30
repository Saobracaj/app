import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/data/auth_status.dart';
import 'attribution_repository.dart';
import 'launch_signals.dart' as signals;

/// Откуда платформа берёт сведения о запуске — отдельным классом, чтобы
/// тесты могли их подменить.
@lazySingleton
class LaunchSignals {
  Future<DateTime?> installedAt() => signals.readInstalledAt();
  Future<String?> playReferrer() => signals.readPlayReferrer();
  String? webClickId() => signals.readWebClickId();
  String platform() => signals.launchPlatform();
}

/// Сообщает бэкенду о запусках приложения, чтобы тот привязал к устройству
/// клик по ссылке-источнику (`/go/<код>`) — и сам клик, и то, что из него
/// вышло: установку, регистрацию, покупку. Сопоставляет бэкенд
/// (`saobracaj_backend/src/attribution`), приложение только рассказывает, что
/// знает:
///
/// * при запуске — когда приложение установлено, а на Android до первого
///   успешного отчёта ещё и Google Play install referrer (в нём лежит id
///   клика, если ставили по нашей ссылке); в вебе — `lnk` из адреса;
/// * при возвращении из фона — просто «открыто»: кнопка «Открыть» на странице
///   стора после клика по ссылке ведёт именно сюда;
/// * после входа — ещё раз, с токеном: источник засчитывается аккаунту;
/// * когда приложение открыто самой ссылкой ([openedByLink]).
///
/// Всё «как получится»: сбой отчёта не виден пользователю и ничего не ломает.
@lazySingleton
class AttributionService {
  AttributionService(this._repository, this._auth, this._signals);

  final AttributionRepository _repository;
  final AuthRepository _auth;
  final LaunchSignals _signals;

  /// Ключ shared preferences: первый отчёт с install referrer дошёл до
  /// бэкенда, referrer больше не нужен (и не спрашивается у Play).
  static const installReportedKey = 'attribution_install_reported';

  /// Чаще этого возвращение из фона не сообщается: переключение между
  /// приложениями — не новый заход.
  static const resumeInterval = Duration(minutes: 1);

  /// Сколько ждать, пока сессия восстановится, прежде чем отчитаться о
  /// запуске гостем.
  static const sessionWait = Duration(seconds: 8);

  bool _started = false;
  bool _launched = false;
  bool _authenticated = false;
  DateTime? _lastReport;
  String? _webClickId;
  Timer? _launchTimer;
  StreamSubscription<AuthStatus>? _sessionSub;
  AppLifecycleListener? _lifecycle;

  /// Отчёты уходят по одному, в порядке поступления.
  Future<void> _tail = Future.value();

  /// Начать: отчёт о запуске уйдёт, как только станет ясно, вошёл ли
  /// пользователь (или через [sessionWait]). Повторный вызов ничего не делает.
  void start({bool watchLifecycle = !kIsWeb}) {
    if (_started) return;
    _started = true;
    _webClickId = _signals.webClickId();
    _sessionSub = _auth.sessionStatus
        .where((status) => status != AuthStatus.unknown)
        .listen(_onSession);
    _launchTimer = Timer(sessionWait, _reportLaunch);
    if (watchLifecycle) {
      _lifecycle = AppLifecycleListener(onResume: onResumed);
    }
  }

  void _onSession(AuthStatus status) {
    final signedIn = status == AuthStatus.authenticated;
    final justSignedIn = signedIn && !_authenticated;
    _authenticated = signedIn;
    if (!_launched) {
      _reportLaunch();
    } else if (justSignedIn) {
      // Аккаунт только что появился на этом устройстве: бэкенд засчитает ему
      // клик, который привёл сюда устройство.
      unawaited(_enqueue(_report));
    }
  }

  void _reportLaunch() {
    if (_launched) return;
    _launched = true;
    _launchTimer?.cancel();
    unawaited(_enqueue(_report));
  }

  /// Приложение вернулось из фона.
  @visibleForTesting
  void onResumed() {
    if (!_launched) return;
    final last = _lastReport;
    if (last != null && DateTime.now().difference(last) < resumeInterval) {
      return;
    }
    unawaited(_enqueue(_report));
  }

  /// Приложение открыто ссылкой `/go/[code]`. Возвращает экран, на который
  /// ведёт ссылка, или `null`, если источник неизвестен или бэкенд не ответил.
  Future<String?> openedByLink(String code) =>
      _enqueue(() => _report(linkCode: code));

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<String?> _report({String? linkCode}) async {
    final prefs = await SharedPreferences.getInstance();
    final installReported = prefs.getBool(installReportedKey) ?? false;
    final clickId = _webClickId;
    _webClickId = null;
    try {
      final target = await _repository.reportAppOpen(
        platform: _signals.platform(),
        authenticated: _authenticated,
        installedAt: await _signals.installedAt(),
        playReferrer: installReported ? null : await _signals.playReferrer(),
        linkCode: linkCode,
        clickId: clickId,
      );
      _lastReport = DateTime.now();
      if (!installReported) await prefs.setBool(installReportedKey, true);
      return target;
    } catch (e) {
      // Клик из адреса веб-версии пригодится следующей попытке.
      _webClickId ??= clickId;
      debugPrint('Attribution: report failed: $e');
      return null;
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    _launchTimer?.cancel();
    _lifecycle?.dispose();
    await _sessionSub?.cancel();
  }
}

/// Код ссылки-источника, если [path] — это `/go/<код>` (путь приложения,
/// как его отдаёт `deepLinkPathFor`), иначе `null`.
String? attributionLinkCode(String path) {
  final segments = Uri.parse(
    path,
  ).pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != 2 || segments.first != 'go') return null;
  final code = segments[1].trim().toLowerCase();
  return code.isEmpty ? null : code;
}
