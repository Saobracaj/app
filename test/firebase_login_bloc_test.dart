import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fb_ui_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/firebase_login/firebase_login_bloc.dart';
import 'package:saobracaj/auth/state_management/firebase_login/firebase_login_events.dart';
import 'package:saobracaj/auth/state_management/firebase_login/firebase_login_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Клиент-заглушка: в этих тестах до обмена токена дело не доходит, поэтому
/// сетевых вызовов нет.
class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async =>
      const {};
}

FirebaseLoginBloc _buildBloc() {
  final storage = TokenStorage();
  return FirebaseLoginBloc(AuthRepository(_FakeClient(storage), storage));
}

/// Дождаться, пока блок отработает событие и погасит one-shot флаги.
Future<FirebaseLoginState> _settled(FirebaseLoginBloc bloc) =>
    bloc.stream.firstWhere((s) => !s.shouldLogOut && !s.success);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('спиннер показывает только нажатая кнопка', () async {
    final bloc = _buildBloc();
    expect(bloc.state.isBusy, isFalse);

    bloc.add(SocialSignInPressed(SocialAuthProvider.google));
    final state = await bloc.stream.first;

    expect(state.isBusy, isTrue);
    expect(state.isBusyWith(SocialAuthProvider.google), isTrue);
    // Вторая кнопка не крутится — она просто выключена, пока идёт вход.
    expect(state.isBusyWith(SocialAuthProvider.apple), isFalse);
  });

  test('ошибка входа показывается сообщением и разблокирует форму', () async {
    final bloc = _buildBloc();
    bloc.add(SocialSignInPressed(SocialAuthProvider.google));
    await bloc.stream.first;

    bloc.add(
      FirebaseAuthReceived(
        fb_ui_auth.AuthFailed(fba.FirebaseAuthException(code: 'internal-error')),
      ),
    );
    final state = await _settled(bloc);

    expect(state.errorMessage, isNotNull);
    expect(state.isBusy, isFalse);
  });

  test('у разных ошибок разные сообщения', () async {
    Future<String?> messageFor(String code) async {
      final bloc = _buildBloc();
      bloc.add(SocialSignInPressed(SocialAuthProvider.apple));
      await bloc.stream.first;
      bloc.add(
        FirebaseAuthReceived(
          fb_ui_auth.AuthFailed(fba.FirebaseAuthException(code: code)),
        ),
      );
      return (await _settled(bloc)).errorMessage;
    }

    final generic = await messageFor('internal-error');
    final network = await messageFor('network-request-failed');
    final exists = await messageFor('account-exists-with-different-credential');

    expect(network, isNot(generic));
    expect(exists, isNot(generic));
  });

  test('отмена входа пользователем не показывает ошибку', () async {
    final bloc = _buildBloc();
    bloc.add(SocialSignInPressed(SocialAuthProvider.google));
    await bloc.stream.first;

    bloc.add(
      FirebaseAuthReceived(
        fb_ui_auth.AuthFailed(
          fba.FirebaseAuthException(code: 'popup-closed-by-user'),
        ),
      ),
    );
    final state = await _settled(bloc);

    expect(state.errorMessage, isNull);
    expect(state.isBusy, isFalse);
  });

  test(
    'сброс флоу (отмена на нативной платформе) снимает блокировку формы',
    () async {
      final bloc = _buildBloc();
      bloc.add(SocialSignInPressed(SocialAuthProvider.google));
      await bloc.stream.first;

      bloc.add(FirebaseAuthReceived(const fb_ui_auth.Uninitialized()));
      final state = await _settled(bloc);

      expect(state.isBusy, isFalse);
      expect(state.errorMessage, isNull);
    },
  );

  test('вход без пользователя не оставляет форму заблокированной', () async {
    final bloc = _buildBloc();
    bloc.add(SocialSignInPressed(SocialAuthProvider.apple));
    await bloc.stream.first;

    bloc.add(FirebaseAuthReceived(fb_ui_auth.SignedIn(null)));
    final state = await _settled(bloc);

    expect(state.isBusy, isFalse);
    expect(state.errorMessage, isNotNull);
  });

  test('новая попытка входа стирает прошлую ошибку', () async {
    final bloc = _buildBloc();
    bloc.add(SocialSignInPressed(SocialAuthProvider.google));
    await bloc.stream.first;
    bloc.add(
      FirebaseAuthReceived(
        fb_ui_auth.AuthFailed(fba.FirebaseAuthException(code: 'internal-error')),
      ),
    );
    await _settled(bloc);

    bloc.add(SocialSignInPressed(SocialAuthProvider.apple));
    final state = await bloc.stream.firstWhere((s) => s.isBusy);

    expect(state.errorMessage, isNull);
    expect(state.isBusyWith(SocialAuthProvider.apple), isTrue);
  });
}
