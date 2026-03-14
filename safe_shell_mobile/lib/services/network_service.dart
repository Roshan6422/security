import 'package:http/http.dart' as http;

/// A singleton service to manage network connections.
/// 
/// By using a single [http.Client] instance, we enable connection pooling,
/// which significantly reduces latency by reusing TCP connections and 
/// avoiding repetitive SSL/TLS handshakes for multiple requests.
class NetworkService {
  static final http.Client _client = http.Client();
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);

  /// The global shared [http.Client] instance.
  static http.Client get client => _client;

  /// Closes the client and frees up resources.
  /// This should generally not be called while the app is running.
  static void dispose() {
    _client.close();
  }
}
