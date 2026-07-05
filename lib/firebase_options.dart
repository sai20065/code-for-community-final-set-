// Generated via `firebase apps:sdkconfig` against the real Firebase project
// `code-for-community-e2cf2` (Firestore + Auth registered; Cloud Storage and
// Google Maps are gated on attaching a billing account — see README).
//
// These are client identifiers, not secrets — Firebase access is controlled
// by Firestore/Storage security rules, not by keeping this file private.
// If you re-run `flutterfire configure`, it will regenerate this file.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
          'Run `flutterfire configure` to generate real options.',
        );
    }
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyBDeALZzviH5X5yGWb7HoVtTtaEHQfadSM',
    appId: '1:830098066112:web:950ea060ae513d25cf7b25',
    messagingSenderId: '830098066112',
    projectId: 'code-for-community-e2cf2',
    authDomain: 'code-for-community-e2cf2.firebaseapp.com',
    storageBucket: 'code-for-community-e2cf2.firebasestorage.app',
    measurementId: 'G-T4V9BT0VT1',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyC_JMVqHbQ1UCqv8FL0huJUBVbTb6KetEs',
    appId: '1:830098066112:android:3f605559297211dfcf7b25',
    messagingSenderId: '830098066112',
    projectId: 'code-for-community-e2cf2',
    storageBucket: 'code-for-community-e2cf2.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyDxKAGN7PmCPKBu5Q0ufs-cQwyD-TAcRP0',
    appId: '1:830098066112:ios:7cb29b66b1caa048cf7b25',
    messagingSenderId: '830098066112',
    projectId: 'code-for-community-e2cf2',
    storageBucket: 'code-for-community-e2cf2.firebasestorage.app',
    iosBundleId: 'com.prajadhvani.app',
  );
}
