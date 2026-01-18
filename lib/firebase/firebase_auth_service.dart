import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ================= REGISTER =================
  static Future<User?> register({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  // ================= LOGIN =================
  static Future<User?> login({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  // ================= SESSION =================
  static bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  static User? currentUser() {
    return _auth.currentUser;
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }
}