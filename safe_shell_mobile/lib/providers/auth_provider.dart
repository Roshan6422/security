import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../services/fcm_service.dart';

import '../core/constants.dart';
import '../services/network_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _profileCacheKey = 'cached_user_profile';

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  Future<void> checkAuth() async {
    try {
      final token = await _storage.read(key: AppConstants.keyToken);
      final currentUser = _firebaseAuth.currentUser;
      
      if (token != null && currentUser != null) {
        // Turbo: Load from cache first for instant startup
        final cachedProfile = await _storage.read(key: _profileCacheKey);
        if (cachedProfile != null) {
          final data = jsonDecode(cachedProfile);
          data['token'] = token;
          _user = User.fromJson(data);
          notifyListeners();
        }

        try {
          final doc = await _firestore.collection('users').doc(currentUser.uid).get();
          if (doc.exists) {
            final data = doc.data()!;
            data['_id'] = currentUser.uid;
            data['token'] = token;
            _user = User.fromJson(data);
            
            if (_user!.isSuspended) {
              await logout();
              return;
            }

            // Update cache
            await _storage.write(key: _profileCacheKey, value: jsonEncode(_user!.toJson()));
            
            if (_user?.recoveryKey != null) {
              await _storage.write(key: 'saved_recovery_key', value: _user!.recoveryKey!);
            }
            FCMService.initialize();
          } else {
            // User exists in Firebase but not in Firestore. Possible sync delay or deleted on server.
            // Don't log out immediately if we have a token; keep trying or let it stay on "profile loading"
            if (kDebugMode) debugPrint('AuthProvider: Firestore doc not found for ${currentUser.uid}');
          }
        } catch (e) {
          // Firestore fetch failed (e.g. timeout/network). 
          // Don't log out if we already have the user from cache or Firebase.
          if (kDebugMode) debugPrint('AuthProvider: Firestore refresh error: $e');
        }
      } else {
         // DEFINITIVELY unauthenticated: missing either token or Firebase user
         if (token != null || _user != null) await logout();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AuthProvider: Grand checkAuth error: $e');
    }
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      try {
        final doc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          data['_id'] = currentUser.uid;
          
          // CRITICAL: Preserve the JWT token which is NOT in Firestore
          final existingToken = _user?.token ?? await _storage.read(key: AppConstants.keyToken);
          data['token'] = existingToken;

          // CRITICAL: Preserve userKey if it was recently set locally but Firestore cache hasn't updated
          if (_user?.userKey != null && data['userKey'] == null) {
            data['userKey'] = _user!.userKey;
          }

          _user = User.fromJson(data);
          
          if (_user!.isSuspended) {
             await logout();
             return;
          }

          await _storage.write(key: _profileCacheKey, value: jsonEncode(_user!.toJson()));
          notifyListeners();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AuthProvider: refreshUser error: $e');
      }
    }
  }

  Future<void> setUserKeyFlag() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      try {
        final token = _user?.token ?? await _storage.read(key: AppConstants.keyToken);
        if (token == null) throw Exception('No auth token available');
        
        final response = await NetworkService.client.post(
          Uri.parse('${AppConstants.baseUrl}/auth/set-key-flag'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token', 
          },
        ).timeout(NetworkService.defaultTimeout);

        if (response.statusCode == 200) {
          // If successful, update locally first to prevent UI flickering/redirection traps
          if (_user != null) {
            _user!.userKey = 'secured_managed'; // any non-null string
            await _storage.write(key: _profileCacheKey, value: jsonEncode(_user!.toJson()));
            notifyListeners();
          }
          // Do not call refreshUser() here as it causes a race condition with Firestore cache
        } else {
          debugPrint('Failed to set key flag on backend: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error setting key flag: $e');
      }
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final cred = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final idToken = await cred.user?.getIdToken();
      if (idToken == null) throw Exception('Failed to get auth token');

      final url = Uri.parse('${AppConstants.baseUrl}/auth/firebase-login');
      debugPrint('AuthProvider: Syncing with Backend: $url');
      debugPrint('AuthProvider: Body: ${jsonEncode({'idToken': idToken})}');

      final response = await NetworkService.client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      ).timeout(NetworkService.defaultTimeout);

      debugPrint('AuthProvider: Backend Response Status: ${response.statusCode}');
      debugPrint('AuthProvider: Backend Response Body: ${response.body}');

      if (response.statusCode != 200) {
        // If not found in backend but exists in Firebase, try auto-registering in backend
        if (response.statusCode == 404) {
           await _syncNewUserToBackend(cred.user!, idToken);
        } else {
           throw Exception('Backend sync failed: ${response.body}');
        }
      } else {
        final userData = jsonDecode(response.body);
        await _handleLoginResponse(userData, password);
      }
      
    } on auth.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Authentication failed');
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncNewUserToBackend(auth.User user, String idToken) async {
     final response = await NetworkService.client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/firebase-register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'name': user.displayName ?? 'User',
        }),
      ).timeout(NetworkService.defaultTimeout);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        await _handleLoginResponse(userData, 'social_or_sync');
      } else {
        throw Exception('Failed to sync user to backend: ${response.body}');
      }
  }

  Future<void> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();
    auth.UserCredential? cred;
    try {
      cred = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final idToken = await cred.user?.getIdToken();
      if (idToken == null) throw Exception('Failed to get auth token');

      // The backend will handle creating the user profile document in Firestore.
      // We only sync with Koyeb Backend here.
      final url = Uri.parse('${AppConstants.baseUrl}/auth/firebase-register');
      debugPrint('AuthProvider: Registering with Backend: $url');
      debugPrint('AuthProvider: Body: ${jsonEncode({'idToken': idToken, 'name': name})}');

      final response = await NetworkService.client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'name': name,
        }),
      ).timeout(NetworkService.defaultTimeout);

      debugPrint('AuthProvider: Register Backend Response Status: ${response.statusCode}');
      debugPrint('AuthProvider: Register Backend Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        await _handleLoginResponse(userData, password);
      } else {
        throw Exception('Backend registration failed: ${response.statusCode}');
      }

    } on auth.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Registration failed');
    } catch (e) {
      // Rollback: if backend sync fails, delete the Firebase auth user so they aren't stuck
      if (cred != null && cred.user != null) {
        try {
          await cred.user!.delete();
        } catch (_) {
          // Ignore rollback errors
        }
      }
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
      final auth.OAuthCredential credential = auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final auth.UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) throw Exception('Google sign-in failed to get token');

      // Sync with Koyeb Backend: firebase-login handles auto-registration (JIT provisioning)
      final response = await NetworkService.client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/firebase-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      ).timeout(NetworkService.defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final userData = jsonDecode(response.body);
        await _handleLoginResponse(userData, 'google_sso');
      } else {
        throw Exception('Backend Google sync failed');
      }

    } catch (e) {
      // Rollback if any part of the Google sign-in fails after Firebase auth
      if (_firebaseAuth.currentUser != null) {
        try {
          await _firebaseAuth.currentUser!.delete();
        } catch (_) {}
      }
      throw Exception('Google Sign-In failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Extracts email and name from Google without signing into Firebase.
  /// Used for auto-filling the registration/login form.
  Future<Map<String, String>?> getGoogleAccountDetails() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        // Sign out immediately so we don't hold the session, we just wanted the data
        await _googleSignIn.signOut();
        return {
          'email': googleUser.email,
          'name': googleUser.displayName ?? '',
          'id': googleUser.id,
        };
      }
    } catch (e) {
      print('Google account picker failed: $e');
    }
    return null;
  }

  /// Generates a deterministic password based on email and googleId.
  /// This ensures that the same Google account always results in the same password.
  String generateDeterministicPassword(String email, String googleId) {
    final bytes = utf8.encode('$email:$googleId:SafeShellSalt2024');
    final hash = sha256.convert(bytes).toString();
    // Complex password: S@fe + 10 chars hash + ! + digit
    return 'G@${hash.substring(0, 10).toUpperCase()}1z!';
  }

  String? _lastOtp;
  String? get lastOtp => _lastOtp;

  Future<void> sendResetOtp(String email) async {
    _isLoading = true;
    _lastOtp = null;
    notifyListeners();
    try {
      final response = await NetworkService.client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(NetworkService.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _lastOtp = data['otp']?.toString();
      } else {
        final message = jsonDecode(response.body)['message'] ?? 'Failed to send OTP';
        throw Exception(message);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyOtp(String email, String otp) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await NetworkService.client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      ).timeout(NetworkService.defaultTimeout);

      if (response.statusCode != 200) {
        final message = jsonDecode(response.body)['message'] ?? 'Invalid OTP';
        throw Exception(message);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPasswordCustom(String email, String otp, String newPassword) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await NetworkService.client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'password': newPassword,
        }),
      ).timeout(NetworkService.defaultTimeout);

      if (response.statusCode != 200) {
        final message = jsonDecode(response.body)['message'] ?? 'Reset failed';
        throw Exception(message);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    throw UnimplementedError('Reset password is now handled by Firebase reset link');
  }

  Future<void> logout() async {
    _user = null;
    await _storage.delete(key: AppConstants.keyToken);
    try {
      await _firebaseAuth.signOut();
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _handleLoginResponse(Map<String, dynamic> userData, String password) async {
    final token = userData['token'];
    
    // The backend returns a flat JSON with user fields and 'token'
    // We pass the whole map to User.fromJson, which will pick relevant fields
    if (token == null) {
      throw Exception('Invalid server response: Missing token');
    }
    
    _user = User.fromJson(userData);
    
    if (_user!.isSuspended) {
      _user = null;
      await _firebaseAuth.signOut();
      throw Exception('Your account has been suspended by an administrator.');
    }

    await _storage.write(key: AppConstants.keyToken, value: token);
    
    // Cache profile for offline/turbo startup
    await _storage.write(key: _profileCacheKey, value: jsonEncode(_user!.toJson()));
    
    notifyListeners();
  }

  Future<void> updateProfileData({String? name, String? email, String? photoUrl}) async {
    if (_user == null) return;
    
    _user = User(
      id: _user!.id,
      name: name ?? _user!.name,
      email: email ?? _user!.email,
      role: _user!.role,
      token: _user!.token,
      recoveryKey: _user!.recoveryKey,
      userKey: _user!.userKey,
      subscriptionStatus: _user!.subscriptionStatus,
      subscriptionExpiry: _user!.subscriptionExpiry,
      photoUrl: photoUrl ?? _user!.photoUrl,
    );
    
    // Cache profile for offline/turbo startup
    await _storage.write(key: _profileCacheKey, value: jsonEncode(_user!.toJson()));
    notifyListeners();
  }
}
