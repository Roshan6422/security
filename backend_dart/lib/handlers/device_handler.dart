import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../middleware/auth_middleware.dart';
import '../models/user.dart';

/// Builds the `/api/device` router.
///
/// Authentication is handled by [deviceHandler].
Router deviceRouter() {
  final router = Router();

  // POST /register
  router.post('/register', (Request request) async {
    try {
      final user = getAuthUser(request);
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final token = body['fcmToken'] as String? ?? body['token'] as String?;

      if (token == null || token.isEmpty) {
        return Response(400,
            body: jsonEncode({'message': 'FCM token required'}),
            headers: {'content-type': 'application/json'});
      }

      final freshUser = await userRepo.findById(user.id!);
      if (freshUser == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      freshUser.deviceToken = token;
      await freshUser.save();

      return Response.ok(
          jsonEncode({
            'message': 'Device registered successfully',
            'deviceToken': token,
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /command (admin-only)
  router.post('/command', (Request request) async {
    try {
      final user = getAuthUser(request);
      if (user.role != 'admin') {
        return Response(403,
            body: jsonEncode({'message': 'Not authorized as admin'}),
            headers: {'content-type': 'application/json'});
      }

      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final userId = body['userId'] as String?;
      final command = body['command'] as String?;

      if (userId == null || command == null) {
        return Response(400,
            body: jsonEncode({'message': 'userId and command required'}),
            headers: {'content-type': 'application/json'});
      }

      final targetUser = await userRepo.findById(userId);
      if (targetUser == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      if (targetUser.deviceToken == null || targetUser.deviceToken!.isEmpty) {
        return Response(400,
            body: jsonEncode(
                {'message': 'No device token registered for this user'}),
            headers: {'content-type': 'application/json'});
      }

      // TODO: Implement actual FCM sending via googleapis
      print('[FCM] Sending command "$command" to token: ${targetUser.deviceToken}');

      return Response.ok(
          jsonEncode({
            'message': 'Command sent successfully',
            'command': command,
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  return router;
}

/// Creates a [Handler] for device routes.
Handler deviceHandler() {
  return const Pipeline()
      .addMiddleware(authMiddleware())
      .addHandler(deviceRouter().call);
}
