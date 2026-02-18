import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

import '../config/env.dart';
import '../models/user.dart';

/// Key used to attach the authenticated [User] to the request context.
const String userContextKey = 'user';

/// Middleware that verifies the JWT `Bearer` token from the
/// `Authorization` header and attaches the corresponding [User]
/// to the request context.
///
/// Returns 401 if the token is missing, invalid, or the user no longer
/// exists. Returns 403 if the account is suspended.
Middleware authMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(401,
            body: jsonEncode({'message': 'Not authorized, no token'}),
            headers: {'content-type': 'application/json'});
      }

      final token = authHeader.substring(7);

      try {
        final jwt = JWT.verify(token, SecretKey(Env.jwtSecret));
        final userId = jwt.payload['id'] as String?;

        if (userId == null) {
          return Response(401,
              body: jsonEncode({'message': 'Not authorized, invalid token'}),
              headers: {'content-type': 'application/json'});
        }

        final user = await userRepo.findById(userId);
        if (user == null) {
          return Response(401,
              body: jsonEncode(
                  {'message': 'Not authorized, user not found'}),
              headers: {'content-type': 'application/json'});
        }

        if (user.isSuspended) {
          return Response(403,
              body: jsonEncode(
                  {'message': 'Account suspended. Please contact support.'}),
              headers: {'content-type': 'application/json'});
        }

        // Attach user to context
        final updatedRequest = request.change(context: {userContextKey: user});
        return innerHandler(updatedRequest);
      } catch (e) {
        return Response(401,
            body: jsonEncode(
                {'message': 'Not authorized, token failed'}),
            headers: {'content-type': 'application/json'});
      }
    };
  };
}

/// Extracts the authenticated [User] from the request context.
///
/// Must only be called on routes protected by [authMiddleware].
User getAuthUser(Request request) {
  return request.context[userContextKey] as User;
}
