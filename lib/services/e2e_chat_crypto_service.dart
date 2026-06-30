import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/config.dart';

class E2EChatCryptoService {
  static const String _roomMarker = 'e2er2';
  static const String _roomLegacyMarker = 'e2er1';
  static const String _localMarker = 'e2el2';
  static const String _localLegacyMarker = 'e2el1';

  static const String _payloadVersion = 'v1';
  static const String _defaultKeyId = 'k1';

  static const int _gcmIvLength = 12;
  static const int _gcmTagLength = 16;

  static const String _localKeyStorageKey = 'orbit_local_chat_key_v1';
  static const String _roomMasterStorageKey = 'orbit_chat_room_master_key_v1';

  // Clave base fija del app — igual en todos los dispositivos.
  // Permite que cualquier usuario cifre/descifre sin configuración adicional.
  // En producción se puede sobreescribir con CHAT_LOCAL_AES_KEY para mayor seguridad.
  static const String _appDefaultMasterKey =
      'orbit-app-base-key-2024-v1-shared-all-users-32b';

  final FlutterSecureStorage _secureStorage;
  final Random _random;

  String? _localSecret;
  bool _initialized = false;

  E2EChatCryptoService({
    FlutterSecureStorage? secureStorage,
    Random? random,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _random = random ?? Random.secure();

  Future<void> initialize() async {
    if (_initialized) return;

    // Resolve room master key from dart-define first and persist it for
    // continuity. In debug, allow secure local generation only if undefined.
    final configuredMaster = _normalizedMasterKey(chatLocalEncryptionKey);
    String? storedRoomMaster;
    try {
      storedRoomMaster = _normalizedMasterKey(
        await _secureStorage.read(key: _roomMasterStorageKey),
      );
    } catch (e) {
      debugPrint(
          '[E2EChatCryptoService] No se pudo leer room master de secure storage: $e');
    }

    if (configuredMaster != null) {
      if (storedRoomMaster != configuredMaster) {
        try {
          await _secureStorage.write(
            key: _roomMasterStorageKey,
            value: configuredMaster,
          );
        } catch (e) {
          debugPrint(
              '[E2EChatCryptoService] No se pudo persistir room master configurado: $e');
        }
      }
    } else if (!kReleaseMode) {
      final generatedRoomMaster = base64Encode(_randomBytes(32));
      try {
        await _secureStorage.write(
          key: _roomMasterStorageKey,
          value: generatedRoomMaster,
        );
      } catch (e) {
        debugPrint(
            '[E2EChatCryptoService] No se pudo persistir room master generado: $e');
      }
    }

    String? existing;
    try {
      existing = await _secureStorage.read(key: _localKeyStorageKey);
    } catch (e) {
      debugPrint(
          '[E2EChatCryptoService] No se pudo leer local key de secure storage: $e');
    }
    if (existing != null && existing.isNotEmpty) {
      _localSecret = existing;
      _initialized = true;
      return;
    }

    final generated = base64Encode(_randomBytes(32));
    try {
      await _secureStorage.write(key: _localKeyStorageKey, value: generated);
    } catch (e) {
      debugPrint(
          '[E2EChatCryptoService] No se pudo persistir local key en secure storage: $e');
    }
    _localSecret = generated;
    _initialized = true;
  }

  String encryptForRoom({
    required String roomId,
    required String plainText,
  }) {
    final key = _deriveRoomKey(roomId);
    return _encryptGcmWithKey(
        plainText: plainText, key: key, marker: _roomMarker);
  }

  String decryptForRoom({
    required String roomId,
    required String cipherText,
  }) {
    final key = _tryDeriveRoomKey(roomId);
    if (key == null) {
      return cipherText;
    }

    final gcmResult = _tryDecryptGcmWithKey(
      payload: cipherText,
      key: key,
      marker: _roomMarker,
    );
    if (gcmResult != null) return gcmResult;

    final legacyResult = _tryDecryptLegacyCbcWithKey(
      payload: cipherText,
      key: key,
      marker: _roomLegacyMarker,
    );
    if (legacyResult != null) return legacyResult;

    return cipherText;
  }

  String encryptLocal(String plainText) {
    final key = _deriveLocalKey();
    return _encryptGcmWithKey(
      plainText: plainText,
      key: key,
      marker: _localMarker,
    );
  }

  String decryptLocal(String cipherText) {
    final key = _deriveLocalKey();
    final gcmResult = _tryDecryptGcmWithKey(
      payload: cipherText,
      key: key,
      marker: _localMarker,
    );
    if (gcmResult != null) return gcmResult;

    final legacyResult = _tryDecryptLegacyCbcWithKey(
      payload: cipherText,
      key: key,
      marker: _localLegacyMarker,
    );
    if (legacyResult != null) return legacyResult;

    return cipherText;
  }

  encrypt.Key _deriveRoomKey(String roomId) {
    // _tryDeriveRoomKey siempre retorna una clave válida ahora.
    return _tryDeriveRoomKey(roomId)!;
  }

  encrypt.Key? _tryDeriveRoomKey(String roomId) {
    final configuredMaster = _normalizedMasterKey(chatLocalEncryptionKey);
    // Prioridad: dart-define -> clave fija del app. No depender de claves por-dispositivo.
    final activeMaster = configuredMaster ?? _appDefaultMasterKey;
    return _buildRoomKey(roomId: roomId, master: activeMaster);
  }

  encrypt.Key _buildRoomKey({
    required String roomId,
    required String master,
  }) {
    final digest = sha256.convert(
      utf8.encode('orbit-e2e-room|$master|$roomId'),
    );
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  encrypt.Key _deriveLocalKey() {
    if (!_initialized || _localSecret == null || _localSecret!.isEmpty) {
      throw StateError('Cifrado local no inicializado');
    }

    final digest = sha256.convert(
      utf8.encode('orbit-e2e-local|${_localSecret!}'),
    );
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  String _encryptGcmWithKey({
    required String plainText,
    required encrypt.Key key,
    required String marker,
  }) {
    final ivBytes = _randomBytes(_gcmIvLength);
    final iv = encrypt.IV(ivBytes);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(
        key,
        mode: encrypt.AESMode.gcm,
        padding: null,
      ),
    );
    final encrypted = encrypter.encryptBytes(
      Uint8List.fromList(utf8.encode(plainText)),
      iv: iv,
    );
    // Almacenamos el payload completo como lo devuelve la librería (incluye tag GCM).
    // Formato 5 partes: marker:version:keyId:iv_b64:payload_b64
    return [
      marker,
      _payloadVersion,
      _defaultKeyId,
      base64Encode(ivBytes),
      base64Encode(encrypted.bytes),
    ].join(':');
  }

  String? _tryDecryptGcmWithKey({
    required String payload,
    required encrypt.Key key,
    required String marker,
  }) {
    if (!payload.startsWith('$marker:')) {
      return null;
    }

    final parts = payload.split(':');
    // Soporta formato nuevo (5 partes: marker:ver:kid:iv:payload)
    // y formato legacy (6 partes: marker:ver:kid:iv:cipher:tag).
    if (parts.length != 5 && parts.length != 6) {
      return null;
    }
    if (parts[1] != _payloadVersion) {
      return null;
    }

    try {
      final ivBytes = base64Decode(parts[3]);
      if (ivBytes.length != _gcmIvLength) return null;

      final Uint8List combinedBytes;
      if (parts.length == 5) {
        // Nuevo formato: payload completo (la librería incluye el tag).
        combinedBytes = base64Decode(parts[4]);
      } else {
        // Formato legacy: cipher (parts[4]) + tag (parts[5]) separados.
        final cipherBytes = base64Decode(parts[4]);
        final tagBytes = base64Decode(parts[5]);
        if (tagBytes.length != _gcmTagLength) return null;
        combinedBytes = Uint8List(cipherBytes.length + tagBytes.length)
          ..setRange(0, cipherBytes.length, cipherBytes)
          ..setRange(
              cipherBytes.length, cipherBytes.length + tagBytes.length, tagBytes);
      }

      final iv = encrypt.IV(ivBytes);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(
          key,
          mode: encrypt.AESMode.gcm,
          padding: null,
        ),
      );
      final decryptedBytes = encrypter.decryptBytes(
        encrypt.Encrypted(combinedBytes),
        iv: iv,
      );
      return utf8.decode(decryptedBytes, allowMalformed: false);
    } catch (_) {
      return null;
    }
  }

  String? _tryDecryptLegacyCbcWithKey({
    required String payload,
    required encrypt.Key key,
    required String marker,
  }) {
    if (!payload.startsWith('$marker:')) {
      return payload;
    }

    final parts = payload.split(':');
    if (parts.length < 3) {
      return null;
    }

    try {
      final ivBytes = base64Decode(parts[1]);
      if (ivBytes.length != 16) {
        return null;
      }
      final cipherText = parts.sublist(2).join(':');
      final iv = encrypt.IV(ivBytes);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      return encrypter.decrypt64(cipherText, iv: iv);
    } catch (_) {
      return null;
    }
  }

  String? _normalizedMasterKey(String? value) {
    final candidate = (value ?? '').trim();
    if (candidate.length < 32) return null;
    return candidate;
  }

  Uint8List _randomBytes(int length) {
    final values = List<int>.generate(length, (_) => _random.nextInt(256));
    return Uint8List.fromList(values);
  }
}
