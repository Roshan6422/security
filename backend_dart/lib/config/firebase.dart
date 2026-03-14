import 'dart:convert';
import 'dart:io';

import 'package:dart_firebase_admin/auth.dart';
import 'package:dart_firebase_admin/dart_firebase_admin.dart';
import 'package:dart_firebase_admin/firestore.dart';
import 'package:dart_firebase_admin/messaging.dart';

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

  /// Returns the service account JSON if available.
  static Map<String, dynamic>? get serviceAccount {
    final base64Key = Env.firebaseServiceAccountBase64;
    if (base64Key == null || base64Key.isEmpty) return null;
    try {
      final cleanBase64 = base64Key.replaceAll(RegExp(r'\s|"'), '');
      return jsonDecode(utf8.decode(base64Decode(cleanBase64)));
    } catch (_) {
      return null;
    }
  }

  /// The Auth instance, or `null` when running in-memory.
  static Auth? get auth => _app != null ? Auth(_app!) : null;

  /// The Messaging instance, or `null` when running in-memory.
  static Messaging? get messaging => _app != null ? Messaging(_app!) : null;

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
      final cleanBase64 = base64Key.replaceAll(RegExp(r'\s|"'), '');
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

      print('[FIREBASE] Server Time (UTC): ${DateTime.now().toUtc().toIso8601String()}');
      
      // DIAGNOSTIC: Check for required fields
      final requiredFields = ['project_id', 'client_email', 'private_key', 'type'];
      for (final field in requiredFields) {
        if (!serviceAccount.containsKey(field)) {
          print('❌ [FIREBASE] Missing required field: $field');
        }
      }

      // Ensure private key handles literal \n correctly and remove any \r or extra spaces
      if (serviceAccount['private_key'] is String) {
        String key = serviceAccount['private_key'] as String;
        key = key.replaceAll(r'\n', '\n');
        key = key.replaceAll(r'\r', '');
        key = key.trim();
        
        // Ensure it has the correct header/footer
        if (!key.contains('-----BEGIN PRIVATE KEY-----')) {
          print('⚠️ [FIREBASE] Private key missing standard PEM header');
        }
        
        serviceAccount['private_key'] = key;
        print('[FIREBASE] Private Key Cleaned. New Length: ${key.length}');
        
        // Log masked header/footer
        final header = key.length > 20 ? key.substring(0, 25).replaceAll('\n', '[NL]') : 'short';
        final footer = key.length > 20 ? key.substring(key.length - 25).replaceAll('\n', '[NL]') : 'short';
        print('[FIREBASE] Private Key Tags: $header...$footer');
      }
      
      // Write to a temporary file to satisfy Credential.fromServiceAccount(File)
      final tempFile = File('service_account.json');
      await tempFile.writeAsString(jsonEncode(serviceAccount));
      
      print('[FIREBASE] Using Credential.fromServiceAccount with file: ${tempFile.path}');
      final credential = Credential.fromServiceAccount(tempFile);

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
