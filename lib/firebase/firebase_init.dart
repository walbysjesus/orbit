import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:orbit/config/config.dart';
import 'package:orbit/firebase_options.dart';

class FirebaseInit {
  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await configureFirebaseServices();
  }
}