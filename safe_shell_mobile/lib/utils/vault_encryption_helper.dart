import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../services/network_service.dart';
import '../services/encryption_service.dart';
import '../core/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VaultEncryptionHelper {
  /// Encrypts a local file and uploads it to the Koyeb Backend.
  /// The backend handles the actual upload to Firebase Storage and DB record creation.
  static Future<String> encryptAndUpload(String originalFilePath, String folderName) async {
    String? encryptedPath;
    try {
      if (kDebugMode) debugPrint('EncryptionHelper: Encrypting $originalFilePath');
      
      // 1. Encrypt the file using pure Dart Cryptography
      encryptedPath = await EncryptionService.encryptFile(originalFilePath);
      
      if (kDebugMode) debugPrint('EncryptionHelper: Uploading encrypted file to Koyeb Backend: ${AppConstants.baseUrl}');

      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.keyToken);
      if (token == null) throw Exception('Session expired. Please login again.');

      // 2. Upload to Backend via Multipart
      final fileName = p.basename(encryptedPath);
      final uri = Uri.parse('${AppConstants.baseUrl}/vault/upload?type=$folderName');
      
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
          'file', // Field name matches backend's expectation
          encryptedPath,
          contentType: MediaType('application', 'octet-stream'),
        ));

      final streamResponse = await NetworkService.client.send(request).timeout(NetworkService.uploadTimeout);
      final response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) debugPrint('EncryptionHelper: Upload successful, response: ${response.body}');
        return data['url']; // Returns the permanent download URL from backend
      } else {
        throw Exception('Upload failed (${response.statusCode}): ${response.body}');
      }
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
