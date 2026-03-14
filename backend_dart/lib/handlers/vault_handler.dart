import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

import '../config/env.dart';
import '../middleware/auth_middleware.dart';
import '../models/vault_item.dart';
import '../services/storage_service.dart';

const _uuid = Uuid();

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _detectType(String filename) {
  // Strip .shell encryption wrapper to get the real extension
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

Router vaultRouter() {
  final router = Router();

  // TEMP: GET /debug-all — dump all vault items for debugging
  router.get('/debug-all', (Request request) async {
    try {
      final items = await vaultItemRepo.find({});
      final result = items.map((i) => {
        'name': i.name,
        'type': i.type,
        'user': i.user,
        'id': i.id,
        'detectedType': _detectType(i.name),
      }).toList();
      return Response.ok(
        jsonEncode({'total': items.length, 'items': result}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Error: $e'}));
    }
  });

  // GET /stats
  router.get('/stats', (Request request) async {
    try {
      final user = getAuthUser(request);
      final items = await vaultItemRepo.find({'user': user.id!, 'isDeleted': false});

      int photos = 0, videos = 0, docs = 0, notes = 0, zips = 0, audios = 0;
      double totalSize = 0;

      for (final item in items) {
        if (item.type == 'photo') photos++;
        else if (item.type == 'video') videos++;
        else if (item.type == 'note') notes++;
        else if (item.type == 'document') docs++;
        else if (item.type == 'zip') zips++;
        else if (item.type == 'audio') audios++;

        final parts = item.size.split(' ');
        if (parts.length == 2) {
          final val = double.tryParse(parts[0]) ?? 0;
          final unit = parts[1];
          if (unit == 'KB') totalSize += val * 1024;
          else if (unit == 'MB') totalSize += val * 1024 * 1024;
          else if (unit == 'GB') totalSize += val * 1024 * 1024 * 1024;
          else totalSize += val;
        }
      }

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
      }), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Server error: $e'}));
    }
  });

  // GET /recent
  router.get('/recent', (Request request) async {
    try {
      final user = getAuthUser(request);
      final items = await vaultItemRepo.find({'user': user.id!, 'isDeleted': false}, {'createdAt': 'desc'});
      final result = items.take(10).map((i) => i.toJson()).toList();
      return Response.ok(jsonEncode(result), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Server error'}));
    }
  });

  // GET /
  router.get('/', (Request request) async {
    try {
      final user = getAuthUser(request);
      final query = request.url.queryParameters;
      final type = query['type'];
      final isDeleted = query['isDeleted'] == 'true';

      final filter = {'user': user.id!, 'isDeleted': isDeleted};
      if (type != null && type.isNotEmpty) filter['type'] = type;

      final items = await vaultItemRepo.find(filter);
      return Response.ok(jsonEncode(items.map((i) => i.toJson()).toList()), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Server error'}));
    }
  });

  // POST / (JSON)
  router.post('/', (Request request) async {
    try {
      final user = getAuthUser(request);
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      
      final item = await vaultItemRepo.create({
        'user': user.id!,
        'name': body['name'] ?? 'Untitled',
        'type': body['type'] ?? 'document',
        'content': body['content'],
        'size': body['size'] ?? '0 B',
        'isDeleted': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      return Response(201, body: jsonEncode(item.toJson()), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Server error: $e'}));
    }
  });

  // POST /upload
  router.post('/upload', (Request request) async {
    try {
      final user = getAuthUser(request);
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('multipart/form-data')) {
        return Response.badRequest(body: jsonEncode({'message': 'Expected multipart/form-data'}));
      }

      final mediaType = MediaType.parse(contentType);
      final boundary = mediaType.parameters['boundary'];
      if (boundary == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Missing boundary'}));
      }

      final transformer = MimeMultipartTransformer(boundary);
      final parts = await transformer.bind(request.read()).toList();

      String? filename;
      List<int>? fileBytes;

      for (final part in parts) {
        final contentDisposition = part.headers['content-disposition'];
        if (contentDisposition != null && contentDisposition.contains('filename=')) {
          final header = HeaderValue.parse(contentDisposition);
          filename = header.parameters['filename'];
          fileBytes = await part.expand((b) => b).toList();
          break;
        }
      }

      if (filename == null || fileBytes == null) {
        return Response.badRequest(body: jsonEncode({'message': 'No file found'}));
      }

      final storedName = '${_uuid.v4()}_$filename';
      
      // Save temporarily to disk to upload to Firebase
      final tempPath = 'data/temp_$storedName';
      await File(tempPath).writeAsBytes(fileBytes);

      String storagePath = 'vault/${user.id}/$storedName';
      String firebaseUrl;
      try {
        firebaseUrl = await StorageService.uploadFile(tempPath, storagePath);
      } finally {
        // Cleanup temp file
        final tempFile = File(tempPath);
        if (await tempFile.exists()) await tempFile.delete();
      }

      String type = request.url.queryParameters['type'] ?? _detectType(filename);
      print('[VAULT UPLOAD] filename=$filename, detectedType=$type');
      final item = await vaultItemRepo.create({
        'user': user.id!,
        'name': filename,
        'type': type,
        'size': _formatSize(fileBytes.length),
        'url': firebaseUrl,
        'storagePath': storagePath, // Store for later deletion
        'isDeleted': false,
      });

      return Response(201, body: jsonEncode(item.toJson()), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Server error: $e'}));
    }
  });

  // DELETE /empty-bin
  router.delete('/empty-bin', (Request request) async {
    try {
      final user = getAuthUser(request);
      await vaultItemRepo.deleteMany({'user': user.id!, 'isDeleted': true});
      return Response.ok(jsonEncode({'message': 'Recycle bin emptied'}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Server error'}));
    }
  });

  // PUT /<id>
  router.put('/<id>', (Request request, String id) async {
    try {
      final user = getAuthUser(request);
      final item = await vaultItemRepo.findById(id);
      if (item == null || item.user != user.id) {
        return Response.notFound(jsonEncode({'message': 'Item not found'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      if (body['name'] != null) item.name = body['name'];
      if (body['content'] != null) item.content = body['content'];
      await item.save();

      return Response.ok(jsonEncode(item.toJson()), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Server error'}));
    }
  });

  // DELETE /<id>
  router.delete('/<id>', (Request request, String id) async {
    try {
      final user = getAuthUser(request);
      final item = await vaultItemRepo.findById(id);
      if (item == null || item.user != user.id) {
        return Response.notFound(jsonEncode({'message': 'Item not found'}));
      }

      final permanent = request.url.queryParameters['permanent'] == 'true';
      if (permanent) {
        final storagePath = item.toJson()['storagePath'];
        if (storagePath != null) {
          await StorageService.deleteFile(storagePath);
        }
        await item.deleteOne();
        return Response.ok(jsonEncode({'message': 'Item permanently deleted'}), headers: {'content-type': 'application/json'});
      } else {
        item.isDeleted = true;
        item.deletedAt = DateTime.now();
        await item.save();
        return Response.ok(jsonEncode({'message': 'Item moved to recycle bin'}), headers: {'content-type': 'application/json'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Server error'}));
    }
  });

  // POST /<id>/restore
  router.post('/<id>/restore', (Request request, String id) async {
    try {
      final user = getAuthUser(request);
      final item = await vaultItemRepo.findById(id);
      if (item == null || item.user != user.id) {
        return Response.notFound(jsonEncode({'message': 'Item not found'}));
      }
      item.isDeleted = false;
      item.deletedAt = null;
      await item.save();
      return Response.ok(jsonEncode({'message': 'Item restored'}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Server error'}));
    }
  });

  // POST /fix-types — re-categorize existing items based on filename
  router.post('/fix-types', (Request request) async {
    try {
      final user = getAuthUser(request);
      final items = await vaultItemRepo.find({'user': user.id!});
      int fixed = 0;
      final debugInfo = <Map<String, String>>[];

      for (final item in items) {
        final correctType = _detectType(item.name);
        debugInfo.add({
          'name': item.name,
          'currentType': item.type,
          'detectedType': correctType,
          'status': correctType != item.type ? 'FIXED' : 'OK',
        });
        print('[FIX-TYPES] name=${item.name}, current=${item.type}, detected=$correctType');
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
          'items': debugInfo,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Server error: $e'}));
    }
  });

  return router;
}

Handler vaultHandler() {
  return const Pipeline()
      .addMiddleware(authMiddleware())
      .addHandler(vaultRouter().call);
}