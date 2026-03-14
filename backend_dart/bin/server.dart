import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:dotenv/dotenv.dart';

import 'package:backend_dart/config/env.dart';
import 'package:backend_dart/config/firebase.dart';
import 'package:backend_dart/middleware/cors_middleware.dart';
import 'package:backend_dart/handlers/auth_handler.dart';
import 'package:backend_dart/handlers/vault_handler.dart';
import 'package:backend_dart/handlers/admin_handler.dart';
import 'package:backend_dart/handlers/payment_handler.dart';
import 'package:backend_dart/handlers/support_handler.dart';
import 'package:backend_dart/handlers/device_handler.dart';
import 'package:backend_dart/handlers/audit_handler.dart';

Future<void> main() async {
  print('🚀 Backend starting up...');
  // Load environment variables from .env file
  try {
    env.load();
  } catch (e) {
    print('ℹ️  Note: .env file not found, using system environment variables.');
  }

  // ── Initialize Firebase ────────────────────────────────────────────
  print('ℹ️  Available Environment Variables: ${Platform.environment.keys.join(", ")}');
  await FirebaseConfig.initialize();

  // ── Ensure uploads directory exists ────────────────────────────────
  final uploadsDir = Directory(Env.uploadsPath);
  if (!uploadsDir.existsSync()) {
    uploadsDir.createSync(recursive: true);
  }

  // ── Build the router ──────────────────────────────────────────────
  final app = Router();

  // Root welcome message
  app.get('/', (Request request) {
    return Response.ok(
        jsonEncode({
          'message': '🚀 SafeShell Dart Backend is live! (V2 - Firebase Integrated)',
          'documentation': 'https://github.com/Roshan6422/security',
          'endpoints': {
            'health': '/api/health',
            'auth': '/api/auth',
            'vault': '/api/vault',
            'admin': '/api/admin',
          }
        }),
        headers: {'content-type': 'application/json'});
  });

  // Diagnostic route
  app.get('/api/auth/ping', (Request request) {
    return Response.ok(jsonEncode({'message': 'pong', 'info': 'Direct route on main router'}), headers: {'content-type': 'application/json'});
  });

  // Health check
  app.get('/api/health', (Request request) {
    return Response.ok(
        jsonEncode({
          'status': 'OK',
          'timestamp': DateTime.now().toIso8601String(),
          'firebase': FirebaseConfig.isInitialized
              ? 'connected'
              : 'in-memory mode',
        }),
        headers: {'content-type': 'application/json'});
  });

  // Mount route handlers (middleware is applied within the handler)
  app.mount('/api/auth', authHandler());
  app.mount('/api/vault', vaultHandler());
  app.mount('/api/admin', adminHandler());
  app.mount('/api/payment', paymentHandler());
  app.mount('/api/support', supportHandler());
  app.mount('/api/device', deviceHandler());
  app.mount('/api/audit', auditHandler());

  // Catch-all for 404s
  app.all('/<ignored|.*>', (Request request) {
    print('⚠️  404 - Not Found: ${request.method} ${request.url.path}');
    print('   Full URL: ${request.requestedUri}');
    print('   Headers: ${request.headers}');
    return Response.notFound(
      jsonEncode({
        'message': 'Route not found: ${request.url.path}',
        'requested_method': request.method,
        'requested_url': request.url.toString(),
        'full_uri': request.requestedUri.toString(),
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  // Static file serving for uploads
  final staticHandler = createStaticHandler(
    Env.uploadsPath,
    defaultDocument: 'index.html',
  );
  app.mount('/uploads', staticHandler);

  // ── Middleware pipeline ────────────────────────────────────────────
  final handler = const Pipeline()
      .addMiddleware(corsMiddleware())
      .addMiddleware(logRequests())
      .addHandler(app.call);

  // ── Start server ──────────────────────────────────────────────────
  final port = Env.port;
  final server = await shelf_io.serve(handler, '0.0.0.0', port);
  server.autoCompress = true;

  print('');
  print('╔══════════════════════════════════════════════════════════╗');
  print('║  🚀 SafeShell Dart Backend                              ║');
  print('║  Server is live on 0.0.0.0:$port${' ' * (28 - port.toString().length)}║');
  print('║  Firebase: ${FirebaseConfig.isInitialized ? '✅ Connected' : '⚠️  In-Memory'}${' ' * (FirebaseConfig.isInitialized ? 17 : 16)}║');
  print('╚══════════════════════════════════════════════════════════╝');
  print('');

  // Graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('\n🛑 Shutting down...');
    await server.close(force: true);
    exit(0);
  });
}
