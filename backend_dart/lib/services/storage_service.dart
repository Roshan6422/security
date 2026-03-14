import 'dart:io';
import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import '../config/firebase.dart';

class StorageService {
  static const _scopes = ['https://www.googleapis.com/auth/devstorage.read_write'];

  static Future<String> uploadFile(String localPath, String remotePath) async {
    final serviceAccount = FirebaseConfig.serviceAccount;
    if (serviceAccount == null) {
      throw Exception('Firebase service account not configured');
    }

    final client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(serviceAccount),
      _scopes,
    );

    try {
      final bucketName = serviceAccount['project_id'] + '.firebasestorage.app'; // Default bucket name pattern
      // Some older projects use .appspot.com
      final fallbackBucket = serviceAccount['project_id'] + '.appspot.com';
      
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      
      final encodedPath = Uri.encodeComponent(remotePath);
      
      // Try primary bucket
      var uploadUrl = 'https://firebasestorage.googleapis.com/v0/b/$bucketName/o?name=$encodedPath';
      var response = await client.post(
        Uri.parse(uploadUrl),
        body: bytes,
        headers: {'Content-Type': _detectMimeType(localPath)},
      );

      if (response.statusCode != 200) {
        // Try fallback bucket
        uploadUrl = 'https://firebasestorage.googleapis.com/v0/b/$fallbackBucket/o?name=$encodedPath';
        response = await client.post(
          Uri.parse(uploadUrl),
          body: bytes,
          headers: {'Content-Type': _detectMimeType(localPath)},
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final name = data['name'];
        final bucket = data['bucket'];
        final downloadToken = data['downloadTokens'] ?? '';
        
        // Final public URL
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(name)}?alt=media&token=$downloadToken';
      } else {
        throw Exception('Failed to upload to Firebase Storage: ${response.statusCode} - ${response.body}');
      }
    } finally {
      client.close();
    }
  }

  static Future<void> deleteFile(String remotePath) async {
    final serviceAccount = FirebaseConfig.serviceAccount;
    if (serviceAccount == null) return;

    final client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(serviceAccount),
      _scopes,
    );

    try {
      final bucketName = serviceAccount['project_id'] + '.firebasestorage.app';
      final fallbackBucket = serviceAccount['project_id'] + '.appspot.com';
      
      final encodedPath = Uri.encodeComponent(remotePath);
      
      var url = 'https://firebasestorage.googleapis.com/v0/b/$bucketName/o/$encodedPath';
      var response = await client.delete(Uri.parse(url));
      
      if (response.statusCode != 204 && response.statusCode != 200) {
        url = 'https://firebasestorage.googleapis.com/v0/b/$fallbackBucket/o/$encodedPath';
        await client.delete(Uri.parse(url));
      }
    } catch (e) {
      print('Failed to delete file from storage: $e');
    } finally {
      client.close();
    }
  }

  static String _detectMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'mp4': 'video/mp4',
      'mp3': 'audio/mpeg',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }
}
