import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
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
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

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
      // 1. Try Firebase Login
      try {
        final cred = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final idToken = await cred.user?.getIdToken();
        if (idToken == null) throw Exception('Failed to get auth token');

        final response = await _apiService.post('/auth/firebase-login', {'idToken': idToken});
        await _handleLoginResponse(response, password);
        return;
      } on FirebaseAuthException catch (e) {
        // If user doesn't exist in Firebase, try legacy migration
        if (e.code == 'user-not-found') {
          final response = await _apiService.post('/auth/login', {
            'email': email,
            'password': password,
          });
          
          // Successful legacy login! Now migrate to Firebase
          final cred = await _firebaseAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          final idToken = await cred.user?.getIdToken();
          
          // Inform backend that this user is now Firebase-enabled
          final fbResponse = await _apiService.post('/auth/firebase-login', {'idToken': idToken});
          await _handleLoginResponse(fbResponse, password);
          return;
        }
        rethrow;
      }
    } catch (e) {
      // Local fallback for truly offline mode
      final savedEmail = await _storage.read(key: 'saved_email') ?? await _storage.read(key: 'bio_email');
      final savedPassword = await _storage.read(key: 'saved_password') ?? await _storage.read(key: 'bio_password');
      final token = await _storage.read(key: AppConstants.keyToken);

      if (savedEmail == email && savedPassword == password && token != null) {
          _user = User(id: 'offline_mode', email: email, name: 'SafeShell User', role: 'user', subscriptionStatus: 'free', token: token);
      } else {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _handleLoginResponse(dynamic response, String password) async {
    _user = User.fromJson(response);
    if (_user?.token != null) {
      await _storage.write(key: AppConstants.keyToken, value: _user!.token);
      await _storage.write(key: 'saved_password', value: password);
      await _storage.write(key: 'saved_email', value: _user!.email);
      if (_user?.recoveryKey != null) {
        await _storage.write(key: 'saved_recovery_key', value: _user!.recoveryKey!);
      }
      await FCMService.initialize();
    }
  }

  Future<void> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Create in Firebase
      final cred = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final idToken = await cred.user?.getIdToken();
      
      // 2. Register in Backend
      final response = await _apiService.post('/auth/firebase-register', {
        'idToken': idToken,
        'name': name,
      });

      _user = User.fromJson(response);
      if (_user?.token != null) {
        await _storage.write(key: AppConstants.keyToken, value: _user!.token);
        await _storage.write(key: 'saved_password', value: password);
        await _storage.write(key: 'saved_email', value: email);
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

  Future<void> forgotPassword(String email) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    // This is now handled entirely by Firebase's reset email link.
    // We keep the method for interface compatibility but it's no longer used in the new flow.
    throw UnimplementedError('Reset password is now handled by Firebase reset link');
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
