// Firebase Cloud Messaging service worker.
//
// firebase_messaging_web looks for this file at `<base href>firebase-messaging-sw.js`
// and registers it on the first getToken() call; without it the call fails with
// "Failed to register a ServiceWorker" and the browser never gets a push token.
// The worker is what shows a notification while the tab is closed or in the
// background — the foreground case is handled by FirebaseMessaging.onMessage in
// Dart.
//
// The config below is DefaultFirebaseOptions.web from lib/firebase_options.dart;
// a service worker cannot read Dart's --dart-define values, so it is duplicated
// here. These values are public (they already ship inside the JS bundle), unlike
// the VAPID key, which is passed to getToken() from Dart.
//
// The SDK version must match `supportedFirebaseJsSdkVersion` from the
// firebase_core_web package that pubspec.lock resolves to — bump both together.
importScripts(
  'https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyDyEU8ZO-H7Kf4Ftxc-uUEh91j302tFQZE',
  appId: '1:1039935330316:web:7433eec5b687bbc5bcf629',
  messagingSenderId: '1039935330316',
  projectId: 'saobracaj-7fd5e',
  authDomain: 'saobracaj-7fd5e.firebaseapp.com',
  storageBucket: 'saobracaj-7fd5e.firebasestorage.app',
  measurementId: 'G-EEKGVHB3BM',
});

// Instantiating messaging is enough: the SDK installs its own `push` handler,
// which shows the `notification` block of the payload on its own. Only a
// data-only message would need an onBackgroundMessage handler here.
firebase.messaging();
