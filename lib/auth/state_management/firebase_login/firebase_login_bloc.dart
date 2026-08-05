import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fb_ui_auth;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../generated/locale_keys.g.dart';
import '../../data/auth_repository.dart';
import '../../data/graphql_client.dart';
import 'firebase_login_events.dart';
import 'firebase_login_state.dart';

/// Drives Google / Apple sign-in. Firebase is used only to obtain an OAuth ID
/// token; that token is exchanged for our own session via
/// [AuthRepository.firebaseAuth], which then publishes the authenticated session
/// on its stream (picked up by the app-wide `AuthBloc`). Same flow as owncup's
/// `FirebaseLoginBloc`.
///
/// Блок держит `activeProvider` — провайдер, вход через который сейчас идёт:
/// от нажатия кнопки и до успеха/ошибки/отмены. Пока он не `null`, страница
/// авторизации выключает все остальные поля и кнопки, а спиннер крутится только
/// на нажатой кнопке (раньше спиннер показывали обе сразу).
@injectable
class FirebaseLoginBloc extends Bloc<FirebaseLoginEvent, FirebaseLoginState> {
  FirebaseLoginBloc(this._repository) : super(const FirebaseLoginState()) {
    on<SocialSignInPressed>(_onPressed);
    on<FirebaseAuthReceived>(_onAuthReceived);
  }

  final AuthRepository _repository;

  void _onPressed(SocialSignInPressed event, Emitter<FirebaseLoginState> emit) {
    emit(state.copyWith(activeProvider: event.provider, errorMessage: null));
  }

  Future<void> _onAuthReceived(
    FirebaseAuthReceived event,
    Emitter<FirebaseLoginState> emit,
  ) async {
    final authState = event.authState;

    // Firebase подтвердил вход. `SignedIn` — вход в существующий аккаунт,
    // `UserCreated` — первый вход через этого провайдера (аккаунт только что
    // создан); оба ведут к обмену ID-токена на нашу сессию.
    final user = switch (authState) {
      fb_ui_auth.SignedIn(:final user) => user,
      fb_ui_auth.UserCreated(:final credential) => credential.user,
      _ => null,
    };
    if (user != null) {
      await _exchangeToken(user, emit);
      return;
    }
    if (authState is fb_ui_auth.SignedIn ||
        authState is fb_ui_auth.UserCreated) {
      // Вход прошёл, но пользователя нет — обменивать нечего.
      _fail(emit, LocaleKeys.auth_errors_socialFailed.tr());
      return;
    }

    if (authState is fb_ui_auth.AuthFailed) {
      final message = _errorMessage(authState.exception);
      // `null` — пользователь сам закрыл окно входа: молча возвращаем кнопки.
      if (message == null) {
        _reset(emit);
      } else {
        _fail(emit, message);
      }
      return;
    }

    // Флоу вернулся в исходное состояние — так `firebase_ui_auth` сообщает об
    // отмене входа на нативных платформах (AuthCancelledException → reset()).
    if (authState is fb_ui_auth.Uninitialized) _reset(emit);
  }

  Future<void> _exchangeToken(
    fba.User user,
    Emitter<FirebaseLoginState> emit,
  ) async {
    String? idToken;
    try {
      idToken = await user.getIdToken(true);
    } on fba.FirebaseAuthException catch (e) {
      _fail(emit, _errorMessage(e) ?? LocaleKeys.auth_errors_socialFailed.tr());
      return;
    }
    if (idToken == null) {
      _fail(emit, LocaleKeys.auth_errors_socialFailed.tr());
      return;
    }

    try {
      final tokens = await _repository.firebaseAuth(idToken);
      if (!tokens.authenticated) {
        _fail(emit, LocaleKeys.auth_errors_socialFailed.tr());
        return;
      }
      _pulse(
        emit,
        state.copyWith(
          activeProvider: null,
          success: true,
          shouldLogOut: true,
        ),
      );
    } on GraphqlException catch (e) {
      _fail(
        emit,
        e.network ? LocaleKeys.auth_errors_socialNetwork.tr() : e.message,
      );
    }
  }

  /// Показать ошибку и вернуть кнопки в рабочее состояние.
  void _fail(Emitter<FirebaseLoginState> emit, String message) {
    _pulse(
      emit,
      state.copyWith(
        activeProvider: null,
        errorMessage: message,
        shouldLogOut: true,
      ),
    );
  }

  /// Тихий сброс (отмена входа пользователем): без сообщения об ошибке.
  void _reset(Emitter<FirebaseLoginState> emit) {
    // Флоу может сбрасываться и просто так (например, после нашего же
    // signOut) — реагируем, только если вход действительно шёл.
    if (!state.isBusy) return;
    _pulse(emit, state.copyWith(activeProvider: null, shouldLogOut: true));
  }

  /// Emit a one-shot effect state, then immediately clear the effect flags so
  /// the same effect isn't re-run on a later rebuild. `errorMessage` намеренно
  /// не сбрасывается — он рисуется инлайново и живёт до следующей попытки.
  void _pulse(Emitter<FirebaseLoginState> emit, FirebaseLoginState effect) {
    emit(effect);
    emit(effect.copyWith(shouldLogOut: false, success: false));
  }
}

/// Человекочитаемый текст ошибки соц-входа, либо `null`, если вход отменил сам
/// пользователь (закрыл окно/попап) — такое сообщением показывать не нужно.
String? _errorMessage(Exception exception) {
  if (exception is fb_ui_auth.AuthCancelledException) return null;
  if (exception is! fba.FirebaseAuthException) {
    return LocaleKeys.auth_errors_socialFailed.tr();
  }
  if (_cancellationCodes.contains(exception.code)) return null;
  return switch (exception.code) {
    'account-exists-with-different-credential' =>
      LocaleKeys.auth_errors_socialAccountExists.tr(),
    'network-request-failed' => LocaleKeys.auth_errors_socialNetwork.tr(),
    _ => LocaleKeys.auth_errors_socialFailed.tr(),
  };
}

/// Коды `FirebaseAuthException`, которыми разные платформы сообщают «пользователь
/// закрыл окно входа». Это не ошибка — сообщение не показываем.
const _cancellationCodes = {
  'popup-closed-by-user',
  'cancelled-popup-request',
  'user-cancelled',
  'user-canceled',
  'canceled',
  'cancelled',
  'web-context-canceled',
  'web-context-cancelled',
  'sign_in_canceled',
  'ERROR_ABORTED_BY_USER',
};
