/// Events of [NetworkStatusBloc].
sealed class NetworkStatusEvent {
  const NetworkStatusEvent();
}

/// Subscribe to `NetworkStatus` and publish its current value (from `main()`).
class NetworkStatusStarted extends NetworkStatusEvent {
  const NetworkStatusStarted();
}

/// `NetworkStatus` reported a change (internal).
class NetworkStatusChanged extends NetworkStatusEvent {
  const NetworkStatusChanged({required this.online});

  final bool online;
}
