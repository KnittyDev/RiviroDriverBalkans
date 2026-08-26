import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';

class EncryptionService {
  // Secret salt used for application-level HMAC/Key Derivation (100% matches rider app)
  static const String _appSalt = "RIVILO_BALKANS_SECURE_CHAT_SALT_2026_AES256";

  /// Derive a deterministic 256-bit (32 bytes) AES Key for a specific ride
  static enc.Key _deriveKeyForRide(String rideId) {
    final rawKeyBytes = utf8.encode("$rideId:$_appSalt");
    final digest = sha256.convert(rawKeyBytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// Encrypt a JSON map payload (sender_id, sender_role, message, metadata)
  /// Returns a Map with {'encrypted_payload': base64Cipher, 'iv': base64Iv}
  static Map<String, String> encryptMap({
    required String rideId,
    required Map<String, dynamic> payload,
  }) {
    try {
      final key = _deriveKeyForRide(rideId);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final jsonString = jsonEncode(payload);
      final encrypted = encrypter.encrypt(jsonString, iv: iv);

      return {
        'encrypted_payload': encrypted.base64,
        'iv': iv.base64,
      };
    } catch (e) {
      debugPrint('Encryption error: $e');
      return {
        'encrypted_payload': '',
        'iv': '',
      };
    }
  }

  /// Decrypt an encrypted payload back into a Map<String, dynamic>
  static Map<String, dynamic>? decryptMap({
    required String rideId,
    required String encryptedBase64,
    required String ivBase64,
  }) {
    if (encryptedBase64.isEmpty || ivBase64.isEmpty) return null;

    try {
      final key = _deriveKeyForRide(rideId);
      final iv = enc.IV.fromBase64(ivBase64);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final decryptedString = encrypter.decrypt64(encryptedBase64, iv: iv);
      final decoded = jsonDecode(decryptedString) as Map<String, dynamic>;
      return decoded;
    } catch (e) {
      debugPrint('Decryption error: $e');
      return null;
    }
  }
}
