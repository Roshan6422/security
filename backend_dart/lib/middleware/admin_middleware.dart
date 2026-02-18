import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'auth_middleware.dart';

/// Middleware that checks the authenticated user has role `admin`.
///
/// Must be applied **after** [authMiddleware].
Middleware adminMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final user = getAuthUser(request);
      if (user.role != 'admin') {
        return Response(401,
            body: jsonEncode({'message': 'Not authorized as an admin'}),
            headers: {'content-type': 'application/json'});
      }
      return innerHandler(request);
    };
  };
}
