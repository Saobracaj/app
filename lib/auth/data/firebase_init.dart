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

  try {
    final googleClientId = DefaultFirebaseOptions.currentPlatform.appId;
    FirebaseUIAuth.configureProviders([
      GoogleProvider(clientId: googleClientId),
      fb_ui_oauth_apple.AppleProvider(),
    ]);
  } catch (e) {
    debugPrint('FirebaseUIAuth.configureProviders failed: $e');
  }
}
