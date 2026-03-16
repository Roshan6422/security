import 'dart:convert';
import 'dart:io';

import 'package:dart_firebase_admin/auth.dart';
import 'package:dart_firebase_admin/dart_firebase_admin.dart';
import 'package:dart_firebase_admin/firestore.dart';
import 'package:dart_firebase_admin/messaging.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

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
      final Map<String, dynamic> decoded = jsonDecode(utf8.decode(base64Decode(cleanBase64)));
      if (decoded['private_key'] is String) {
        decoded['private_key'] = _cleanPrivateKey(decoded['private_key'] as String);
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// The Auth instance, or `null` when running in-memory.
  static Auth? get auth => _app != null ? Auth(_app!) : null;

  /// The Messaging instance, or `null` when running in-memory.
  static Messaging? get messaging => _app != null ? Messaging(_app!) : null;

  /// Robust cleaner for PEM private keys.
  static String _cleanPrivateKey(String key) {
    if (key.isEmpty) return key;

    // 1. Handle common escaping issues from environment variables
    key = key.replaceAll(r'\\n', '\n');
    key = key.replaceAll(r'\n', '\n');
    key = key.replaceAll(r'\r', '');
    key = key.trim();

    // 2. Extract base64 content and remove any invalid characters (like spaces/newlines)
    const header = '-----BEGIN PRIVATE KEY-----';
    const footer = '-----END PRIVATE KEY-----';

    if (key.contains(header) && key.contains(footer)) {
      final start = key.indexOf(header) + header.length;
      final end = key.indexOf(footer);
      String content = key.substring(start, end);
      
      // Remove EVERYTHING that is not valid Base64 (A-Z, a-z, 0-9, +, /, =)
      content = content.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
      
      // Reconstruct exactly
      return '$header\n$content\n$footer';
    }

    return key;
  }

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
      // Robust cleaning: remove everything EXCEPT valid Base64 characters
      final cleanBase64 = base64Key.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
      print('[FIREBASE] Base64 length: ${base64Key.length} -> Cleaned length: ${cleanBase64.length}');

      final decodedBytes = base64Decode(cleanBase64);
      final decodedJson = utf8.decode(decodedBytes);
      print('[FIREBASE] Decoded JSON length: ${decodedJson.length}');
      
      // Validate JSON
      final Map<String, dynamic> serviceAccount =
          jsonDecode(decodedJson) as Map<String, dynamic>;
      print('[FIREBASE] JSON parse successful');

      final projectId = serviceAccount['project_id'] as String?;
      if (projectId == null) {
        throw FormatException('Missing project_id in service account JSON');
      }

      print('[FIREBASE] Server Time (UTC): ${DateTime.now().toUtc().toIso8601String()}');
      print('[FIREBASE] Service Account Keys: ${serviceAccount.keys.toList()}');

      // Sanitize the private key
      if (serviceAccount['private_key'] is String) {
        final rawKey = serviceAccount['private_key'] as String;
        print('[FIREBASE] Raw private_key field length: ${rawKey.length}');
        
        final key = _cleanPrivateKey(rawKey);
        print('[FIREBASE] Cleaned private_key length: ${key.length}');

        // Look for common truncation clues
        if (key.length < 1500) {
          print('⚠️ [FIREBASE] WARNING: Private key seems unusually short (${key.length} chars).');
        }

        // DIAGNOSTIC: Try to sign a test JWT to see if the key is valid
        try {
          final testJwt = JWT({'test': 'diag'});
          testJwt.sign(RSAPrivateKey(key), algorithm: JWTAlgorithm.RS256);
          print('✅ [FIREBASE] Diagnostic: Private key confirmed as a valid RSA PEM string.');
        } catch (e) {
          print('❌ [FIREBASE] Diagnostic: Private key is NOT a valid RSA string! Error: $e');
          print('   Hint: This usually means the key was truncated or corrupted during copy-paste.');
          print('   The PEM content (base64) length is: ${key.replaceAll(RegExp(r'---.*---|\s'), '').length}');
        }

        serviceAccount['private_key'] = key;
        
        // Log masked tags for confirmation
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
