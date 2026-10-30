// Default FirebaseOptions stub for WasteWise mobile app
// Replace with your project's generated firebase_options.dart from `flutterfire configure`

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
    apiKey: 'AIzaSy-demo-key-web',
    appId: '1:123456789:web:abcdef',
    messagingSenderId: '123456789',
    projectId: 'waste-wise-demo',
    authDomain: 'waste-wise-demo.firebaseapp.com',
    storageBucket: 'waste-wise-demo.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSy-demo-key-android',
    appId: '1:123456789:android:abcdef',
    messagingSenderId: '123456789',
    projectId: 'waste-wise-demo',
    storageBucket: 'waste-wise-demo.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSy-demo-key-ios',
    appId: '1:123456789:ios:abcdef',
    messagingSenderId: '123456789',
    projectId: 'waste-wise-demo',
    storageBucket: 'waste-wise-demo.appspot.com',
    iosBundleId: 'com.example.wasteMgmtApp',
  );
}
