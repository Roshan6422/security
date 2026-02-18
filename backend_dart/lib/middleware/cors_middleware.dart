import 'package:shelf/shelf.dart';

/// Middleware that adds CORS headers to every response.
///
/// Allows all origins, common HTTP methods, and the `Content-Type`
/// plus `Authorization` headers. Handles preflight `OPTIONS` requests.
Middleware corsMiddleware() {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }

      final response = await innerHandler(request);
      return response.change(headers: corsHeaders);
    };
  };
}
