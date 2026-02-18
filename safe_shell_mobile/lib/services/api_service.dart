import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();
  static String _baseUrl = AppConstants.baseUrl;

  static void setBaseUrl(String url) {
    if (url.isNotEmpty) {
      _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      // Ensure /api suffix if missing, or user provides full path
      if (!_baseUrl.endsWith('/api')) {
        _baseUrl = '$_baseUrl/api';
      }
    }
  }

  static String get currentBaseUrl => _baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: AppConstants.keyToken);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<String?> getToken() async {
    return await const FlutterSecureStorage().read(key: AppConstants.keyToken);
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final headers = await _getHeaders();

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final headers = await _getHeaders();
    
    try {
      if (kDebugMode) debugPrint('ApiService: GET request to $url');
      final response = await http.get(url, headers: headers).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (kDebugMode) debugPrint('ApiService: Timeout connecting to $url');
          throw Exception('Connection timed out. Check your internet or server IP.');
        },
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) debugPrint('ApiService: Error connecting to $url: $e');
      rethrow;
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final headers = await _getHeaders();

    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final headers = await _getHeaders();

    final response = await http.delete(url, headers: headers);

    return _handleResponse(response);
  }

  Future<dynamic> uploadMultipart(String endpoint, String filePath) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final request = http.MultipartRequest('POST', url);
    final token = await _storage.read(key: AppConstants.keyToken);
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) debugPrint('ApiService: Upload error: $e');
      rethrow;
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Something went wrong');
    }
  }
}
