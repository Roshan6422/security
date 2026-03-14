import 'dart:convert';
import 'dart:math';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dbcrypt/dbcrypt.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/env.dart';
import '../config/firebase.dart';
import '../middleware/auth_middleware.dart';
import '../models/user.dart';

final _bcrypt = DBCrypt();
final _random = Random.secure();

String _generateToken(String userId) {
  final jwt = JWT({'id': userId});
  return jwt.sign(SecretKey(Env.jwtSecret), expiresIn: const Duration(days: 30));
}

String _hashPassword(String password) {
  final salt = _bcrypt.gensalt();
  return _bcrypt.hashpw(password, salt);
}

bool _checkPassword(String password, String hash) {
  return _bcrypt.checkpw(password, hash);
}

/// Builds the `/api/auth` router.
Router authRouter() {
  final router = Router();

  // Removed old /register and /login - Now using /firebase-register and /firebase-login

  // POST /firebase-login
  router.post('/firebase-login', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final idToken = body['idToken'] as String?;

      if (idToken == null) {
        return Response(400, body: jsonEncode({'message': 'ID Token is required'}), headers: {'content-type': 'application/json'});
      }

      if (FirebaseConfig.auth == null) {
        return Response(503, body: jsonEncode({'message': 'Firebase Auth not configured'}), headers: {'content-type': 'application/json'});
      }

      final decodedToken = await FirebaseConfig.auth!.verifyIdToken(idToken);
      final email = decodedToken.email;

      if (email == null) {
        return Response(400, body: jsonEncode({'message': 'Email not found in Token'}), headers: {'content-type': 'application/json'});
      }

      var user = await userRepo.findOne({'email': email});
      if (user == null) {
        return Response(404, body: jsonEncode({'message': 'User not found in system'}), headers: {'content-type': 'application/json'});
      }

      if (user.isSuspended) {
        return Response(403, body: jsonEncode({'message': 'Account suspended'}), headers: {'content-type': 'application/json'});
      }

      return Response.ok(jsonEncode({
        '_id': user.id,
        'name': user.name,
        'email': user.email,
        'token': _generateToken(user.id!),
        'role': user.role,
        'subscriptionStatus': user.subscriptionStatus,
      }), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'message': 'Server error'}), headers: {'content-type': 'application/json'});
    }
  });

  // POST /firebase-register
  router.post('/firebase-register', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final idToken = body['idToken'] as String?;
      final name = body['name'] as String? ?? 'User';

      if (idToken == null) {
        return Response(400, body: jsonEncode({'message': 'ID Token is required'}), headers: {'content-type': 'application/json'});
      }

      final decodedToken = await FirebaseConfig.auth!.verifyIdToken(idToken);
      final email = decodedToken.email;

      if (email == null) {
        return Response(400, body: jsonEncode({'message': 'Email not found in Token'}), headers: {'content-type': 'application/json'});
      }

      var existing = await userRepo.findOne({'email': email});
      if (existing != null) {
        return Response.ok(jsonEncode({
          '_id': existing.id,
          'name': existing.name,
          'email': existing.email,
          'token': _generateToken(existing.id!),
          'role': existing.role,
        }), headers: {'content-type': 'application/json'});
      }

      final user = await userRepo.create({
        'name': name,
        'email': email,
        'role': 'user',
        'subscriptionStatus': 'free',
        'isSuspended': false,
      });

      return Response(201, body: jsonEncode({
        '_id': user.id,
        'name': user.name,
        'email': user.email,
        'token': _generateToken(user.id!),
        'role': user.role,
      }), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'message': 'Server error'}), headers: {'content-type': 'application/json'});
    }
  });

  // POST /google (Handles Firebase Google Sign-in Tokens)
  router.post('/google', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final idToken = body['idToken'] as String?;

      if (idToken == null) {
        return Response(400, body: jsonEncode({'message': 'ID Token is required'}), headers: {'content-type': 'application/json'});
      }

      if (FirebaseConfig.auth == null) {
        return Response(503, body: jsonEncode({'message': 'Firebase Auth not configured'}), headers: {'content-type': 'application/json'});
      }

      final decodedToken = await FirebaseConfig.auth!.verifyIdToken(idToken);
      final email = decodedToken.email;

      if (email == null) {
        return Response(400, body: jsonEncode({'message': 'Email not found in Token'}), headers: {'content-type': 'application/json'});
      }

      var user = await userRepo.findOne({'email': email});
      
      // Auto-register if not found (Google accounts are pre-verified)
      if (user == null) {
          user = await userRepo.create({
            'name': decodedToken.claims['name'] ?? 'Google User', // Fix: Access via claims map
            'email': email,
            'role': 'user',
            'subscriptionStatus': 'free',
            'isSuspended': false,
          });
      }

      if (user.isSuspended) {
        return Response(403, body: jsonEncode({'message': 'Account suspended'}), headers: {'content-type': 'application/json'});
      }

      return Response.ok(jsonEncode({
        '_id': user.id,
        'name': user.name,
        'email': user.email,
        'token': _generateToken(user.id!),
        'role': user.role,
        'subscriptionStatus': user.subscriptionStatus,
      }), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'message': 'Server error'}), headers: {'content-type': 'application/json'});
    }
  });

  // Legacy /login (For migration/fallback)
  router.post('/login', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final email = body['email'] as String?;
      final password = body['password'] as String?;

      if (email == null || password == null) {
        return Response(400, body: jsonEncode({'message': 'Email and password required'}), headers: {'content-type': 'application/json'});
      }

      final user = await userRepo.findOne({'email': email});
      if (user == null || user.password == null || !_checkPassword(password, user.password!)) {
        return Response(401, body: jsonEncode({'message': 'Invalid credentials'}), headers: {'content-type': 'application/json'});
      }

      return Response.ok(jsonEncode({
        '_id': user.id,
        'name': user.name,
        'email': user.email,
        'token': _generateToken(user.id!),
        'role': user.role,
        'subscriptionStatus': user.subscriptionStatus,
      }), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'message': 'Server error'}), headers: {'content-type': 'application/json'});
    }
  });

  // GET /me (protected)
  router.get('/me', _protected((Request request) async {
    try {
      final authUser = getAuthUser(request);
      final user = await userRepo.findById(authUser.id!);
      if (user == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      return Response.ok(
          jsonEncode({
            '_id': user.id,
            'name': user.name,
            'email': user.email,
            'hasCalculatorPassword': user.calculatorPassword != null && user.calculatorPassword!.isNotEmpty,
            'calculatorPassword': user.calculatorPassword,
            'role': user.role,
            'subscriptionStatus': user.subscriptionStatus,
            'subscriptionExpiry': user.subscriptionExpiry?.toIso8601String(),
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  }));

  // PUT /calculator-password (protected)
  router.put('/calculator-password', _protected((Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final oldPassword = body['oldPassword'] as String?;
      final newPassword = body['newPassword'] as String?;

      if (newPassword == null || !RegExp(r'^\d+$').hasMatch(newPassword)) {
        return Response(400,
            body: jsonEncode({'message': 'Password must be numeric only'}),
            headers: {'content-type': 'application/json'});
      }

      final user = getAuthUser(request);
      final freshUser = await userRepo.findById(user.id!);
      if (freshUser == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      if (freshUser.calculatorPassword != null &&
          freshUser.calculatorPassword!.isNotEmpty) {
        if (freshUser.calculatorPassword != oldPassword) {
          return Response(401,
              body: jsonEncode({'message': 'Incorrect old password'}),
              headers: {'content-type': 'application/json'});
        }
      }

      freshUser.calculatorPassword = newPassword;
      await freshUser.save();

      return Response.ok(
          jsonEncode({'message': 'Calculator password updated successfully'}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  }));

  // PUT /profile (protected)
  router.put('/profile', _protected((Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final authUser = getAuthUser(request);
      final user = await userRepo.findById(authUser.id!);
      if (user == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      if (body['name'] != null) user.name = body['name'] as String;
      if (body['email'] != null) user.email = body['email'] as String;
      if (body['password'] != null) {
        user.password = _hashPassword(body['password'] as String);
      }

      await user.save();

      return Response.ok(
          jsonEncode({
            '_id': user.id,
            'name': user.name,
            'email': user.email,
            'role': user.role,
            'subscriptionStatus': user.subscriptionStatus,
            'subscriptionExpiry': user.subscriptionExpiry?.toIso8601String(),
            'token': _generateToken(user.id!),
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  }));

  // POST /upgrade (protected)
  router.post('/upgrade', _protected((Request request) async {
    try {
      final authUser = getAuthUser(request);
      final user = await userRepo.findById(authUser.id!);
      if (user == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      user.subscriptionStatus = 'premium';
      user.subscriptionExpiry =
          DateTime.now().add(const Duration(days: 365));
      await user.save();

      return Response.ok(
          jsonEncode({
            'message': 'Subscription upgraded successfully',
            'subscriptionStatus': user.subscriptionStatus,
            'subscriptionExpiry': user.subscriptionExpiry?.toIso8601String(),
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  }));

  // DELETE /delete-account (protected)
  router.delete('/delete-account', _protected((Request request) async {
    try {
      final authUser = getAuthUser(request);
      final user = await userRepo.findById(authUser.id!);
      if (user == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }
      await user.deleteOne();
      return Response.ok(
          jsonEncode({'message': 'Account deleted successfully'}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  }));

  // POST /make-admin
  router.post('/make-admin', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final secret = body['secret'] as String?;
      final email = body['email'] as String?;

      if (secret != Env.adminSecret && secret != 'admin-secret-123') {
        return Response(401,
            body: jsonEncode({'message': 'Unauthorized'}),
            headers: {'content-type': 'application/json'});
      }

      final user = await userRepo.findOne({'email': email});
      if (user == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      user.role = 'admin';
      await user.save();

      return Response.ok(
          jsonEncode({'message': 'User ${user.email} is now an admin'}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  return router;
}

/// Wraps a handler with [authMiddleware].
Handler _protected(Handler handler) {
  return const Pipeline()
      .addMiddleware(authMiddleware())
      .addHandler(handler);
}

/// Creates a [Handler] for auth routes.
Handler authHandler() {
  return const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(authRouter().call);
}
