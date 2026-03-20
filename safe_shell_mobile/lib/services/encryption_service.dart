import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class EncryptionService {
  // Use AES-GCM with 256-bit keys.
  // GCM is an Authenticated Encryption mode (AEAD), safer than CBC.
  static final _algorithm = AesGcm.with256bits();
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  static const _keyStorageKey = 'safe_shell_vault_key_v1';
  static const _nativeChannel = MethodChannel('com.safeshell.safe_shell_mobile/stealth');

  ///  Hardware Encryption Logic 

  static Future<Map<String, String>> hwEncrypt(Uint8List data) async {
    final result = await _nativeChannel.invokeMapMethod<String, String>('hwEncrypt', {'data': data});
    if (result == null) throw Exception('Hardware encryption failed');
    return result;
  }

  static Future<Uint8List> hwDecrypt(String ciphertext, String iv) async {
    final result = await _nativeChannel.invokeMethod<Uint8List>('hwDecrypt', {
      'ciphertext': ciphertext,
      'iv': iv,
    });
    if (result == null) throw Exception('Hardware decryption failed');
    return result;
  }

  ///  Key Management 

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

  ///  File Operations 

  /// Encrypts a file from [sourcePath] and saves it to the App's secure vault.
  /// 
  /// Returns the path to the newly created encrypted file.
  static Future<String> encryptFile(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('EncryptionError: Source file not found at $sourcePath');
    }

    final int originalSize = await file.length();
    if (kDebugMode) debugPrint('EncryptionService: Encrypting file ($originalSize bytes) at $sourcePath');

    // Security Pass 255/256: Native Streaming for files > 5MB
    if (originalSize > 5 * 1024 * 1024 && !kIsWeb && Platform.isAndroid) {
      final appDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory(p.join(appDir.path, 'vault_storage'));
      if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = p.join(vaultDir.path, 'enc_$timestamp.shell');
      
      await _nativeChannel.invokeMethod('encryptStream', {
        'inputPath': sourcePath,
        'outputPath': targetPath,
      });
      return targetPath;
    }

    final clearText = await file.readAsBytes();

    late Uint8List finalBytes;
    // 1. Fallback to Pure Dart Cryptography for ALL platforms.
    final key = await _getOrCreateKey();
    if (kDebugMode) debugPrint('EncryptionService: Key retrieved, starting AES-GCM encryption...');
    
    final secretBox = await _algorithm.encrypt(clearText, secretKey: key);
    finalBytes = Uint8List.fromList(secretBox.concatenation());
    
    if (kDebugMode) debugPrint('EncryptionService: Encryption complete. Encrypted size: ${finalBytes.length} bytes');

    // 3. Prepare Vault Directory
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(appDir.path, 'vault_storage'));
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);

    // 3b. Ensure .nomedia exists (hides vault from Gallery/File Manager apps)
    final nomedia = File(p.join(vaultDir.path, '.nomedia'));
    if (!await nomedia.exists()) await nomedia.create();

    // 4. Save
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = p.join(vaultDir.path, 'enc_$timestamp.shell');
    await File(targetPath).writeAsBytes(finalBytes);

    return targetPath;
  }

  /// Decrypts a file from [encryptedPath] to a temporary file.
  static Future<String> decryptFile(String encryptedPath) async {
    final encryptedFile = File(encryptedPath);
    if (!await encryptedFile.exists()) throw Exception('Encrypted file not found');

    final int fileSize = await encryptedFile.length();

    // Security Pass 256: Native Streaming Decryption for files > 5MB
    if (fileSize > 5 * 1024 * 1024 && !kIsWeb && Platform.isAndroid && !encryptedPath.endsWith('.hw.shell')) {
      final tempDir = await getTemporaryDirectory();
      String tempFileName = p.basename(encryptedPath).replaceAll('.shell', '');
      final tempPath = p.join(tempDir.path, 'dec_$tempFileName');
      
      await _nativeChannel.invokeMethod('decryptStream', {
        'inputPath': encryptedPath,
        'outputPath': tempPath,
      });
      return tempPath;
    }

    final fileBytes = await encryptedFile.readAsBytes();
    late Uint8List clearText;

    // 1. Pure Dart Decryption
    try {
      if (encryptedPath.endsWith('.hw.shell')) {
        // Fallback for files encrypted before the revert
        final ivLength = fileBytes[0];
        final iv = base64Encode(fileBytes.sublist(1, 1 + ivLength));
        final ciphertext = base64Encode(fileBytes.sublist(1 + ivLength));
        clearText = await hwDecrypt(ciphertext, iv);
      } else {
        final key = await _getOrCreateKey();
        final secretBox = SecretBox.fromConcatenation(fileBytes, nonceLength: 12, macLength: 16);
        clearText = Uint8List.fromList(await _algorithm.decrypt(secretBox, secretKey: key));
      }
    } catch (_) {
      throw Exception('Failed to decrypt file. It may be corrupted or using an old key.');
    }

    // 3. Write to Temp
    final tempDir = await getTemporaryDirectory();
    String tempFileName = p.basename(encryptedPath)
        .replaceAll('.hw.shell', '')
        .replaceAll('.shell', '');
    
    final tempPath = p.join(tempDir.path, 'dec_$tempFileName');
    await File(tempPath).writeAsBytes(clearText);

    return tempPath;
  }

  ///  Helpers 

  /// Gets a directory specifically for temporary decrypted files.
  /// This helps in centralizing cache management.
  static Future<Directory> getDecryptedCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, 'decrypted_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Returns the persistent path for an encrypted file in the vault.
  static Future<String> getLocalVaultPath(String id) async {
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(appDir.path, 'vault_storage'));
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
    return p.join(vaultDir.path, 'vault_$id.shell');
  }

  /// Clears all files in the decrypted cache.
  /// Should be called on logout or app lock for maximum security.
  static Future<void> clearDecryptedCache() async {
    try {
      final cacheDir = await getDecryptedCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('EncryptionService: Decrypted cache cleared.');
      }
    } catch (e) {
      debugPrint('EncryptionService: Failed to clear cache: $e');
    }
  }

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

  /// Security Pass 254: Cleanup orphaned temporary or encrypted files
  static Future<void> cleanupOrphanedFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final appDir = await getApplicationDocumentsDirectory();
      
      // Cleanup temp dir
      if (await tempDir.exists()) {
        await for (var entity in tempDir.list()) {
          if (entity is File && (entity.path.contains('dec_') || entity.path.contains('enc_'))) {
            // If older than 2 hours, delete
            final stat = await entity.stat();
            if (DateTime.now().difference(stat.modified).inHours > 2) {
              await entity.delete();
            }
          }
        }
      }

      // Cleanup vault_storage for un-renamed 'enc_' files
      final vaultDir = Directory(p.join(appDir.path, 'vault_storage'));
      if (await vaultDir.exists()) {
        await for (var entity in vaultDir.list()) {
          if (entity is File && p.basename(entity.path).startsWith('enc_')) {
             final stat = await entity.stat();
             if (DateTime.now().difference(stat.modified).inHours > 2) {
               await entity.delete();
             }
          }
        }
      }
    } catch (e) {
      debugPrint('EncryptionService: Cleanup failed: $e');
    }
  }
}
