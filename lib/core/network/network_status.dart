import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide "are we online?" signal.
///
/// Two sources feed it:
///
/// * the platform's connectivity — no interface at all (airplane mode, no
///   Wi-Fi/mobile) is a definite *offline*, and an interface coming back is a
///   *reconnect* signal;
/// * the GraphQL client — a transport failure (`GraphqlClient` reports it via
///   [reportFailure]) means the server is unreachable even though the platform
///   claims a link, and a completed request ([reportSuccess]) means we are back.
///
/// The value is deliberately optimistic: the app starts *online* and only flips
/// when either source says otherwise, so a slow platform answer never blanks
/// the home screen at start-up.
///
/// While the platform claims a link but the server was unreachable, an optional
/// [probe] (a trivial request through the GraphQL client, which reports its own
/// outcome here) runs every [probeInterval] — otherwise a server that came back
/// would only be noticed on the next user action.
///
/// Consumers:
/// * `NetworkStatusBloc` republishes [isOnline] to the widget tree (offline
///   card on the home screen, "no network" copy instead of a generic error);
/// * Blocs whose last load failed subscribe to [onReconnected] and reload on
///   their own — the product rule is "when the network is back, data loads by
///   itself; no snackbar".
///
/// Registered via `RegisterModule` in `lib/core/di.dart` (the optional
/// constructor params are for tests, and would confuse injectable).
class NetworkStatus {
  NetworkStatus({
    Connectivity? connectivity,
    Future<void> Function()? probe,
    this.probeInterval = const Duration(seconds: 20),
    @visibleForTesting Stream<List<ConnectivityResult>>? connectivityChanges,
    @visibleForTesting Future<List<ConnectivityResult>>? initialConnectivity,
  }) : _connectivity = connectivity,
       _probe = probe,
       _connectivityChanges = connectivityChanges,
       _initialConnectivity = initialConnectivity;

  final Connectivity? _connectivity;
  final Stream<List<ConnectivityResult>>? _connectivityChanges;
  final Future<List<ConnectivityResult>>? _initialConnectivity;

  /// A cheap request that reports its outcome back here (see `RegisterModule`).
  /// Its result is ignored — the client's [reportSuccess] / [reportFailure] is
  /// what flips the status.
  final Future<void> Function()? _probe;

  /// How often to [_probe] while offline-with-a-link.
  final Duration probeInterval;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _probeTimer;

  bool _online = true;
  bool _linkUp = true;
  bool _started = false;

  /// The latest known status (synchronous read).
  bool get isOnline => _online;

  /// Every *change* of [isOnline] — never the same value twice in a row.
  Stream<bool> get changes => _controller.stream;

  /// Fires each time the app goes from offline back to online. This is the
  /// signal Blocs use to redo a load that failed while offline.
  Stream<void> get onReconnected => changes.where((online) => online);

  /// Subscribe to the platform's connectivity. Idempotent; call once from
  /// `main()` before `runApp`. Failures of the plugin itself (unsupported
  /// platform, missing permission) leave the status at *online* — the client's
  /// own reports still work.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final connectivity = _connectivity ?? Connectivity();
      final stream = _connectivityChanges ?? connectivity.onConnectivityChanged;
      _subscription = stream.listen(
        _onConnectivityChanged,
        onError: (Object _) {
          // The plugin can't tell — assume online, the client reports the rest.
        },
      );
      final initial =
          await (_initialConnectivity ?? connectivity.checkConnectivity());
      _onConnectivityChanged(initial);
    } catch (_) {
      // Same: no connectivity information is not the same as no connection.
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _linkUp =
        results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
    // A link coming (back) up is worth a probe even if the server was
    // unreachable a moment ago: the reload either succeeds or reports a
    // failure and we flip back — no harm done. Going to "no link at all" is
    // definitely offline.
    _set(_linkUp);
  }

  /// A request never reached the server (timeout / connection error). Called by
  /// `GraphqlClient`; the platform may still claim we have a link.
  void reportFailure() => _set(false);

  /// A request completed (with any HTTP status) — the server is reachable.
  void reportSuccess() => _set(true);

  void _set(bool online) {
    if (online != _online) {
      _online = online;
      if (!_controller.isClosed) _controller.add(online);
    }
    _scheduleProbe();
  }

  /// While the platform has a link but the server was unreachable, ask again
  /// after [probeInterval]; the probe's outcome reaches [_set] through the
  /// client, which either ends the loop (online) or schedules the next one.
  void _scheduleProbe() {
    _probeTimer?.cancel();
    _probeTimer = null;
    final probe = _probe;
    if (_online || !_linkUp || probe == null || _controller.isClosed) return;
    _probeTimer = Timer(probeInterval, () async {
      _probeTimer = null;
      try {
        await probe();
      } catch (_) {
        // The client already reported the failure.
      }
      if (!_online) _scheduleProbe();
    });
  }

  @mustCallSuper
  Future<void> dispose() async {
    _probeTimer?.cancel();
    await _subscription?.cancel();
    await _controller.close();
  }
}
