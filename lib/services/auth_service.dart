
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ================== REGISTER ==================
  static Future<void> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw Exception('Usuario no creado');
      }
      if (fullName != null) {
        await user.updateDisplayName(fullName);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e.code));
    }
  }

  // ================== LOGIN ==================
  static Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user == null) {
        throw Exception('Login inválido');
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e.code));
    }
  }

  // ================== SESSION ==================
  static Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ================== UTIL ==================
  static String _firebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este correo ya está registrado';
      case 'invalid-email':
        return 'Correo inválido';
      case 'weak-password':
        return 'La contraseña es muy débil';
      case 'user-not-found':
        return 'Usuario no existe';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      default:
        return 'Error de autenticación';
    }
  }
}
