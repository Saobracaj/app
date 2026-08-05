import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fb_ui_auth;

import 'firebase_login_state.dart';

sealed class FirebaseLoginEvent {}

/// Пользователь нажал кнопку входа через [provider]. Блок сразу помечает этот
/// провайдер активным — с этого момента спиннер показывает только его кнопка, а
/// вся остальная форма выключена.
class SocialSignInPressed extends FirebaseLoginEvent {
  SocialSignInPressed(this.provider);
  final SocialAuthProvider provider;
}

/// A transition reported by a `firebase_ui_auth` OAuth button (Google / Apple).
class FirebaseAuthReceived extends FirebaseLoginEvent {
  FirebaseAuthReceived(this.authState);
  final fb_ui_auth.AuthState authState;
}
