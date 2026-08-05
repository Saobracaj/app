import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import 'deep_link_path.dart';

/// Links the operating system hands to the app, as routes to navigate to.
///
/// On the web there is nothing to do: the address bar *is* the router's input,
/// and Flutter already parses it — so this service stays quiet there.
///
/// A link that arrives before the widget tree exists (a cold start from an
/// invitation) is held for [takePending] rather than dropped: the stream is
/// broadcast, and an event with no listener would simply vanish.
@lazySingleton
class DeepLinkService {
  final StreamController<String> _controller = StreamController<String>.broadcast();
  StreamSubscription<Uri>? _subscription;
  String? _pending;

  /// Routes to open, one per link that arrives while the app is running.
  Stream<String> get paths => _controller.stream;

  /// Starts listening to the platform. Safe to call more than once.
  Future<void> start() async {
    if (kIsWeb || _subscription != null) return;
    // `uriLinkStream` replays the link the app was launched with and then keeps
    // delivering the ones that arrive later, so there is no separate
    // "initial link" query to race with.
    _subscription = AppLinks().uriLinkStream.listen(handleLink);
  }

  /// Routes [uri] if it is one of ours.
  @visibleForTesting
  void handleLink(Uri uri) {
    final path = deepLinkPathFor(uri);
    if (path == null) return;
    if (_controller.hasListener) {
      _controller.add(path);
    } else {
      _pending = path;
    }
  }

  /// The route a not-yet-built app was launched with, consumed once.
  String? takePending() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
