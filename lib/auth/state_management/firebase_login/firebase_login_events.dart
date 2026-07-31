import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fb_ui_auth;

sealed class FirebaseLoginEvent {}

/// A transition reported by a `firebase_ui_auth` OAuth button (Google / Apple).
class FirebaseAuthReceived extends FirebaseLoginEvent {
  FirebaseAuthReceived(this.authState);
  final fb_ui_auth.AuthState authState;
}
