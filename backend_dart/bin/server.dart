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

Future<void> main() async {
  // Load environment variables from .env file
  env.load();

  // ── Initialize Firebase ────────────────────────────────────────────
  await FirebaseConfig.initialize();

  // ── Ensure uploads directory exists ────────────────────────────────
  final uploadsDir = Directory(Env.uploadsPath);
  if (!uploadsDir.existsSync()) {
    uploadsDir.createSync(recursive: true);
  }

  // ── Build the router ──────────────────────────────────────────────
  final app = Router();

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
