import 'package:freezed_annotation/freezed_annotation.dart';

part 'firebase_login_state.freezed.dart';

@freezed
abstract class FirebaseLoginState with _$FirebaseLoginState {
  const factory FirebaseLoginState({
    @Default(false) bool isBusy,
    // One-shot effects consumed by the page's BlocListener.
    @Default(false) bool shouldLogOut,
    @Default(false) bool success,
    String? errorMessage,
  }) = _FirebaseLoginState;
}
