import 'dart:io';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class EncryptionService {
  // Use AES-GCM with 256-bit keys.
  // GCM is an Authenticated Encryption mode (AEAD), safer than CBC.
  static final _algorithm = AesGcm.with256bits();
  static const _storage = FlutterSecureStorage();
  static const _keyStorageKey = 'safe_shell_vault_key_v1';

  /// ─── Key Management ──────────────────────────────────────────────

  /// Retrieves the existing key or generates a new one if it doesn't exist.
  static Future<SecretKey> _getOrCreateKey() async {
    // 1. Try to read from secure storage
    String? storedKeyBase64 = await _storage.read(key: _keyStorageKey);

    if (storedKeyBase64 != null) {
      // 2. Decode existing key
      final keyBytes = base64Decode(storedKeyBase64);
      return SecretKey(keyBytes);
    } else {
      // 3. Generate new key
      final key = await _algorithm.newSecretKey();
      final keyBytes = await key.extractBytes();
      
      // 4. Save to secure storage
      await _storage.write(
        key: _keyStorageKey, 
        value: base64Encode(keyBytes),
      );
      
      return key;
    }
  }

  /// ─── File Operations ─────────────────────────────────────────────

  /// Encrypts a file from [sourcePath] and saves it to the App's secure vault.
  /// 
  /// Returns the path to the newly created encrypted file.
  /// 
  /// Structure of saved file: [Nonce (12 bytes)] + [Ciphertext] + [MAC (16 bytes)]
  static Future<String> encryptFile(String sourcePath) async {
    final key = await _getOrCreateKey();
    final file = File(sourcePath);
    
    // 1. Read bytes (Be careful with very large files > 500MB on mobile RAM)
    final clearText = await file.readAsBytes();

    // 2. Encrypt
    // The algorithm automatically generates a random 12-byte Nonce
    final secretBox = await _algorithm.encrypt(
      clearText,
      secretKey: key,
    );

    // 3. Prepare Vault Directory
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(appDir.path, 'vault_storage'));
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }

    // 4. Generate Filename (Timestamp + Original Extension)
    // We obscure the original filename for privacy.
    final ext = p.extension(sourcePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newFileName = 'enc_$timestamp$ext.shell'; // Custom extension
    final targetPath = p.join(vaultDir.path, newFileName);

    // 5. Write Concatenation to Disk
    // concatenation() returns: Nonce + CipherText + Mac
    await File(targetPath).writeAsBytes(secretBox.concatenation());

    return targetPath;
  }

  /// Decrypts a file from [encryptedPath] to a temporary file.
  /// 
  /// Returns the path to the temporary decrypted file.
  /// NOTE: The caller is responsible for deleting this file after viewing.
  static Future<String> decryptFile(String encryptedPath) async {
    final key = await _getOrCreateKey();
    final encryptedFile = File(encryptedPath);

    if (!await encryptedFile.exists()) {
      throw Exception('Encrypted file not found');
    }

    // 1. Read all bytes
    final fileBytes = await encryptedFile.readAsBytes();

    // 2. Reconstruct the SecretBox from the bytes
    // AES-GCM standard: Nonce (12) + Cipher + MAC (16)
    final secretBox = SecretBox.fromConcatenation(
      fileBytes,
      nonceLength: 12, 
      macLength: 16,
    );

    // 3. Decrypt
    final clearText = await _algorithm.decrypt(
      secretBox,
      secretKey: key,
    );

    // 4. Write to Temp Directory
    final tempDir = await getTemporaryDirectory();
    // recover original extension if possible, or default to .tmp
    // We stored it as .shell, but usually we need the logic layer to know the real extension
    // For now, we strip .shell and hope the OS handles the mime type, 
    // or rely on the caller to rename it based on database metadata.
    String tempFileName = p.basename(encryptedPath).replaceAll('.shell', '');
    
    // If the original extension is missing, the viewer might fail. 
    // Ideally, you store the original extension in your Database (SQLite/Hive).
    
    final tempPath = p.join(tempDir.path, 'dec_$tempFileName');
    await File(tempPath).writeAsBytes(clearText);

    return tempPath;
  }

  /// ─── Helpers ─────────────────────────────────────────────────────

  /// Permanently deletes a file from the vault
  static Future<void> deleteFromVault(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clears the encryption key (Dangerous: makes all data unreadable)
  static Future<void> dangerousClearKey() async {
    await _storage.delete(key: _keyStorageKey);
  }
}