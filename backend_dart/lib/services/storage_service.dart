import 'dart:io';
import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:mime/mime.dart';
import '../config/firebase.dart';
import '../config/env.dart';

class StorageService {
  static const _scopes = ['https://www.googleapis.com/auth/devstorage.read_write'];

  static Future<String> uploadFile(String localPath, String remotePath, {String? requestOrigin}) async {
    // Check if we should use local storage
    if (Env.storageMode == 'local') {
      return _uploadLocal(localPath, remotePath, requestOrigin);
    }

    final serviceAccount = FirebaseConfig.serviceAccount;
    if (serviceAccount == null) {
      print('[STORAGE] No service account found, falling back to LOCAL storage.');
      return _uploadLocal(localPath, remotePath, requestOrigin);
    }

    final client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(serviceAccount),
      _scopes,
    );

    try {
      final projectId = serviceAccount['project_id'];
      final envBucket = Env.firebaseStorageBucket;
      final bucketName = envBucket ?? '$projectId.firebasestorage.app';
      final fallbackBucket = '$projectId.appspot.com';
      
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      
      final encodedPath = Uri.encodeComponent(remotePath);
      final mimeType = lookupMimeType(localPath) ?? 'application/octet-stream';
      
      print('[STORAGE] Attempting Firebase upload to bucket: $bucketName');
      
      var uploadUrl = 'https://firebasestorage.googleapis.com/v0/b/$bucketName/o?name=$encodedPath&uploadType=media';
      var response = await client.post(
        Uri.parse(uploadUrl),
        body: bytes,
        headers: {'Content-Type': mimeType},
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200 && envBucket == null) {
        print('[STORAGE] Primary bucket failed (${response.statusCode}). Trying fallback: $fallbackBucket');
        uploadUrl = 'https://firebasestorage.googleapis.com/v0/b/$fallbackBucket/o?name=$encodedPath&uploadType=media';
        response = await client.post(
          Uri.parse(uploadUrl),
          body: bytes,
          headers: {'Content-Type': mimeType},
        ).timeout(const Duration(seconds: 60));
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final name = data['name'];
        final bucket = data['bucket'];
        final String rawTokens = data['downloadTokens'] ?? '';
        final downloadToken = rawTokens.split(',').first;
        
        print('[STORAGE] Firebase upload successful! Bucket: $bucket');
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(name)}?alt=media&token=$downloadToken';
      } else {
        print('[STORAGE] Firebase failed (${response.statusCode}). Falling back to LOCAL storage.');
        return _uploadLocal(localPath, remotePath, requestOrigin);
      }
    } catch (e) {
      print('[STORAGE] Firebase exception: $e. Falling back to LOCAL storage.');
      return _uploadLocal(localPath, remotePath, requestOrigin);
    } finally {
      client.close();
    }
  }

  static Future<String> _uploadLocal(String localPath, String remotePath, String? requestOrigin) async {
    final uploadsDir = Directory(Env.uploadsPath);
    if (!await uploadsDir.exists()) await uploadsDir.create(recursive: true);

    // Use a unique name for local storage
    final fileName = p.basename(remotePath);
    
    // Copy file to local uploads directory
    final destinationPath = p.join(uploadsDir.path, fileName);
    await File(localPath).copy(destinationPath);

    print('[STORAGE] Saved locally to $destinationPath');

    // Generate URL
    final baseUrl = Env.storageBaseUrl ?? requestOrigin ?? 'http://localhost:${Env.port}';
    return '$baseUrl/api/vault/file/$fileName';
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
}
