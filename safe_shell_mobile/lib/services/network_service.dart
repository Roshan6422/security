import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';

class NetworkService {
  static final http.Client _client = http.Client();
  static const Duration defaultTimeout = Duration(seconds: 60);
  static const Duration uploadTimeout = Duration(minutes: 15);
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  static http.Client get client => _client;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: AppConstants.keyToken);
    return {
      'Authorization': 'Bearer ${token ?? ""}',
      'Content-Type': 'application/json',
    };
  }

  static Future<http.Response> get(String url) async {
    final headers = await _getHeaders();
    return _retry(() => _client.get(Uri.parse(url), headers: headers));
  }

  static Future<http.Response> post(String url, dynamic body) async {
    final headers = await _getHeaders();
    return _retry(() => _client.post(
      Uri.parse(url), 
      headers: headers, 
      body: body is Map ? jsonEncode(body) : body,
    ));
  }

  static Future<http.Response> put(String url, dynamic body) async {
    final headers = await _getHeaders();
    return _retry(() => _client.put(
      Uri.parse(url), 
      headers: headers, 
      body: body is Map ? jsonEncode(body) : body,
    ));
  }

  static Future<http.Response> delete(String url) async {
    final headers = await _getHeaders();
    return _retry(() => _client.delete(Uri.parse(url), headers: headers));
  }

  static Future<http.Response> _retry(Future<http.Response> Function() fn, {int maxRetries = 2}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final response = await fn().timeout(defaultTimeout);
        return response;
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
    throw Exception('Request failed after $maxRetries retries');
  }

  static void dispose() {
    _client.close();
  }
}
