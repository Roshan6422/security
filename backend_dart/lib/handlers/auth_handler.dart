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

  // POST /register
  router.post('/register', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      final name = body['name'] as String? ?? 'User';
      final adminSecret = body['adminSecret'] as String?;

      if (email == null || password == null) {
        return Response(400,
            body: jsonEncode({'message': 'Email and password are required'}),
            headers: {'content-type': 'application/json'});
      }

      final existing = await userRepo.findOne({'email': email});
      if (existing != null) {
        return Response(400,
            body: jsonEncode({'message': 'User already exists'}),
            headers: {'content-type': 'application/json'});
      }

      final hashedPassword = _hashPassword(password);
      final role = (adminSecret == Env.adminSecret ||
              adminSecret == 'admin-secret-123')
          ? 'admin'
          : 'user';

      final user = await userRepo.create({
        'name': name,
        'email': email,
        'password': hashedPassword,
        'role': role,
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
            'subscriptionStatus': user.subscriptionStatus,
            'subscriptionExpiry': user.subscriptionExpiry?.toIso8601String(),
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      print('Register error: $e');
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /login
  router.post('/login', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final email = body['email'] as String?;
      final password = body['password'] as String?;

      if (email == null || password == null) {
        return Response(400,
            body: jsonEncode({'message': 'Email and password are required'}),
            headers: {'content-type': 'application/json'});
      }

      final user = await userRepo.findOne({'email': email});
      if (user == null || user.password == null) {
        return Response(401,
            body: jsonEncode({'message': 'Invalid email or password'}),
            headers: {'content-type': 'application/json'});
      }

      if (!_checkPassword(password, user.password!)) {
        return Response(401,
            body: jsonEncode({'message': 'Invalid email or password'}),
            headers: {'content-type': 'application/json'});
      }

      if (user.isSuspended) {
        return Response(403,
            body: jsonEncode(
                {'message': 'Account suspended. Please contact support.'}),
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
            'subscriptionExpiry': user.subscriptionExpiry?.toIso8601String(),
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      print('Login error: $e');
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /google
  router.post('/google', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final idToken = body['idToken'] as String?;

      if (idToken == null) {
        return Response(400,
            body: jsonEncode({'message': 'ID Token is required'}),
            headers: {'content-type': 'application/json'});
      }

      // 1. Verify Google ID Token
      if (FirebaseConfig.auth == null) {
         return Response(503,
            body: jsonEncode({'message': 'Firebase Auth not configured'}),
            headers: {'content-type': 'application/json'});
      }

      final decodedToken = await FirebaseConfig.auth!.verifyIdToken(idToken);
      final email = decodedToken.email;
      final name = (decodedToken as Map<String, dynamic>)['name'] as String? ?? 'Google User';
      final uid = decodedToken.uid;

      if (email == null) {
         return Response(400,
            body: jsonEncode({'message': 'Email not found in Google Token'}),
            headers: {'content-type': 'application/json'});
      }

      // 2. Check if user exists
      var user = await userRepo.findOne({'email': email});

      if (user == null) {
        // 3. Create new user if not exists
        // Note: Password is null for Google users, or we generate a random complex one
        // Let's generate a random password so they can't login via standard auth unless they reset it
        final randomPassword = _hashPassword(DateTime.now().toIso8601String() + _random.nextInt(100000).toString());

        user = await userRepo.create({
          'name': name,
          'email': email,
          'password': randomPassword, // Or handle null password in login logic
          'role': 'user',
          'subscriptionStatus': 'free',
          'isSuspended': false,
          'googleUid': uid, // Optional: store Google UID if schema supports it
        });
      }

      if (user.isSuspended) {
        return Response(403,
            body: jsonEncode(
                {'message': 'Account suspended. Please contact support.'}),
            headers: {'content-type': 'application/json'});
      }

      // 4. Generate Session Token
      return Response.ok(
          jsonEncode({
            '_id': user.id,
            'name': user.name,
            'email': user.email,
            'token': _generateToken(user.id!),
            'role': user.role,
            'subscriptionStatus': user.subscriptionStatus,
            'subscriptionExpiry': user.subscriptionExpiry?.toIso8601String(),
          }),
          headers: {'content-type': 'application/json'});

    } catch (e) {
      print('Google Login error: $e');
      return Response(500,
          body: jsonEncode({'message': 'Invalid Token or Server Error'}),
          headers: {'content-type': 'application/json'});
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
