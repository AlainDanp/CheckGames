import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web not configured');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS not configured');
      case TargetPlatform.macOS:
        throw UnsupportedError('MacOS not configured');
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB7rZ8MdgwPwG1YlMVUAJDvXd5b1GmEi9U',
    appId: '1:114628623792:android:4acaf64eddc5907022ea75',
    messagingSenderId: '114628623792',
    projectId: 'checkgames',
    storageBucket: 'checkgames.firebasestorage.app',
  );

}