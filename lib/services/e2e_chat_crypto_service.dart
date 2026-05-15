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

  final FlutterSecureStorage _secureStorage;
  final Random _random;

  String? _localSecret;
  String? _roomMasterSecret;
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
    final storedRoomMaster = _normalizedMasterKey(
        await _secureStorage.read(key: _roomMasterStorageKey));

    if (configuredMaster != null) {
      _roomMasterSecret = configuredMaster;
      if (storedRoomMaster != configuredMaster) {
        await _secureStorage.write(
          key: _roomMasterStorageKey,
          value: configuredMaster,
        );
      }
    } else if (storedRoomMaster != null) {
      _roomMasterSecret = storedRoomMaster;
    } else if (!kReleaseMode) {
      final generatedRoomMaster = base64Encode(_randomBytes(32));
      await _secureStorage.write(
        key: _roomMasterStorageKey,
        value: generatedRoomMaster,
      );
      _roomMasterSecret = generatedRoomMaster;
    }

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
    final key = _tryDeriveRoomKey(roomId);
    if (key == null) {
      throw StateError(
        'CHAT_LOCAL_AES_KEY inválida. Debe tener al menos 32 caracteres o estar disponible en almacenamiento seguro.',
      );
    }
    return key;
  }

  encrypt.Key? _tryDeriveRoomKey(String roomId) {
    final configuredMaster = _normalizedMasterKey(chatLocalEncryptionKey);
    final activeMaster =
        configuredMaster ?? _normalizedMasterKey(_roomMasterSecret);
    if (activeMaster == null) {
      return null;
    }
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
    final encryptedBytes = encrypted.bytes;
    if (encryptedBytes.length < (_gcmTagLength + 1)) {
      throw StateError('No se pudo generar payload AES-GCM válido.');
    }

    final cipherBytes =
        encryptedBytes.sublist(0, encryptedBytes.length - _gcmTagLength);
    final tagBytes =
        encryptedBytes.sublist(encryptedBytes.length - _gcmTagLength);
    return [
      marker,
      _payloadVersion,
      _defaultKeyId,
      base64Encode(ivBytes),
      base64Encode(cipherBytes),
      base64Encode(tagBytes),
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
    if (parts.length != 6) {
      return null;
    }
    if (parts[1] != _payloadVersion) {
      return null;
    }

    try {
      final ivBytes = base64Decode(parts[3]);
      final cipherBytes = base64Decode(parts[4]);
      final tagBytes = base64Decode(parts[5]);
      if (ivBytes.length != _gcmIvLength || tagBytes.length != _gcmTagLength) {
        return null;
      }

      final combinedBytes = Uint8List(cipherBytes.length + tagBytes.length)
        ..setRange(0, cipherBytes.length, cipherBytes)
        ..setRange(
            cipherBytes.length, cipherBytes.length + tagBytes.length, tagBytes);

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
