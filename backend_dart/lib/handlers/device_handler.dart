import 'dart:convert';

import 'package:shelf/shelf.dart' as s;
import 'package:shelf_router/shelf_router.dart' as sr;
import 'package:uuid/uuid.dart';
import 'package:dart_firebase_admin/messaging.dart' as fcm;

import '../config/firebase.dart';
import '../middleware/auth_middleware.dart';
import '../models/firestore_model.dart';
import '../models/user.dart';



/// Device model stored in Firestore.
class DeviceEntry extends FirestoreModel {
  String userId;
  String deviceName;
  String model;
  String os;
  String platform;
  String? fcmToken;
  bool isTrusted;
  DateTime lastSeen;
  DateTime registeredAt;

  DeviceEntry({
    this.userId = '',
    this.deviceName = '',
    this.model = '',
    this.os = '',
    this.platform = 'android',
    this.fcmToken,
    this.isTrusted = true,
    DateTime? lastSeen,
    DateTime? registeredAt,
  })  : lastSeen = lastSeen ?? DateTime.now(),
        registeredAt = registeredAt ?? DateTime.now();

  @override
  String get collectionName => 'devices';

  @override
  Map<String, dynamic> toMap() => {
    'userId': userId,
    'deviceName': deviceName,
    'model': model,
    'os': os,
    'platform': platform,
    'fcmToken': fcmToken,
    'isTrusted': isTrusted,
    'lastSeen': lastSeen.toIso8601String(),
    'registeredAt': registeredAt.toIso8601String(),
  };

  factory DeviceEntry.fromMap(Map<String, dynamic> map) {
    final device = DeviceEntry(
      userId: map['userId'] as String? ?? '',
      deviceName: map['deviceName'] as String? ?? '',
      model: map['model'] as String? ?? '',
      os: map['os'] as String? ?? '',
      platform: map['platform'] as String? ?? 'android',
      fcmToken: map['fcmToken'] as String?,
      isTrusted: map['isTrusted'] as bool? ?? true,
      lastSeen: FirestoreModel.parseDate(map['lastSeen']) ?? DateTime.now(),
      registeredAt: FirestoreModel.parseDate(map['registeredAt']) ?? DateTime.now(),
    );
    device.populateFromMap(map);
    return device;
  }
}

final _deviceRepo = ModelRepository<DeviceEntry>('devices', DeviceEntry.fromMap);

/// Builds the `/api/device` router.
sr.Router deviceRouter() {
  final router = sr.Router();

  // POST /register — register or update a device
  router.post('/register', (s.Request request) async {
    try {
      final user = getAuthUser(request);
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final deviceName = body['deviceName'] as String? ?? 'Unknown Device';
      final model = body['model'] as String? ?? '';
      final os = body['os'] as String? ?? '';
      final platform = body['platform'] as String? ?? 'android';
      final fcmToken = body['fcmToken'] as String? ?? body['token'] as String?;

      // Check if this device model already registered for this user
      final allDevices = await _deviceRepo.find();
      final existing = allDevices.where(
        (d) => d.userId == user.id && d.model == model,
      ).toList();

      DeviceEntry device;
      if (existing.isNotEmpty) {
        // Update existing
        device = existing.first;
        device.deviceName = deviceName;
        device.os = os;
        device.platform = platform;
        device.fcmToken = fcmToken;
        device.lastSeen = DateTime.now();
        await device.save();
      } else {
        // Create new
        device = DeviceEntry(
          userId: user.id!,
          deviceName: deviceName,
          model: model,
          os: os,
          platform: platform,
          fcmToken: fcmToken,
          isTrusted: true,
        );
        await device.save();
      }

      // Also update user's deviceToken for backward compat
      final freshUser = await userRepo.findById(user.id!);
      if (freshUser != null && fcmToken != null) {
        freshUser.deviceToken = fcmToken;
        await freshUser.save();
      }

      return s.Response.ok(
        jsonEncode({
          'message': 'Device registered',
          'deviceId': device.id,
          'device': {...device.toMap(), 'id': device.id},
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return s.Response(500,
        body: jsonEncode({'message': 'Server error: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  });

  // GET /list — list all devices for user
  router.get('/list', (s.Request request) async {
    try {
      final user = getAuthUser(request);
      final allDevices = await _deviceRepo.find();
      final userDevices = allDevices
          .where((d) => d.userId == user.id)
          .toList();

      userDevices.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

      final result = userDevices.map((d) => {
        ...d.toMap(),
        'id': d.id,
      }).toList();

      return s.Response.ok(
        jsonEncode({
          'devices': result,
          'total': result.length,
          'trusted': userDevices.where((d) => d.isTrusted).length,
          'untrusted': userDevices.where((d) => !d.isTrusted).length,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return s.Response(500,
        body: jsonEncode({'message': 'Server error: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  });

  // PUT /<id>/trust — toggle device trust
  router.put('/<deviceId>/trust', (s.Request request, String deviceId) async {
    try {
      final user = getAuthUser(request);
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final trusted = body['trusted'] as bool? ?? true;

      final device = await _deviceRepo.findById(deviceId);
      if (device == null || device.userId != user.id) {
        return s.Response(404,
          body: jsonEncode({'message': 'Device not found'}),
          headers: {'content-type': 'application/json'},
        );
      }

      device.isTrusted = trusted;
      await device.save();

      return s.Response.ok(
        jsonEncode({'message': 'Device ${trusted ? "trusted" : "untrusted"}', 'device': {...device.toMap(), 'id': device.id}}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return s.Response(500,
        body: jsonEncode({'message': 'Server error: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  });

  // DELETE /<id> — remove device
  router.delete('/<deviceId>', (s.Request request, String deviceId) async {
    try {
      final user = getAuthUser(request);
      final device = await _deviceRepo.findById(deviceId);
      if (device == null || device.userId != user.id) {
        return s.Response(404,
          body: jsonEncode({'message': 'Device not found'}),
          headers: {'content-type': 'application/json'},
        );
      }

      await device.deleteOne();

      return s.Response.ok(
        jsonEncode({'message': 'Device removed'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return s.Response(500,
        body: jsonEncode({'message': 'Server error: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  });

  // POST /command (admin-only) — kept for backward compat
  router.post('/command', (s.Request request) async {
    try {
      final user = getAuthUser(request);
      if (user.role != 'admin') {
        return s.Response(403,
          body: jsonEncode({'message': 'Not authorized as admin'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final userId = body['userId'] as String?;
      final command = body['command'] as String?;

      if (userId == null || command == null) {
        return s.Response(400,
          body: jsonEncode({'message': 'userId and command required'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final targetUser = await userRepo.findById(userId);
      if (targetUser == null) {
        return s.Response(404,
          body: jsonEncode({'message': 'User not found'}),
          headers: {'content-type': 'application/json'},
        );
      }

      if (targetUser.deviceToken == null || targetUser.deviceToken!.isEmpty) {
        return s.Response(400,
          body: jsonEncode({'message': 'No device token registered for this user'}),
          headers: {'content-type': 'application/json'},
        );
      }

      print('[FCM] Sending command "$command" to token: ${targetUser.deviceToken}');

      final messaging = FirebaseConfig.messaging;
      if (messaging != null) {
        try {
          // Determine command action
          String action;
          switch (command.toUpperCase()) {
            case 'LOCK':
              action = 'LOCK_DEVICE';
              break;
            case 'ALARM':
              action = 'SOUND_ALARM';
              break;
            case 'LOCATION':
              action = 'GET_LOCATION';
              break;
            case 'WIPE':
              action = 'WIPE_DATA';
              break;
            default:
              return s.Response(400, body: jsonEncode({'message': 'Invalid command type'}));
          }

          final message = fcm.TokenMessage(
            token: targetUser.deviceToken!,
            data: {
              'command': action,
              'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          );
          
          final response = await messaging.send(message);
          print('[FCM] Successfully sent message: $response');
        } catch (e) {
          print('[FCM] Failed to send message: $e');
          return s.Response(500, body: jsonEncode({'message': 'Failed to send push notification: $e'}));
        }
      } else {
        print('[FCM] WARNING: Firebase Messaging is not initialized (In-Memory Fallback)');
      }

      return s.Response.ok(
        jsonEncode({'message': 'Command sent successfully', 'command': command}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return s.Response(500,
        body: jsonEncode({'message': 'Server error'}),
        headers: {'content-type': 'application/json'},
      );
    }
  });

  return router;
}

/// Creates a [s.Handler] for device routes.
s.Handler deviceHandler() {
  return const s.Pipeline()
      .addMiddleware(authMiddleware())
      .addHandler(deviceRouter().call);
}
