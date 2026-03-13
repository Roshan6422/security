import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();
  static String _baseUrl = AppConstants.baseUrl;
  static bool _baseUrlLoaded = false;

  static Future<void> _ensureBaseUrlLoaded() async {
    if (_baseUrlLoaded) return;
    // Temporarily disabled to force AppConstants.baseUrl
    /*
    const storage = FlutterSecureStorage();
    final savedUrl = await storage.read(key: 'custom_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    }
    */
    _baseUrlLoaded = true;
  }

  static Future<void> setBaseUrl(String url) async {
    if (url.isNotEmpty) {
      String formattedUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      if (!formattedUrl.endsWith('/api')) {
        formattedUrl = '$formattedUrl/api';
      }
      _baseUrl = formattedUrl;
      const storage = FlutterSecureStorage();
      await storage.write(key: 'custom_base_url', value: _baseUrl);
      _baseUrlLoaded = true;
    }
  }

  static String get currentBaseUrl => _baseUrl;

  static Future<String> getBaseUrl() async {
    await _ensureBaseUrlLoaded();
    return _baseUrl;
  }

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

  Uri _buildUrl(String endpoint) {
    String cleanBase = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    String cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    
    // ENSURE trailing slash for root-level service routes (e.g., /vault? -> /vault/?)
    // This resolves shelf_router prefix matching issues.
    if (cleanEndpoint.contains('?')) {
        final pathPart = cleanEndpoint.split('?')[0];
        if (!pathPart.contains('/', 1)) { // e.g., /vault 
             cleanEndpoint = cleanEndpoint.replaceFirst(pathPart, '$pathPart/');
        }
    } else if (!cleanEndpoint.contains('/', 1)) {
         // e.g., /vault -> /vault/
         cleanEndpoint = '$cleanEndpoint/';
    }

    final fullUrl = '$cleanBase$cleanEndpoint'.replaceAll(RegExp(r'\s+'), '');
    if (kDebugMode) {
      debugPrint('ApiService DEBUG: BASE="$_baseUrl" END="$endpoint"');
      debugPrint('ApiService FINAL: [$fullUrl]');
      debugPrint('ApiService CODES: ${fullUrl.runes.toList()}');
    }
    return Uri.parse(fullUrl);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    await _ensureBaseUrlLoaded();
    final url = _buildUrl(endpoint);
    final headers = await _getHeaders();

    if (kDebugMode) debugPrint('ApiService POST: [$url]');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> get(String endpoint) async {
    await _ensureBaseUrlLoaded();
    final url = _buildUrl(endpoint);
    final headers = await _getHeaders();
    
    try {
      if (kDebugMode) {
        final token = headers['Authorization']?.substring(0, 15);
        debugPrint('ApiService GET: [$url] (Token: $token...)');
      }
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
    await _ensureBaseUrlLoaded();
    final url = _buildUrl(endpoint);
    final headers = await _getHeaders();

    if (kDebugMode) debugPrint('ApiService PUT: [$url]');
    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    await _ensureBaseUrlLoaded();
    final url = _buildUrl(endpoint);
    final headers = await _getHeaders();

    if (kDebugMode) debugPrint('ApiService DELETE: [$url]');
    final response = await http.delete(url, headers: headers);

    return _handleResponse(response);
  }

  /// Max upload file size: 50MB
  static const int _maxUploadBytes = 50 * 1024 * 1024;

  Future<dynamic> uploadMultipart(String endpoint, String filePath) async {
    await _ensureBaseUrlLoaded();

    // Check file size before uploading
    final file = await File(filePath).stat();
    if (file.size > _maxUploadBytes) {
      final sizeMB = (file.size / (1024 * 1024)).toStringAsFixed(1);
      throw Exception('File too large ($sizeMB MB). Maximum upload size is 50 MB.');
    }

    final url = _buildUrl(endpoint);
    final request = http.MultipartRequest('POST', url);
    final token = await _storage.read(key: AppConstants.keyToken);
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (kDebugMode) debugPrint('ApiService UPLOAD: [$url]');
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
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw Exception('Server returned invalid data format: ${response.statusCode}');
      }
    } else {
      if (kDebugMode) {
        debugPrint('ApiService ERROR: ${response.statusCode}');
        debugPrint('ApiService HEADERS: ${response.headers}');
        debugPrint('ApiService BODY: ${response.body}');
      }
      try {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Something went wrong: ${response.statusCode}');
      } catch (e) {
        // Include the body in the exception so it shows up in the Dashboard error log
        throw Exception('Server error: ${response.statusCode}. Body: ${response.body}');
      }
    }
  }
}
