// PLACEHOLDER — regenerate with the FlutterFire CLI.
//
// Run the following from `app/` to overwrite this file with real credentials
// for the `at.gleb.saobracaj` (Android) / `at.gleb.saobracaj.saobracaj` (iOS)
// Firebase apps, and to drop google-services.json / GoogleService-Info.plist
// into the platform folders:
//
//     dart pub global activate flutterfire_cli
//     flutterfire configure
//
// Until then these placeholder values let the project compile; Firebase social
// sign-in stays disabled at runtime (see initFirebase() in
// lib/auth/data/firebase_init.dart, which fails soft).
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform. '
          'Run `flutterfire configure` to generate lib/firebase_options.dart.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDyEU8ZO-H7Kf4Ftxc-uUEh91j302tFQZE',
    appId: '1:1039935330316:web:7433eec5b687bbc5bcf629',
    messagingSenderId: '1039935330316',
    projectId: 'saobracaj-7fd5e',
    authDomain: 'saobracaj-7fd5e.firebaseapp.com',
    storageBucket: 'saobracaj-7fd5e.firebasestorage.app',
    measurementId: 'G-EEKGVHB3BM',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDHHTosShAz7r4AWDIX4aChMRBp-dEJiVI',
    appId: '1:1039935330316:android:7563c90f12d1dbf4bcf629',
    messagingSenderId: '1039935330316',
    projectId: 'saobracaj-7fd5e',
    storageBucket: 'saobracaj-7fd5e.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBNbPaaYr6K2SUm4Buu8_bdlmsz0LXwHo8',
    appId: '1:1039935330316:ios:765e90f2d92af606bcf629',
    messagingSenderId: '1039935330316',
    projectId: 'saobracaj-7fd5e',
    storageBucket: 'saobracaj-7fd5e.firebasestorage.app',
    iosClientId: '1039935330316-rnhorhr3nqrmpoi7cpfrppdfcbichn2b.apps.googleusercontent.com',
    iosBundleId: 'at.gleb.saobracaj.saobracaj',
  );
}
