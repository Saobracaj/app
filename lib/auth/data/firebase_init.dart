import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_apple/firebase_ui_oauth_apple.dart'
    as fb_ui_oauth_apple;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// True once [initFirebase] has successfully initialised Firebase and
/// configured the OAuth providers. While false, [SocialLogin] hides the
/// Google / Apple buttons so an unconfigured project doesn't show dead buttons.
bool firebaseReady = false;

/// Initialise Firebase and register the Google / Apple providers used by
/// `firebase_ui_auth`. Fails soft: if the project hasn't been wired up yet
/// (placeholder `firebase_options.dart`, missing platform config) the app still
/// runs — only social sign-in stays unavailable.
Future<void> initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final googleClientId = DefaultFirebaseOptions.currentPlatform.appId;
    FirebaseUIAuth.configureProviders([
      GoogleProvider(clientId: googleClientId),
      fb_ui_oauth_apple.AppleProvider(),
    ]);
    firebaseReady = true;
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      firebaseReady = true;
      return;
    }
    // Not configured yet — leave social sign-in disabled but keep the app alive.
    debugPrint(
      'Firebase not initialised, social sign-in disabled. '
      'Run `flutterfire configure`. ($e)',
    );
  }
}
