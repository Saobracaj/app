import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import 'push_message.dart';

/// Push notifications as they reach the running app, in the two ways that
/// matter to the UI:
///
///   * [foreground] — a notification that arrived while the app was on
///     screen. The OS shows nothing for those, so the app shows a snackbar
///     with the text and a «go» button leading to the link.
///   * [opened] — the user tapped a notification (in the system tray, while
///     the app was in the background or not running at all). The link it
///     carries is opened right away — in-app when it is one of ours,
///     otherwise in the browser.
///
/// The one that launched the app can arrive before the widget tree exists;
/// like [DeepLinkService], the service holds it for [takePendingOpen] instead
/// of dropping an event nobody was listening to.
///
/// Every Firebase call is best-effort — a device without FCM, or a platform
/// where the plugin lacks a stream, must never take the app down.
@lazySingleton
class PushMessageService {
  final StreamController<PushMessage> _foreground =
      StreamController<PushMessage>.broadcast();
  final StreamController<PushMessage> _opened =
      StreamController<PushMessage>.broadcast();
  final List<StreamSubscription<RemoteMessage>> _subscriptions = [];
  PushMessage? _pendingOpen;
  bool _started = false;

  Stream<PushMessage> get foreground => _foreground.stream;
  Stream<PushMessage> get opened => _opened.stream;

  /// Start listening to Firebase Messaging. Idempotent — call once from
  /// `main()` after Firebase is initialised.
  void start() {
    if (_started) return;
    _started = true;
    try {
      _subscriptions.add(FirebaseMessaging.onMessage.listen(handleForeground));
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(handleOpened),
      );
      // The notification that launched the app from a terminated state — the
      // plugin hands it over once, here, and never through onMessageOpenedApp.
      unawaited(
        FirebaseMessaging.instance.getInitialMessage().then((message) {
          if (message != null) handleOpened(message);
        }).catchError((Object e) {
          debugPrint('FirebaseMessaging.getInitialMessage failed: $e');
        }),
      );
    } catch (e) {
      debugPrint('PushMessageService.start failed: $e');
    }
  }

  @visibleForTesting
  void handleForeground(RemoteMessage message) {
    final push = PushMessage.fromRemote(message);
    if (push == null) return;
    _foreground.add(push);
  }

  @visibleForTesting
  void handleOpened(RemoteMessage message) {
    final push = PushMessage.fromRemote(message);
    // A tapped notification without a link has nothing to open.
    if (push == null || push.link == null) return;
    if (_opened.hasListener) {
      _opened.add(push);
    } else {
      _pendingOpen = push;
    }
  }

  /// The notification a not-yet-built app was launched from, consumed once.
  PushMessage? takePendingOpen() {
    final pending = _pendingOpen;
    _pendingOpen = null;
    return pending;
  }

  @disposeMethod
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _foreground.close();
    await _opened.close();
  }
}
