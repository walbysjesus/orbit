import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utilidad para validar autenticación y diagnosticar problemas Firebase
class FirebaseAuthValidator {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  /// Verifica si el usuario está autenticado
  static bool isAuthenticated() {
    return _auth.currentUser != null;
  }

  /// Obtiene el UID actual o vacío si no autenticado
  static String getCurrentUid() {
    return _auth.currentUser?.uid ?? '';
  }

  /// Verifica acceso a Firestore con una query de prueba
  static Future<bool> canAccessFirestore() async {
    try {
      final uid = getCurrentUid();
      if (uid.isEmpty) {
        debugPrint('[FirebaseAuthValidator] ❌ No autenticado');
        return false;
      }

      // Intenta leer un documento pequeño para verificar permisos
      await _db.collection('users').doc(uid).get();
      debugPrint('[FirebaseAuthValidator] ✅ Acceso a Firestore OK');
      return true;
    } on FirebaseException catch (e) {
      debugPrint(
          '[FirebaseAuthValidator] ⚠️ Firestore error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[FirebaseAuthValidator] ⚠️ Acceso a Firestore: $e');
      return false;
    }
  }

  /// Diagnostica problemas de Firebase
  static Future<FirebaseDiagnostics> diagnose() async {
    final isAuth = isAuthenticated();
    final canAccess = isAuth ? await canAccessFirestore() : false;

    return FirebaseDiagnostics(
      isAuthenticated: isAuth,
      canAccessFirestore: canAccess,
      currentUid: getCurrentUid(),
      firebaseUser: _auth.currentUser,
    );
  }

  /// Log completo de diagnóstico
  static Future<void> printDiagnostics() async {
    final diag = await diagnose();
    debugPrint('''
╔════════════════════════════════════════════╗
║   Firebase Authentication Status           ║
╠════════════════════════════════════════════╣
║ Autenticado:       ${diag.isAuthenticated ? '✅ SÍ' : '❌ NO'}
║ UID:               ${diag.currentUid.isNotEmpty ? diag.currentUid : '(vacío)'}
║ Acceso Firestore:  ${diag.canAccessFirestore ? '✅ SÍ' : '❌ NO'}
║ Email:             ${diag.firebaseUser?.email ?? '(sin email)'}
║ Provider:          ${diag.firebaseUser?.providerData.isNotEmpty ?? false ? '✅ Vinculado' : '❌ No vinculado'}
╚════════════════════════════════════════════╝
    ''');
  }
}

/// Resultado del diagnóstico Firebase
class FirebaseDiagnostics {
  final bool isAuthenticated;
  final bool canAccessFirestore;
  final String currentUid;
  final User? firebaseUser;

  FirebaseDiagnostics({
    required this.isAuthenticated,
    required this.canAccessFirestore,
    required this.currentUid,
    this.firebaseUser,
  });

  /// Resumen en texto
  String get summary {
    if (!isAuthenticated) return 'No autenticado';
    if (!canAccessFirestore) return 'Autenticado pero sin acceso a Firestore';
    return 'Autenticado y con acceso a Firestore ✅';
  }

  /// ¿Está completamente listo?
  bool get isReady => isAuthenticated && canAccessFirestore;
}
