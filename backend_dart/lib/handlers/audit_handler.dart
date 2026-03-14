import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:crypto/crypto.dart';

import '../middleware/auth_middleware.dart';
import '../models/firestore_model.dart';

class AuditEntry extends FirestoreModel {
  String userId;
  String type;
  String action;
  String detail;
  String hash;
  String fileUrl;
  String fileType;
  DateTime timestamp;

  AuditEntry({
    this.userId = '',
    this.type = 'file',
    this.action = '',
    this.detail = '',
    this.hash = '',
    this.fileUrl = '',
    this.fileType = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String get collectionName => 'audit_logs';

  @override
  Map<String, dynamic> toMap() => {
    'userId': userId,
    'type': type,
    'action': action,
    'detail': detail,
    'hash': hash,
    'fileUrl': fileUrl,
    'fileType': fileType,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AuditEntry.fromMap(Map<String, dynamic> map) {
    final entry = AuditEntry(
      userId: map['userId'] as String? ?? '',
      type: map['type'] as String? ?? 'file',
      action: map['action'] as String? ?? '',
      detail: map['detail'] as String? ?? '',
      hash: map['hash'] as String? ?? '',
      fileUrl: map['fileUrl'] as String? ?? '',
      fileType: map['fileType'] as String? ?? '',
      timestamp: FirestoreModel.parseDate(map['timestamp']) ?? DateTime.now(),
    );
    entry.populateFromMap(map);
    return entry;
  }
}

final _auditRepo = ModelRepository<AuditEntry>(
    'audit_logs', AuditEntry.fromMap);

const _allowedTypes = {'security', 'file', 'key', 'backup', 'settings'};
const _allowedFileTypes = {'photo', 'video', 'audio', 'document', 'note', ''};

Router auditRouter() {
  final router = Router();

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

      final typeFilter = request.url.queryParameters['type'];
      final page = int.tryParse(
              request.url.queryParameters['page'] ?? '1') ?? 1;
      final limit = int.tryParse(
              request.url.queryParameters['limit'] ?? '50') ?? 50;

      // ✅ Ideally server-side filtered query
      final allEntries = await _auditRepo.find();
      var userEntries = allEntries
          .where((e) => e.userId == userId)
          .toList();

      if (typeFilter != null && typeFilter.isNotEmpty) {
        userEntries =
            userEntries.where((e) => e.type == typeFilter).toList();
      }

      userEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // ✅ Pagination
      final startIndex = (page - 1) * limit;
      final paginated = userEntries.skip(startIndex).take(limit).toList();

      return Response.ok(
        jsonEncode({
          'data': paginated.map((e) => {...e.toMap(), 'id': e.id}).toList(),
          'page': page,
          'total': userEntries.length,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      print('Audit GET error: $e\n$stackTrace');
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /
  router.post('/', (Request request) async {
    try {
      final user = getAuthUser(request);
      final userId = user.id;
      if (userId == null) {
        return Response(401,
            body: jsonEncode({'message': 'Invalid session'}),
            headers: {'content-type': 'application/json'});
      }

      final body = jsonDecode(await request.readAsString())
          as Map<String, dynamic>;

      final type = body['type'] as String? ?? 'file';
      final action = body['action'] as String? ?? '';
      final detail = body['detail'] as String? ?? '';
      final fileUrl = body['fileUrl'] as String? ?? '';
      final fileType = body['fileType'] as String? ?? '';

      // ✅ Input validation
      if (!_allowedTypes.contains(type)) {
        return Response(400,
            body: jsonEncode({'message': 'Invalid audit type'}),
            headers: {'content-type': 'application/json'});
      }
      if (!_allowedFileTypes.contains(fileType)) {
        return Response(400,
            body: jsonEncode({'message': 'Invalid file type'}),
            headers: {'content-type': 'application/json'});
      }

      // ✅ Single timestamp
      final now = DateTime.now();

      String previousHash = '';
      final allEntries = await _auditRepo.find();
      final userEntries =
          allEntries.where((e) => e.userId == userId).toList();
      userEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (userEntries.isNotEmpty) {
        previousHash = userEntries.last.hash;
      }

      final chainInput =
          '$previousHash|$userId|$type|$action|$detail'
          '|${now.toIso8601String()}';
      final newHash =
          sha256.convert(utf8.encode(chainInput)).toString();

      final entry = AuditEntry(
        userId: userId,
        type: type,
        action: action,
        detail: detail,
        hash: newHash,
        fileUrl: fileUrl,
        fileType: fileType,
        timestamp: now, // ✅ Same timestamp
      );
      await entry.save();

      return Response.ok(
        jsonEncode({
          'message': 'Audit entry created',
          'id': entry.id,
          'hash': newHash,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      print('Audit POST error: $e\n$stackTrace');
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // GET /verify — ✅ Actual chain verification
  router.get('/verify', (Request request) async {
    try {
      final user = getAuthUser(request);
      final userId = user.id;
      if (userId == null) {
        return Response(401,
            body: jsonEncode({'message': 'Invalid session'}),
            headers: {'content-type': 'application/json'});
      }

      final allEntries = await _auditRepo.find();
      final userEntries =
          allEntries.where((e) => e.userId == userId).toList();
      userEntries
          .sort((a, b) => a.timestamp.compareTo(b.timestamp));

      bool verified = true;
      String? brokenAtId;
      String previousHash = '';

      for (var entry in userEntries) {
        final chainInput =
            '$previousHash|${entry.userId}|${entry.type}'
            '|${entry.action}|${entry.detail}'
            '|${entry.timestamp.toIso8601String()}';
        final expectedHash =
            sha256.convert(utf8.encode(chainInput)).toString();

        if (entry.hash != expectedHash) {
          verified = false;
          brokenAtId = entry.id;
          break;
        }
        previousHash = entry.hash;
      }

      return Response.ok(
        jsonEncode({
          'verified': verified,
          'totalEvents': userEntries.length,
          if (!verified) 'brokenAt': brokenAtId,
          'message': verified
              ? 'All ${userEntries.length} events verified'
              : 'Chain integrity compromised',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      print('Audit verify error: $e\n$stackTrace');
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  return router;
}

Handler auditHandler() {
  return const Pipeline()
      .addMiddleware(authMiddleware())
      .addHandler(auditRouter().call);
}