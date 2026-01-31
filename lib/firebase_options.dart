import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with [Firebase.initializeApp].
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBWrtIYdCqMc4UUzXIOAjnqMJim4Z7Bm9M',
    appId: '1:319995267344:android:d6f430b8febc93fd907d95',
    messagingSenderId: '319995267344',
    projectId: 'kam-kam-82af0',
    storageBucket: 'kam-kam-82af0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBAYclLnQtdc8rqEcPM7UPOaQTCio3bba8',
    appId: '1:319995267344:ios:d18b8c370c7ff766907d95',
    messagingSenderId: '319995267344',
    projectId: 'kam-kam-82af0',
    storageBucket: 'kam-kam-82af0.firebasestorage.app',
    iosBundleId: 'com.rondohub.rondoHub',
  );
}
