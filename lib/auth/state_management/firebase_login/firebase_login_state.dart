import 'package:freezed_annotation/freezed_annotation.dart';

part 'firebase_login_state.freezed.dart';

/// Провайдер соц-входа. Нужен, чтобы знать, какая именно кнопка сейчас в работе:
/// спиннер показывает только она, вторая просто выключается.
enum SocialAuthProvider { google, apple }

@freezed
abstract class FirebaseLoginState with _$FirebaseLoginState {
  const FirebaseLoginState._();

  const factory FirebaseLoginState({
    /// Провайдер, вход через который сейчас выполняется, либо `null`.
    SocialAuthProvider? activeProvider,
    // One-shot effects consumed by the page's BlocListener.
    @Default(false) bool shouldLogOut,
    @Default(false) bool success,

    /// Текст ошибки для инлайнового [ErrorField]. Живёт до следующей попытки
    /// входа (в отличие от one-shot флагов выше).
    String? errorMessage,
  }) = _FirebaseLoginState;

  /// Идёт ли соц-вход через какой-либо провайдер: пока да, вся форма
  /// (поля, кнопки, ссылки) на странице авторизации переводится в disabled.
  bool get isBusy => activeProvider != null;

  /// Крутится ли спиннер именно на кнопке [provider].
  bool isBusyWith(SocialAuthProvider provider) => activeProvider == provider;
}
