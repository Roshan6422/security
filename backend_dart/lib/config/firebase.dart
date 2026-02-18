import 'dart:convert';

import 'package:dart_firebase_admin/auth.dart';
import 'package:dart_firebase_admin/dart_firebase_admin.dart';
import 'package:dart_firebase_admin/firestore.dart';

import 'env.dart';

/// Global Firebase / Firestore state.
///
/// When Firebase credentials are unavailable or the connection fails,
/// the application falls back to an in-memory data store.
class FirebaseConfig {
  FirebaseConfig._();

  static FirebaseAdminApp? _app;
  static Firestore? _db;
  static bool _initialized = false;

  /// Whether Firebase is initialised and Firestore is reachable.
  static bool get isInitialized => _initialized;

  /// The Firestore instance, or `null` when running in-memory.
  static Firestore? get db => _db;

  /// The Auth instance, or `null` when running in-memory.
  static Auth? get auth => _app != null ? Auth(_app!) : null;

  /// Attempts to initialise Firebase from the Base64-encoded service
  /// account key in the environment. Logs diagnostic information and
  /// falls back to in-memory mode on failure.
  static Future<void> initialize() async {
    final base64Key = Env.firebaseServiceAccountBase64;

    if (base64Key == null || base64Key.isEmpty) {
      print('[FIREBASE] No FIREBASE_SERVICE_ACCOUNT_BASE64 env variable found.');
      print('⚠️  Firebase not initialized. Using IN-MEMORY mode.');
      return;
    }

    print('[FIREBASE] Found FIREBASE_SERVICE_ACCOUNT_BASE64 env variable');

    try {
      final cleanBase64 = base64Key.replaceAll(RegExp(r'\s'), '');
      print('[FIREBASE] Base64 length: ${base64Key.length} -> Cleaned length: ${cleanBase64.length}');

      final decodedBytes = base64Decode(cleanBase64);
      final decodedJson = utf8.decode(decodedBytes);
      print('[FIREBASE] Decoded JSON length: ${decodedJson.length}');
      print('[FIREBASE] JSON Start: ${decodedJson.substring(0, 40)}...');
      print('[FIREBASE] JSON End: ...${decodedJson.substring(decodedJson.length - 40)}');

      // Validate JSON
      final Map<String, dynamic> serviceAccount =
          jsonDecode(decodedJson) as Map<String, dynamic>;
      print('[FIREBASE] JSON parse successful');

      final projectId = serviceAccount['project_id'] as String?;
      if (projectId == null) {
        throw FormatException('Missing project_id in service account JSON');
      }

      final credential = Credential.fromServiceAccountParams(
        clientId: serviceAccount['client_id'] as String,
        email: serviceAccount['client_email'] as String,
        privateKey: serviceAccount['private_key'] as String,
      );

      _app = FirebaseAdminApp.initializeApp(
        projectId,
        credential,
      );

      _db = Firestore(_app!);
      _initialized = true;
      print('✅ Firebase Admin SDK Initialized');

      // Verify Firestore connection
      await _verifyConnection();
    } catch (e) {
      print('[FIREBASE] Failed to initialize: $e');
      print('⚠️  Firebase not initialized. Using IN-MEMORY mode.');
      _initialized = false;
      _db = null;
    }
  }

  static Future<void> _verifyConnection() async {
    if (!_initialized || _db == null) return;

    try {
      print('⏳ Verifying Firestore connection...');
      await _db!
          .collection('_health_check')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      print('✅ Firestore connection verified');
    } catch (e) {
      print('❌ Firestore connection test failed: $e');
      print('⚠️  Falling back to IN-MEMORY mode (data will not persist).');
      _initialized = false;
      _db = null;
    }
  }
}
