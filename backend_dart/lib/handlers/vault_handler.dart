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

const _uuid = Uuid();

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _detectType(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'tiff', 'ico'};
  const videoExts = {'mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm', '3gp', 'm4v'};
  const audioExts = {'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma'};
  const docExts = {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'csv', 'md'};
  const zipExts = {'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz'};

  if (imageExts.contains(ext)) return 'photo';
  if (videoExts.contains(ext)) return 'video';
  if (audioExts.contains(ext)) return 'audio'; // New type for audio
  if (docExts.contains(ext)) return 'document';
  if (zipExts.contains(ext)) return 'zip';
  return 'document'; // Default to document for unknown types
}

/// Builds the `/api/vault` router.
///
/// Auth middleware is applied at the mount level via [vaultHandler].
Router vaultRouter() {
  final router = Router();

  // GET / - List items (handles filters)
  router.get('/', (Request request) async {
    try {
      final user = getAuthUser(request);
      final query = request.url.queryParameters;
      final type = query['type'];
      final isDeleted = query['isDeleted'] == 'true';

      final filter = {
        'user': user.id!,
        'isDeleted': isDeleted,
      };

      if (type != null && type.isNotEmpty) {
        filter['type'] = type;
      }

      final items = await vaultItemRepo.find(filter);

      return Response.ok(
          jsonEncode(items.map((i) => i.toJson()).toList()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      print('Get vault items error: $e');
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST / - Create text note / entry (non-file)
  router.post('/', (Request request) async {
    try {
      final user = getAuthUser(request);
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final item = await vaultItemRepo.create({
        'user': user.id!,
        'name': body['name'] ?? 'Untitled',
        'type': body['type'] ?? 'note',
        'size': body['size'] ?? '0 B',
        'content': body['content'],
        'url': body['url'],
        'isDeleted': false,
      });

      return Response(201,
          body: jsonEncode(item.toJson()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /upload
  router.post('/upload', (Request request) async {
    try {
      final user = getAuthUser(request);
      final contentType = request.headers['content-type'];

      if (contentType == null || !contentType.contains('multipart/form-data')) {
        return Response(400,
            body: jsonEncode({'message': 'Expected multipart/form-data'}),
            headers: {'content-type': 'application/json'});
      }

      final mediaType = MediaType.parse(contentType);
      final boundary = mediaType.parameters['boundary'];
      if (boundary == null) {
        return Response(400,
            body: jsonEncode({'message': 'Missing boundary in content-type'}),
            headers: {'content-type': 'application/json'});
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
          break; // Stop at first file for now as per current mobile logic
        }
      }

      if (filename == null || fileBytes == null) {
        return Response(400,
            body: jsonEncode({'message': 'No file found in multipart request'}),
            headers: {'content-type': 'application/json'});
      }

      // Save file
      final uploadsDir = Directory(Env.uploadsPath);
      if (!uploadsDir.existsSync()) {
        uploadsDir.createSync(recursive: true);
      }
      
      final storedName = '${_uuid.v4()}_$filename';
      final filePath = '${Env.uploadsPath}/$storedName';
      await File(filePath).writeAsBytes(fileBytes);

      final item = await vaultItemRepo.create({
        'user': user.id!,
        'name': filename,
        'type': _detectType(filename),
        'size': _formatSize(fileBytes.length),
        'url': '/uploads/$storedName',
        'isDeleted': false,
      });

      return Response(201,
          body: jsonEncode(item.toJson()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      print('Upload error: $e');
      return Response(500,
          body: jsonEncode({'message': 'Server error: $e'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // DELETE /empty-bin
  router.delete('/empty-bin', (Request request) async {
    try {
      final user = getAuthUser(request);
      await vaultItemRepo.deleteMany({
        'user': user.id!,
        'isDeleted': true,
      });

      return Response.ok(
          jsonEncode({'message': 'Recycle bin emptied'}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
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
        return Response(404,
            body: jsonEncode({'message': 'Item not found'}),
            headers: {'content-type': 'application/json'});
      }

      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      if (body['name'] != null) item.name = body['name'] as String;
      if (body['content'] != null) item.content = body['content'] as String;
      await item.save();

      return Response.ok(jsonEncode(item.toJson()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // DELETE /<id> (Handles both soft and permanent delete)
  router.delete('/<id>',
      (Request request, String id) async {
    try {
      final user = getAuthUser(request);
      final item = await vaultItemRepo.findById(id);
      if (item == null || item.user != user.id) {
        return Response(404,
            body: jsonEncode({'message': 'Item not found'}),
            headers: {'content-type': 'application/json'});
      }

      final query = request.url.queryParameters;
      final permanent = query['permanent'] == 'true';

      if (permanent) {
         // Delete file from disk
        if (item.url != null) {
          final filePath = '${Env.uploadsPath}/${item.url!.replaceFirst('/uploads/', '')}';
          try {
            await File(filePath).delete();
          } catch (_) {
            // File may not exist
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
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /<id>/restore
  router.post('/<id>/restore',
      (Request request, String id) async {
    try {
      final user = getAuthUser(request);
      final item = await vaultItemRepo.findById(id);
      if (item == null || item.user != user.id) {
        return Response(404,
            body: jsonEncode({'message': 'Item not found'}),
            headers: {'content-type': 'application/json'});
      }

      item.isDeleted = false;
      item.deletedAt = null;
      await item.save();

      return Response.ok(jsonEncode({'message': 'Item restored'}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  return router;
}

/// Creates a [Handler] for vault routes with auth middleware applied.
Handler vaultHandler() {
  return const Pipeline()
      .addMiddleware(authMiddleware())
      .addHandler(vaultRouter().call);
}
