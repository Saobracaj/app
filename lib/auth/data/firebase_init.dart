import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_apple/firebase_ui_oauth_apple.dart'
    as fb_ui_oauth_apple;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Initialise Firebase and register the Google / Apple providers used for
/// social sign-in.
///
/// Firebase is used for exactly one thing here: obtaining an OAuth ID token that
/// the back-end `firebaseAuth` mutation exchanges for our own session tokens.
/// The social buttons are therefore *always* shown; this init only wires the
/// providers up. Initialisation failures are swallowed (logged) so a transient
/// problem never takes the whole app down — same approach as owncup.
Future<void> initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // A duplicate-app error just means Firebase is already initialised.
    if (!e.toString().contains('duplicate-app')) {
      debugPrint('Firebase.initializeApp failed: $e');
    }
  }

  // На web провайдеры firebase_ui не настраиваем: вход там идёт напрямую через
  // `signInWithPopup` (см. FirebaseLoginBloc._webSignIn), а конструктор
  // GoogleProvider создаёт GoogleSignIn, который на web инициализирует GIS SDK
  // прямо в конструкторе и без client_id кидает необработанное исключение.
  if (kIsWeb) return;

  try {
    FirebaseUIAuth.configureProviders([
      GoogleProvider(clientId: googleOAuthClientId),
      fb_ui_oauth_apple.AppleProvider(),
    ]);
  } catch (e) {
    debugPrint('FirebaseUIAuth.configureProviders failed: $e');
  }
}

/// The OAuth client id for Google Sign-In — the single source of truth for
/// every `GoogleProvider` in the app.
///
/// It is the *OAuth* client id, NOT `options.appId` (the Firebase app id):
/// passing the app id makes the native GoogleSignIn SDK fail on iOS. Only the
/// native flows read it — on Android the plugin takes the client id from
/// google-services.json, and on the web firebase_ui_oauth_google signs in
/// through `signInWithPopup` — so an empty string is the correct value there.
String get googleOAuthClientId {
  final options = DefaultFirebaseOptions.currentPlatform;
  final clientId = switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => options.iosClientId,
    TargetPlatform.android => options.androidClientId,
    _ => null,
  };
  return clientId ?? '';
}
