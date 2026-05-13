import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions no esta configurado para web. '
        'Ejecuta FlutterFire CLI para agregar esa plataforma.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions no esta configurado para macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions no esta configurado para Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions no esta configurado para Linux.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions no esta configurado para Fuchsia.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAOE_bha-j2rBB7Ofc4HsvOlmwkhAGFIGE',
    appId: '1:1040464298596:android:4d3058bb74cf81ae049571',
    messagingSenderId: '1040464298596',
    projectId: 'orbit-app-1',
    storageBucket: 'orbit-app-1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC0r7EWpvSb7GyigFh3O-N2Bl-1OCMkGHw',
    appId: '1:1040464298596:ios:136eba6fff0a1b29049571',
    messagingSenderId: '1040464298596',
    projectId: 'orbit-app-1',
    storageBucket: 'orbit-app-1.firebasestorage.app',
    iosBundleId: 'com.orbit.app',
  );
}
