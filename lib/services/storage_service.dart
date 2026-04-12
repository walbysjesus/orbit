import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Servicio para subir y descargar archivos multimedia (imágenes, audio, video) a Firebase Storage.
/// - Soporta subida, descarga y borrado seguro de archivos.
/// - Maneja errores automáticamente y expone logs para debug.
class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Sube un archivo a Firebase Storage y retorna la URL pública.
  /// [file] es el archivo local, [path] es la ruta destino en el bucket.
  static Future<String> uploadFile({
    required File file,
    required String path,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e, st) {
      debugPrint('Error subiendo archivo: $e\n$st');
      rethrow;
    }
  }

  /// Descarga un archivo de Firebase Storage y retorna los bytes.
  static Future<Uint8List?> downloadFile(String path) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.getData();
    } catch (e, st) {
      debugPrint('Error descargando archivo: $e\n$st');
      return null;
    }
  }

  /// Borra un archivo de Firebase Storage.
  static Future<void> deleteFile(String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e, st) {
      debugPrint('Error borrando archivo: $e\n$st');
    }
  }
}
