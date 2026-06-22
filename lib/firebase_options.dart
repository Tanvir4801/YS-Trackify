import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

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
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCl8uA0m4UNggUt9-fwcU8oY5Z9u9Z6sV4',
    appId: '1:487752590406:web:0000000000000000000000',
    messagingSenderId: '487752590406',
    projectId: 'ys-construction',
    authDomain: 'ys-construction.firebaseapp.com',
    storageBucket: 'ys-construction.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCl8uA0m4UNggUt9-fwcU8oY5Z9u9Z6sV4',
    appId: '1:487752590406:android:cd252b86dd246509581647',
    messagingSenderId: '487752590406',
    projectId: 'ys-construction',
    storageBucket: 'ys-construction.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAgi1TQR8riIgfMckxXhrgmiH6YTZk_YXw',
    appId: '1:487752590406:ios:6072e3095352973f581647',
    messagingSenderId: '487752590406',
    projectId: 'ys-construction',
    storageBucket: 'ys-construction.firebasestorage.app',
    iosBundleId: 'com.trackify.ys',
  );
}