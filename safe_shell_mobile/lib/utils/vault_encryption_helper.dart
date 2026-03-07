import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';

class VaultEncryptionHelper {
  /// Encrypts a local file and uploads it to the given endpoint.
  /// Automatically cleans up the temporary encrypted file after upload.
  static Future<void> encryptAndUpload(String originalFilePath, String endpoint) async {
    String? encryptedPath;
    try {
      if (kDebugMode) debugPrint('EncryptionHelper: Encrypting $originalFilePath');
      
      // 1. Encrypt the file
      encryptedPath = await EncryptionService.encryptFile(originalFilePath);
      
      if (kDebugMode) debugPrint('EncryptionHelper: Uploading encrypted file $encryptedPath');

      // 2. Upload the encrypted file (.shell)
      await ApiService().uploadMultipart(endpoint, encryptedPath);
      
      if (kDebugMode) debugPrint('EncryptionHelper: Upload successful');
    } catch (e) {
      if (kDebugMode) debugPrint('EncryptionHelper: Error during encrypt/upload: $e');
      rethrow;
    } finally {
      // 3. Clean up the temporary encrypted file
      if (encryptedPath != null) {
        final encFile = File(encryptedPath);
        if (await encFile.exists()) {
          await encFile.delete();
          if (kDebugMode) debugPrint('EncryptionHelper: Cleaned up temp file $encryptedPath');
        }
      }
    }
  }
}
