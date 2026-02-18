import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// AES-256-CBC encryption service for vault files.
class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _keyStorageKey = 'vault_encryption_key';
  static const _ivStorageKey = 'vault_encryption_iv';

  /// Get or generate the encryption key (stored in secure storage).
  static Future<enc.Key> _getKey() async {
    String? storedKey = await _storage.read(key: _keyStorageKey);
    if (storedKey == null) {
      // Generate a random 256-bit key
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
      storedKey = base64Encode(keyBytes);
      await _storage.write(key: _keyStorageKey, value: storedKey);
    }
    return enc.Key.fromBase64(storedKey);
  }

  /// Get or generate the IV (stored in secure storage).
  static Future<enc.IV> _getIV() async {
    String? storedIV = await _storage.read(key: _ivStorageKey);
    if (storedIV == null) {
      final random = Random.secure();
      final ivBytes = List<int>.generate(16, (_) => random.nextInt(256));
      storedIV = base64Encode(ivBytes);
      await _storage.write(key: _ivStorageKey, value: storedIV);
    }
    return enc.IV.fromBase64(storedIV);
  }

  /// Encrypt a file and save it to the app's private vault directory.
  /// Returns the path to the encrypted file.
  static Future<String> encryptFile(String sourcePath) async {
    final key = await _getKey();
    final iv = await _getIV();
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final sourceFile = File(sourcePath);
    final bytes = await sourceFile.readAsBytes();
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);

    // Save to app private vault directory
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${appDir.path}/vault_encrypted');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}.enc';
    final encryptedPath = '${vaultDir.path}/$fileName';
    await File(encryptedPath).writeAsBytes(encrypted.bytes);

    return encryptedPath;
  }

  /// Decrypt an encrypted file and return it as a temporary decrypted file.
  /// The caller should delete this temp file after use.
  static Future<String> decryptFile(String encryptedPath) async {
    final key = await _getKey();
    final iv = await _getIV();
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final encryptedFile = File(encryptedPath);
    final encryptedBytes = await encryptedFile.readAsBytes();
    final encrypted = enc.Encrypted(encryptedBytes);
    final decryptedBytes = encrypter.decryptBytes(encrypted, iv: iv);

    // Write to temp
    final tempDir = await getTemporaryDirectory();
    final originalName = p.basename(encryptedPath).replaceAll('.enc', '');
    final tempPath = '${tempDir.path}/$originalName';
    await File(tempPath).writeAsBytes(decryptedBytes);

    return tempPath;
  }

  /// Get the vault encrypted directory path.
  static Future<String> getVaultPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/vault_encrypted';
  }
}
