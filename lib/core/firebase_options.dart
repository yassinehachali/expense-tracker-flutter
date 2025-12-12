// File: lib/core/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // For this migration, we are using the Web keys as defaults for other platforms 
    // to allow quick start, but ideally Android/iOS should use google-services.json
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCHha5j3Se0jiFs1Vp3N4jXjBGkxtqtPhw',
    appId: '1:240440981774:web:35708918a4fdb03eab7f5f',
    messagingSenderId: '240440981774',
    projectId: 'expense-tracker-8eca3',
    authDomain: 'expense-tracker-8eca3.firebaseapp.com',
    storageBucket: 'expense-tracker-8eca3.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCHha5j3Se0jiFs1Vp3N4jXjBGkxtqtPhw',
    appId: '1:240440981774:web:35708918a4fdb03eab7f5f', // Placeholder
    messagingSenderId: '240440981774',
    projectId: 'expense-tracker-8eca3',
    storageBucket: 'expense-tracker-8eca3.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCHha5j3Se0jiFs1Vp3N4jXjBGkxtqtPhw',
    appId: '1:240440981774:web:35708918a4fdb03eab7f5f', // Placeholder
    messagingSenderId: '240440981774',
    projectId: 'expense-tracker-8eca3',
    storageBucket: 'expense-tracker-8eca3.firebasestorage.app',
    iosClientId: '240440981774-ios.apps.googleusercontent.com', // Placeholder
    iosBundleId: 'com.example.expenseTracker',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCHha5j3Se0jiFs1Vp3N4jXjBGkxtqtPhw',
    appId: '1:240440981774:web:35708918a4fdb03eab7f5f', // Placeholder
    messagingSenderId: '240440981774',
    projectId: 'expense-tracker-8eca3',
    storageBucket: 'expense-tracker-8eca3.firebasestorage.app',
    iosClientId: '240440981774-macos.apps.googleusercontent.com', // Placeholder
    iosBundleId: 'com.example.expenseTracker',
  );
}
