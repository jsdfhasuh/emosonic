import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';
import 'logger.dart';

/// Service for encrypting and decrypting sensitive data like passwords
/// Uses AES-GCM for authenticated encryption with random nonce per encryption
class EncryptionService {
  static const String _keyStorageKey = 'encryption_key_v2';
  static const String _encryptedPrefixV2 = 'ENCv2:';
  static EncryptionService? _instance;
  late encrypt.Key _key;
  final Logger _logger = Logger('EncryptionService');

  EncryptionService._();

  static Future<EncryptionService> getInstance() async {
    if (_instance == null) {
      _instance = EncryptionService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  /// Initialize the encryption service with a stored or new key
  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    String? keyString = prefs.getString(_keyStorageKey);

    if (keyString == null) {
      // Generate a new random key (256-bit for AES-256-GCM)
      final random = Random.secure();
      final keyBytes = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        keyBytes[i] = random.nextInt(256);
      }
      keyString = base64Encode(keyBytes);
      await prefs.setString(_keyStorageKey, keyString);
      _logger.info('Generated new encryption key');
    }

    final keyBytes = base64Decode(keyString);
    _key = encrypt.Key(keyBytes);
  }

  /// Encrypt a plaintext string using AES-GCM
  /// Returns encrypted string with format: ENCv2:nonce_b64:ciphertext_b64
  String encryptString(String plaintext) {
    try {
      // Generate random 12-byte nonce for GCM
      final random = Random.secure();
      final nonceBytes = Uint8List(12);
      for (int i = 0; i < 12; i++) {
        nonceBytes[i] = random.nextInt(256);
      }
      final nonce = encrypt.IV(nonceBytes);

      // Create GCM encrypter
      final encrypter = encrypt.Encrypter(
        encrypt.AES(_key, mode: encrypt.AESMode.gcm),
      );

      // Encrypt
      final encrypted = encrypter.encrypt(plaintext, iv: nonce);

      // Format: ENCv2:<nonce_b64>:<ciphertext_b64>:<tag_b64>
      // Note: In GCM mode, the tag is appended to the ciphertext by the encrypt package
      final nonceB64 = base64Encode(nonce.bytes);
      final cipherB64 = encrypted.base64;

      return '$_encryptedPrefixV2$nonceB64:$cipherB64';
    } catch (e) {
      throw EncryptionException('Failed to encrypt data: $e');
    }
  }

  /// Decrypt an encrypted string
  /// Only handles ENCv2: format (AES-GCM)
  String decryptString(String encryptedValue) {
    try {
      if (!encryptedValue.startsWith(_encryptedPrefixV2)) {
        throw EncryptionException('Unsupported encryption format');
      }

      // Parse format: ENCv2:<nonce_b64>:<ciphertext_b64>
      final parts = encryptedValue.substring(_encryptedPrefixV2.length).split(':');
      if (parts.length != 2) {
        throw EncryptionException('Invalid encrypted format');
      }

      final nonceBytes = base64Decode(parts[0]);
      final cipherBytes = base64Decode(parts[1]);

      final nonce = encrypt.IV(Uint8List.fromList(nonceBytes));
      final encrypted = encrypt.Encrypted(Uint8List.fromList(cipherBytes));

      // Create GCM encrypter
      final encrypter = encrypt.Encrypter(
        encrypt.AES(_key, mode: encrypt.AESMode.gcm),
      );

      return encrypter.decrypt(encrypted, iv: nonce);
    } catch (e) {
      throw EncryptionException('Failed to decrypt data: $e');
    }
  }

  /// Check if a string is encrypted with the new format (ENCv2:)
  bool isEncrypted(String value) {
    return value.startsWith(_encryptedPrefixV2);
  }

  /// Check if a string is an old format encrypted password (ENC: or base64)
  bool isOldFormat(String value) {
    if (value.startsWith('ENC:')) {
      return true;
    }
    // Check for legacy format (base64 encoded, length >= 16)
    try {
      final decoded = base64Decode(value);
      return decoded.length >= 16;
    } catch (e) {
      return false;
    }
  }
}

/// Exception thrown when encryption/decryption fails
class EncryptionException implements Exception {
  final String message;
  EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}
