import 'dart:io';
import 'package:dotenv/dotenv.dart';

final env = DotEnv();

/// Application environment configuration.
///
/// Reads values from environment variables with sensible defaults
/// for local development.
class Env {
  Env._();

  static String? _get(String key) {
    // 1. Try system environment (Koyeb/Runtime)
    if (Platform.environment.containsKey(key)) {
      return Platform.environment[key];
    }
    // 2. Try .env file (Local development)
    if (env.isDefined(key)) {
      return env[key];
    }
    return null;
  }

  /// The port the server listens on.
  static int get port =>
      int.tryParse(_get('PORT') ?? '') ?? 8000;

  /// Secret used to sign and verify JWT tokens.
  static String get jwtSecret =>
      _get('JWT_SECRET') ?? 'secret123';

  /// Secret used to promote users to admin role.
  static String get adminSecret =>
      _get('ADMIN_SECRET') ?? 'admin-secret-123';

  /// Base64-encoded Firebase service account JSON.
  static String? get firebaseServiceAccountBase64 =>
      _get('FIREBASE_SERVICE_ACCOUNT_BASE64');

  /// PayHere merchant ID.
  static String get payhereMerchantId =>
      _get('PAYHERE_MERCHANT_ID') ?? '1228956';

  /// PayHere merchant secret.
  static String get payhereMerchantSecret =>
      _get('PAYHERE_MERCHANT_SECRET') ?? 'your_merchant_secret';

  /// PayHere notification URL.
  static String get payhereNotifyUrl =>
      _get('PAYHERE_NOTIFY_URL') ??
      'http://localhost:8000/api/payment/notify';

  /// Frontend URL for payment redirects.
  static String get frontendUrl =>
      _get('FRONTEND_URL') ?? 'http://localhost:5173';

  /// Uploads directory path.
  static String get uploadsPath =>
      _get('UPLOADS_PATH') ?? 'data/uploads';

  /// Storage mode: 'firebase' (default) or 'local'
  static String get storageMode =>
      _get('STORAGE_MODE') ?? 'firebase';

  /// Base URL for the backend (used for local storage links)
  static String? get storageBaseUrl =>
      _get('STORAGE_BASE_URL');

  /// Optional: Custom Firebase Storage bucket (overrides default project-id based naming)
  static String? get firebaseStorageBucket =>
      _get('FIREBASE_STORAGE_BUCKET');
}
