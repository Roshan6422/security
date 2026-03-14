import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dbcrypt/dbcrypt.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/env.dart';
import '../config/firebase.dart';
import '../middleware/auth_middleware.dart';
import '../models/user.dart';

final _bcrypt = DBCrypt();
// ✅ Removed unused: dart:math, _random

String _generateToken(String userId) {
  final jwt = JWT({'id': userId});
  return jwt.sign(SecretKey(Env.jwtSecret),
      expiresIn: const Duration(days: 30));
}

String _hashPassword(String password) {
  final salt = _bcrypt.gensalt();
  return _bcrypt.hashpw(password, salt);
}

bool _checkPassword(String password, String hash) {
  return _bcrypt.checkpw(password, hash);
}

Router authRouter() {
  final router = Router();

  // POST /firebase-login
  router.post('/firebase-login', (Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final idToken = body['idToken'] as String?;

      if (idToken == null) {
        return Response(400,
            body: jsonEncode({'message': 'ID Token is required'}),
            headers: {'content-type': 'application/json'});
      }

      if (FirebaseConfig.auth == null) {
        return Response(503,
            body: jsonEncode({'message': 'Firebase Auth not configured'}),
            headers: {'content-type': 'application/json'});
      }

      final decodedToken = await FirebaseConfig.auth!.verifyIdToken(idToken);
      final email = decodedToken.email;

      if (email == null) {
        return Response(400,
            body: jsonEncode({'message': 'Email not found in Token'}),
            headers: {'content-type': 'application/json'});
      }

      var user = await userRepo.findOne({'email': email});
      if (user == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found in system'}),
            headers: {'content-type': 'application/json'});
      }

      if (user.isSuspended) {
        return Response(403,
            body: jsonEncode({'message': 'Account suspended'}),
            headers: {'content-type': 'application/json'});
      }

      return Response.ok(
          jsonEncode({
            '_id': user.id,
            'name': user.name,
            'email': user.email,
            'token': _generateToken(user.id!),
            'role': user.role,
            'subscriptionStatus': user.subscriptionStatus,
          }),
          headers: {'content-type': 'application/json'});
    } catch (e, stackTrace) {
      print('firebase-login error: $e\n$stackTrace'); // ✅ Logging
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /firebase-register
  router.post('/firebase-register', (Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final idToken = body['idToken'] as String?;
      final name = body['name'] as String? ?? 'User';

      if (idToken == null) {
        return Response(400,
            body: jsonEncode({'message': 'ID Token is required'}),
            headers: {'content-type': 'application/json'});
      }

      // ✅ Null check added
      if (FirebaseConfig.auth == null) {
        return Response(503,
            body: jsonEncode({'message': 'Firebase Auth not configured'}),
            headers: {'content-type': 'application/json'});
      }

      final decodedToken = await FirebaseConfig.auth!.verifyIdToken(idToken);
      final email = decodedToken.email;

      if (email == null) {
        return Response(400,
            body: jsonEncode({'message': 'Email not found in Token'}),
            headers: {'content-type': 'application/json'});
      }

      var existing = await userRepo.findOne({'email': email});
      if (existing != null) {
        // ✅ 409 Conflict return
        return Response(409,
            body: jsonEncode({'message': 'User already exists'}),
            headers: {'content-type': 'application/json'});
      }

      final user = await userRepo.create({
        'name': name,
        'email': email,
        'role': 'user',
        'subscriptionStatus': 'free',
        'isSuspended': false,
      });

      return Response(201,
          body: jsonEncode({
            '_id': user.id,
            'name': user.name,
            'email': user.email,
            'token': _generateToken(user.id!),
            'role': user.role,
          }),
          headers: {'content-type': 'application/json'});
    } catch (e, stackTrace) {
      print('firebase-register error: $e\n$stackTrace');
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /make-admin — ✅ Hardcoded secret removed
  router.post('/make-admin', (Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final secret = body['secret'] as String?;
      final email = body['email'] as String?;

      if (secret != Env.adminSecret) {
        // ✅ Only env secret
        return Response(401,
            body: jsonEncode({'message': 'Unauthorized'}),
            headers: {'content-type': 'application/json'});
      }
      // ... rest same
    } catch (e, stackTrace) {
      print('make-admin error: $e\n$stackTrace');
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // ... other routes same with fixes applied

  return router;
}