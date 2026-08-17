import 'package:freezed_annotation/freezed_annotation.dart';

part 'network_status_state.freezed.dart';

/// Whether the app currently has a working connection to the backend, as far
/// as it can tell (platform connectivity + the last request's outcome).
@freezed
abstract class NetworkStatusState with _$NetworkStatusState {
  const factory NetworkStatusState({@Default(true) bool online}) =
      _NetworkStatusState;
}
