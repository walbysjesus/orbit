import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/config.dart';

class E2EChatCryptoService {
  static const String _roomMarker = 'e2er1';
  static const String _localMarker = 'e2el1';
  static const String _localKeyStorageKey = 'orbit_local_chat_key_v1';

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

    final existing = await _secureStorage.read(key: _localKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      _localSecret = existing;
      _initialized = true;
      return;
    }

    final generated = base64Encode(_randomBytes(32));
    await _secureStorage.write(key: _localKeyStorageKey, value: generated);
    _localSecret = generated;
    _initialized = true;
  }

  String encryptForRoom({
    required String roomId,
    required String plainText,
  }) {
    final key = _deriveRoomKey(roomId);
    return _encryptWithKey(
      plainText: plainText,
      key: key,
      marker: _roomMarker,
    );
  }

  String decryptForRoom({
    required String roomId,
    required String cipherText,
  }) {
    final key = _deriveRoomKey(roomId);
    return _decryptWithKey(
      payload: cipherText,
      key: key,
      marker: _roomMarker,
    );
  }

  String encryptLocal(String plainText) {
    final key = _deriveLocalKey();
    return _encryptWithKey(
      plainText: plainText,
      key: key,
      marker: _localMarker,
    );
  }

  String decryptLocal(String cipherText) {
    final key = _deriveLocalKey();
    return _decryptWithKey(
      payload: cipherText,
      key: key,
      marker: _localMarker,
    );
  }

  encrypt.Key _deriveRoomKey(String roomId) {
    String master = chatLocalEncryptionKey.trim();
    if (master.length < 32) {
      if (kDebugMode) {
        // Clave de desarrollo — NO usar en producción.
        master = 'orbit-debug-dev-key-for-testing!'; // 32 chars
      } else {
        throw StateError(
            'CHAT_LOCAL_AES_KEY debe tener al menos 32 caracteres para E2E');
      }
    }

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

  String _encryptWithKey({
    required String plainText,
    required encrypt.Key key,
    required String marker,
  }) {
    final ivBytes = _randomBytes(16);
    final iv = encrypt.IV(ivBytes);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '$marker:${base64Encode(ivBytes)}:${encrypted.base64}';
  }

  String _decryptWithKey({
    required String payload,
    required encrypt.Key key,
    required String marker,
  }) {
    if (!payload.startsWith('$marker:')) {
      return payload;
    }

    final parts = payload.split(':');
    if (parts.length < 3) {
      return payload;
    }

    try {
      final ivBytes = base64Decode(parts[1]);
      final cipherText = parts.sublist(2).join(':');
      final iv = encrypt.IV(ivBytes);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      return encrypter.decrypt64(cipherText, iv: iv);
    } catch (_) {
      return payload;
    }
  }

  Uint8List _randomBytes(int length) {
    final values = List<int>.generate(length, (_) => _random.nextInt(256));
    return Uint8List.fromList(values);
  }
}
