import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';


import '../middleware/auth_middleware.dart';
import '../models/vault_item.dart';
import '../services/storage_service.dart';
import '../config/env.dart';

const _uuid = Uuid();
const _maxFileSize = 50 * 1024 * 1024; // 50MB
const _allowedTypes = {'photo', 'video', 'audio', 'document', 'note', 'zip'};

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _detectType(String filename) {
  final cleanName = filename.toLowerCase().endsWith('.shell')
      ? filename.substring(0, filename.length - 6)
      : filename;
  final ext = cleanName.split('.').last.toLowerCase();
  const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'tiff', 'ico', 'heic', 'heif'};
  const videoExts = {'mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm', '3gp', 'm4v'};
  const audioExts = {'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma'};
  const docExts = {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'csv', 'md', 'key', 'pages', 'numbers'};
  const zipExts = {'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz'};

  if (imageExts.contains(ext)) return 'photo';
  if (videoExts.contains(ext)) return 'video';
  if (audioExts.contains(ext)) return 'audio';
  if (docExts.contains(ext)) return 'document';
  if (zipExts.contains(ext)) return 'zip';
  return 'document';
}

// ✅ Fix: Sanitize filename to prevent path traversal
String _sanitizeFilename(String filename) {
  return filename
      .replaceAll(RegExp(r'[/\\]'), '_')  // path separators
      .replaceAll(RegExp(r'\.\.'), '_')     // directory traversal
      .replaceAll(RegExp(r'[^\w.\-]'), '_') // special chars
      .trim();
}

Router vaultRouter() {
  final router = Router();

  // ✅ Fix 1: REMOVED debug-all endpoint (was exposing ALL users' data without ownership check)
  // router.get('/debug-all', ...) — REMOVED

  // GET /stats
  router.get('/stats', (Request request) async {
    try {
      final user = getAuthUser(request);
      // ✅ Fix 2: Null check
      final userId = user.id;
      if (userId == null) {
        return Response(401,
            body: jsonEncode({'message': 'Invalid session'}),
            headers: {'content-type': 'application/json'});
      }

      final items = await vaultItemRepo.find({'user': userId, 'isDeleted': false});

      int photos = 0, videos = 0, docs = 0, notes = 0, zips = 0, audios = 0;
      double totalSize = 0;

      for (final item in items) {
        if (item.type == 'photo') {
          photos++;
        } else if (item.type == 'video') {
          videos++;
        } else if (item.type == 'note') {
          notes++;
        } else if (item.type == 'document') {
          docs++;
        } else if (item.type == 'zip') {
          zips++;
        } else if (item.type == 'audio') {
          audios++;
        }

        final parts = item.size.split(' ');
        if (parts.length == 2) {
          final val = double.tryParse(parts[0]) ?? 0;
          final unit = parts[1];
          if (unit == 'KB') {
            totalSize += val * 1024;
          } else if (unit == 'MB') {
            totalSize += val * 1024 * 1024;
          } else if (unit == 'GB') {
            totalSize += val * 1024 * 1024 * 1024;
          } else {
            totalSize += val;
          }
        }
      }

      // Fetch 10 most recent items to include in stats (reduces dashboard lag)
      final sortedItems = List<VaultItem>.from(items);
      sortedItems.sort((a, b) {
        final dateA = a.createdAt ?? DateTime(2000);
        final dateB = b.createdAt ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });
      final recent = sortedItems.take(10).map((i) => i.toJson()).toList();

      return Response.ok(jsonEncode({
        'count': items.length,
        'photoCount': photos,
        'videoCount': videos,
        'noteCount': notes,
        'docCount': docs,
        'zipCount': zips,
        'audioCount': audios,
        'totalSize': totalSize.toInt(),
        'sizeFormatted': _formatSize(totalSize.toInt()),
        'recentItems': recent,
      }), headers: {'content-type': 'application/json'});
    } catch (e, stackTrace) {
      // ✅ Fix 3: No error details leaked + logging
      print('Vault stats error: $e\n$stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // GET /recent
  router.get('/recent', (Request request) async {
    try {
      final user = getAuthUser(request);
      final userId = user.id;
      if (userId == null) {
        return Response(401,
            body: jsonEncode({'message': 'Invalid session'}),
            headers: {'content-type': 'application/json'});
      }

      final items = await vaultItemRepo.find({'user': userId, 'isDeleted': false}, {'createdAt': 'desc'});
      final result = items.take(10).map((i) => i.toJson()).toList();
      return Response.ok(jsonEncode(result), headers: {'content-type': 'application/json'});
    } catch (e, stackTrace) {
      print('Vault recent error: $e\n$stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // GET /
  router.get('/', (Request request) async {
    try {
      final user = getAuthUser(request);
      final userId = user.id;
      if (userId == null) {
        return Response(401,
            body: jsonEncode({'message': 'Invalid session'}),
            headers: {'content-type': 'application/json'});
      }

      final query = request.url.queryParameters;
      final type = query['type'];
      final isDeleted = query['isDeleted'] == 'true';

      // ✅ Fix 4: Validate type parameter
      if (type != null && type.isNotEmpty && !_allowedTypes.contains(type)) {
        return Response(400,
            body: jsonEncode({'message': 'Invalid type. Allowed: ${_allowedTypes.join(', ')}'}),
            headers: {'content-type': 'application/json'});
      }

      final filter = <String, dynamic>{'user': userId, 'isDeleted': isDeleted};
      if (type != null && type.isNotEmpty) filter['type'] = type;

      final items = await vaultItemRepo.find(filter);
      return Response.ok(jsonEncode(items.map((i) => i.toJson()).toList()), headers: {'content-type': 'application/json'});
    } catch (e, stackTrace) {
      print('Vault list error: $e\n$stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST / (JSON)
  router.post('/', (Request request) async {
    try {
      final user = getAuthUser(request);
      final userId = user.id;
      if (userId == null) {
        return Response(401,
            body: jsonEncode({'message': 'Invalid session'}),
            headers: {'content-type': 'application/json'});
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      // ✅ Fix 5: Validate name
      final name = (body['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) {
        return Response(400,
            body: jsonEncode({'message': 'Name is required'}),
            headers: {'content-type': 'application/json'});
      }
      if (name.length > 500) {
        return Response(400,
            body: jsonEncode({'message': 'Name too long (max 500)'}),
            headers: {'content-type': 'application/json'});
      }

      // ✅ Fix 6: Validate type
      final type = body['type'] as String? ?? 'document';
      if (!_allowedTypes.contains(type)) {
        return Response(400,
            body: jsonEncode({'message': 'Invalid type'}),
            headers: {'content-type': 'application/json'});
      }

      final item = await vaultItemRepo.create({
        'user': userId,
        'name': name,
        'type': type,
        'content': body['content'],
        'size': body['size'] ?? '0 B',
        'isDeleted': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      return Response(201, body: jsonEncode(item.toJson()), headers: {'content-type': 'application/json'});
    } catch (e, stackTrace) {
      print('Vault create error: $e\n$stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /upload
  router.post('/upload', (Request request) async {
    try {
      final user = getAuthUser(request);
      final userId = user.id;
      if (userId == null) {
        return Response(401,
            body: jsonEncode({'message': 'Invalid session'}),
            headers: {'content-type': 'application/json'});
      }

      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('multipart/form-data')) {
        return Response.badRequest(
            body: jsonEncode({'message': 'Expected multipart/form-data'}),
            headers: {'content-type': 'application/json'});
      }

      final mediaType = MediaType.parse(contentType);
      final boundary = mediaType.parameters['boundary'];
      if (boundary == null) {
        return Response.badRequest(
            body: jsonEncode({'message': 'Missing boundary'}),
            headers: {'content-type': 'application/json'});
      }

      final transformer = MimeMultipartTransformer(boundary);
      final parts = transformer.bind(request.read());

      String? filename;
      String? tempPath;
      int bytesReceived = 0;

      await for (final part in parts) {
        final contentDisposition = part.headers['content-disposition'];
        if (contentDisposition != null && contentDisposition.contains('filename=')) {
          final header = HeaderValue.parse(contentDisposition);
          filename = header.parameters['filename'];
          if (filename == null) continue;

          final sanitizedFilename = _sanitizeFilename(filename);
          final storedName = '${_uuid.v4()}_$sanitizedFilename';

          final dataDir = Directory('data');
          if (!await dataDir.exists()) await dataDir.create(recursive: true);

          tempPath = 'data/temp_$storedName';
          final file = File(tempPath);
          final sink = file.openWrite();

          bool sizeExceeded = false;
          try {
            await for (final chunk in part) {
              bytesReceived += chunk.length;
              if (bytesReceived > _maxFileSize) {
                sizeExceeded = true;
                break;
              }
              sink.add(chunk);
            }
          } finally {
            await sink.close();
          }

          if (sizeExceeded) {
            if (await file.exists()) await file.delete();
            return Response(413,
                body: jsonEncode({
                  'message': 'File too large. Max ${_formatSize(_maxFileSize)}'
                }),
                headers: {'content-type': 'application/json'});
          }
          break; // Only handle the first file
        }
      }

      if (filename == null || tempPath == null || bytesReceived == 0) {
        return Response.badRequest(
            body: jsonEncode({'message': 'No file found or empty file'}),
            headers: {'content-type': 'application/json'});
      }

      final sanitizedFilename = _sanitizeFilename(filename);
      final storedName = p.basename(tempPath);
      String storagePath = 'vault/$userId/$storedName';
      String firebaseUrl;
      
      try {
        final origin = request.requestedUri.origin;
        firebaseUrl = await StorageService.uploadFile(tempPath, storagePath, requestOrigin: origin);
      } finally {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) await tempFile.delete();
      }

      String type = request.url.queryParameters['type'] ?? _detectType(filename);
      if (!_allowedTypes.contains(type)) {
        type = 'document';
      }

      print('[VAULT UPLOAD] filename=$sanitizedFilename, type=$type, size=$bytesReceived');
      final item = await vaultItemRepo.create({
        'user': userId,
        'name': filename,
        'type': type,
        'size': _formatSize(bytesReceived),
        'url': firebaseUrl,
        'storagePath': storagePath,
        'isDeleted': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      return Response(201, body: jsonEncode(item.toJson()), headers: {'content-type': 'application/json'});
    } catch (e, stackTrace) {
      print('Vault upload error: $e\n$stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // DELETE /empty-bin
  router.delete('/empty-bin', (Request request) async {
    try {
      final user = getAuthUser(request);
      final userId = user.id;
      if (userId == null) {
        return Response(401,
            body: jsonEncode({'message': 'Invalid session'}),
            headers: {'content-type': 'application/json'});
      }

      // ✅ Fix 10: Delete storage files before removing DB records
      final deletedItems = await vaultItemRepo.find({'user': userId, 'isDeleted': true});
      int deletedCount = 0;

      for (final item in deletedItems) {
        try {
          final storagePath = item.toJson()['storagePath'] as String?;
          if (storagePath != null && storagePath.isNotEmpty) {
            await StorageService.deleteFile(storagePath);
          }
        } catch (e) {
          print('Failed to delete storage file for ${item.id}: $e');
        }
        await item.deleteOne();
        deletedCount++;
      }

      return Response.ok(
          jsonEncode({'message': 'Recycle bin emptied', 'deletedCount': deletedCount}),
          headers: {'content-type': 'application/json'});
    } catch (e, stackTrace) {
      print('Empty bin error: $e\n$stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // PUT /<id>
  router.put('/<id>', (Request request, String id) async {
    try {
      final user = getAuthUser(request);
      final item = await vaultItemRepo.findById(id);
      if (item == null || item.user != user.id) {
        return Response.notFound(
            jsonEncode({'message': 'Item not found'}),
            headers: {'content-type': 'application/json'});
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      // ✅ Fix 11: Validate update fields
      if (body['name'] != null) {
        final name = (body['name'] as String).trim();
        if (name.isEmpty || name.length > 500) {
          return Response(400,
              body: jsonEncode({'message': 'Invalid name'}),
              headers: {'content-type': 'application/json'});
        }
        item.name = name;
      }
      if (body['content'] != null) item.content = body['content'];
      await item.save();

      return Response.ok(jsonEncode(item.toJson()), headers: {'content-type': 'application/json'});
    } catch (e, stackTrace) {
      print('Vault update error: $e\n$stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // DELETE /<id>
  router.delete('/<id>', (Request request, String id) async {
    try {
      final user = getAuthUser(request);
      final item = await vaultItemRepo.findById(id);
      if (item == null || item.user != user.id) {
        return Response.notFound(
            jsonEncode({'message': 'Item not found'}),
            headers: {'content-type': 'application/json'});
      }

      final permanent = request.url.queryParameters['permanent'] == 'true';
      if (permanent) {
        final storagePath = item.toJson()['storagePath'];
        if (storagePath != null) {
          // ✅ Fix 12: Wrap storage delete in try-catch (don't fail if storage delete fails)
          try {
            await StorageService.deleteFile(storagePath);
          } catch (e) {
            print('Storage delete failed for $storagePath: $e');
          }
        }
        await item.deleteOne();
        return Response.ok(
            jsonEncode({'message': 'Item permanently deleted'}),
            headers: {'content-type': 'application/json'});
      } else {
        item.isDeleted = true;
        item.deletedAt = DateTime.now();
        await item.save();
        return Response.ok(
            jsonEncode({'message': 'Item moved to recycle bin'}),
            headers: {'content-type': 'application/json'});
      }
    } catch (e, stackTrace) {
      print('Vault delete error: $e\n$stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /<id>/restore
  router.post('/<id>/restore', (Request request, String id) async {
    try {
      final user = getAuthUser(request);
      final item = await vaultItemRepo.findById(id);
      if (item == null || item.user != user.id) {
        return Response.notFound(
            jsonEncode({'message': 'Item not found'}),
            headers: {'content-type': 'application/json'});
      }
      item.isDeleted = false;
      item.deletedAt = null;
      await item.save();
      return Response.ok(
          jsonEncode({'message': 'Item restored'}),
          headers: {'content-type': 'application/json'});
    } catch (e, stackTrace) {
      print('Vault restore error: $e\n$stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /fix-types
  router.post('/fix-types', (Request request) async {
    try {
      final user = getAuthUser(request);
      final userId = user.id;
      if (userId == null) {
        return Response(401,
            body: jsonEncode({'message': 'Invalid session'}),
            headers: {'content-type': 'application/json'});
      }

      final items = await vaultItemRepo.find({'user': userId});
      int fixed = 0;

      // ✅ Fix 13: Removed detailed debug info from response
      for (final item in items) {
        final correctType = _detectType(item.name);
        if (correctType != item.type) {
          item.type = correctType;
          await item.save();
          fixed++;
        }
      }

      return Response.ok(
        jsonEncode({
          'message': 'Fixed $fixed items out of ${items.length}',
          'fixed': fixed,
          'total': items.length,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      print('Fix types error: $e\n$stackTrace');
      return Response.internalServerError(
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // GET /file/<filename> - Serve local files
  router.get('/file/<name>', (Request request, String name) async {
    try {
      final sanitized = _sanitizeFilename(name);
      final file = File(p.join(Env.uploadsPath, sanitized));
      
      if (!await file.exists()) {
        return Response.notFound(jsonEncode({'message': 'File not found'}));
      }

      final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';
      return Response.ok(file.openRead(), headers: {'content-type': contentType});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Error serving file: $e'}));
    }
  });

  return router;
}

Handler vaultHandler() {
  return const Pipeline()
      .addMiddleware(authMiddleware())
      .addHandler(vaultRouter().call);
}