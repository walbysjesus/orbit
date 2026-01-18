import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class FirebaseInit {
  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
  }
}