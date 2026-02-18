import 'dart:io';
import 'package:dotenv/dotenv.dart';

final env = DotEnv();

/// Application environment configuration.
///
/// Reads values from environment variables with sensible defaults
/// for local development.
class Env {
  Env._();

  /// The port the server listens on.
  static int get port =>
      int.tryParse(env['PORT'] ?? '') ?? 8000;

  /// Secret used to sign and verify JWT tokens.
  static String get jwtSecret =>
      env['JWT_SECRET'] ?? 'secret123';

  /// Secret used to promote users to admin role.
  static String get adminSecret =>
      env['ADMIN_SECRET'] ?? 'admin-secret-123';

  /// Base64-encoded Firebase service account JSON.
  static String? get firebaseServiceAccountBase64 =>
      env['FIREBASE_SERVICE_ACCOUNT_BASE64'];

  /// PayHere merchant ID.
  static String get payhereMerchantId =>
      env['PAYHERE_MERCHANT_ID'] ?? '1228956';

  /// PayHere merchant secret.
  static String get payhereMerchantSecret =>
      env['PAYHERE_MERCHANT_SECRET'] ?? 'your_merchant_secret';

  /// PayHere notification URL.
  static String get payhereNotifyUrl =>
      env['PAYHERE_NOTIFY_URL'] ??
      'http://localhost:8000/api/payment/notify';

  /// Frontend URL for payment redirects.
  static String get frontendUrl =>
      env['FRONTEND_URL'] ?? 'http://localhost:5173';

  /// Uploads directory path.
  static String get uploadsPath =>
      env['UPLOADS_PATH'] ?? 'data/uploads';
}
