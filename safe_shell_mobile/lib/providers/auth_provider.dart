import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';

import '../core/constants.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  Future<void> checkAuth() async {
    try {
      final token = await _storage.read(key: AppConstants.keyToken);
      if (token != null) {
        try {
          final userData = await _apiService.get('/auth/me');
          _user = User.fromJson(userData);
          if (_user?.recoveryKey != null) {
            await _storage.write(key: 'saved_recovery_key', value: _user!.recoveryKey!);
          }
          await FCMService.initialize();
        } catch (e) {
          await logout();
        }
      }
    } catch (e) {
      // Handle error implicitly or log to a service
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      _user = User.fromJson(response);
      if (_user?.token != null) {
        await _storage.write(key: AppConstants.keyToken, value: _user!.token);
        // Save password for offline emergency unlock
        await _storage.write(key: 'saved_password', value: password);
        if (_user?.recoveryKey != null) {
          await _storage.write(key: 'saved_recovery_key', value: _user!.recoveryKey!);
        }
        await FCMService.initialize();
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/register', {
        'name': name,
        'email': email,
        'password': password,
      });

      _user = User.fromJson(response);
      if (_user?.token != null) {
        await _storage.write(key: AppConstants.keyToken, value: _user!.token);
        // Save password for offline emergency unlock
        await _storage.write(key: 'saved_password', value: password);
        // Save recovery info for forgot password auto-fill
        if (_user!.recoveryKey != null) {
          await _storage.write(key: 'saved_recovery_key', value: _user!.recoveryKey!);
        }
        await _storage.write(key: 'saved_email', value: email);
        await _storage.write(key: 'saved_name', value: name);
        await FCMService.initialize();
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google sign-in failed: missing idToken');
      }

      final response = await _apiService.post('/auth/google', {
        'idToken': idToken,
      });

      _user = User.fromJson(response);
      if (_user?.token != null) {
        await _storage.write(key: AppConstants.keyToken, value: _user!.token);
        await _storage.write(key: 'saved_email', value: _user!.email);
        await FCMService.initialize();
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    await _storage.delete(key: AppConstants.keyToken);
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}
    notifyListeners();
  }
}
