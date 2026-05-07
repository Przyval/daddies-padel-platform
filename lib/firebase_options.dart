import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
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
          'DefaultFirebaseOptions not configured for ${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCVVVYlPtioX8HDDziEae_xG5Y999jaj6Q',
    appId: '1:507873202149:web:396ce0d222ed70b30d698c',
    messagingSenderId: '507873202149',
    projectId: 'padel-daddies',
    authDomain: 'padel-daddies.firebaseapp.com',
    storageBucket: 'padel-daddies.firebasestorage.app',
    measurementId: 'G-YHP9QZD7L5',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCbTo54LKH85y2Ncw07dp99u_5ToXZs-oI',
    appId: '1:507873202149:android:098196348ffbd7960d690c',
    messagingSenderId: '507873202149',
    projectId: 'padel-daddies',
    storageBucket: 'padel-daddies.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDYJn_yFJ8s7Qh53T4yyWMujZ0KfqIS2jY',
    appId: '1:507873202149:ios:e271a7fa77718ab10d690c',
    messagingSenderId: '507873202149',
    projectId: 'padel-daddies',
    storageBucket: 'padel-daddies.firebasestorage.app',
    iosBundleId: 'com.daddies.daddiesApp',
  );
}
