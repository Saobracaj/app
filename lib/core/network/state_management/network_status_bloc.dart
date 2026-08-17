import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../network_status.dart';
import 'network_status_events.dart';
import 'network_status_state.dart';

/// Republishes [NetworkStatus] to the widget tree, so screens can switch copy
/// ("no network" vs. a generic error) and the home screen can show its offline
/// card. Provided app-wide in `main.dart`, like `AuthBloc`.
///
/// Blocs that need to *react* (reload after a reconnect) listen to
/// [NetworkStatus.onReconnected] directly rather than to this Bloc — the
/// service is the source of truth, this is only its view.
@injectable
class NetworkStatusBloc extends Bloc<NetworkStatusEvent, NetworkStatusState> {
  NetworkStatusBloc(this._network)
    : super(NetworkStatusState(online: _network.isOnline)) {
    on<NetworkStatusStarted>(_onStarted);
    on<NetworkStatusChanged>(
      (event, emit) => emit(state.copyWith(online: event.online)),
    );
  }

  final NetworkStatus _network;
  StreamSubscription<bool>? _subscription;

  void _onStarted(NetworkStatusStarted event, Emitter<NetworkStatusState> emit) {
    _subscription ??= _network.changes.listen(
      (online) => add(NetworkStatusChanged(online: online)),
    );
    emit(state.copyWith(online: _network.isOnline));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
