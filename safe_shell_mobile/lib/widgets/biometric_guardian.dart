import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:safe_shell_mobile/core/theme.dart';

class BiometricGuardian extends StatefulWidget {
  final Widget child;

  const BiometricGuardian({super.key, required this.child});

  @override
  State<BiometricGuardian> createState() => _BiometricGuardianState();
}

class _BiometricGuardianState extends State<BiometricGuardian> with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isLocked = false;
  
  // We don't cache _isEnabled permanently because it might change in Settings
  // We check it on resume.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _isAuthenticating = false;
  DateTime? _lastAuthTime;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Prevent double-triggering from lifecycle resumed event when native prompt closes
      if (_isAuthenticating) return;
      if (_lastAuthTime != null && DateTime.now().difference(_lastAuthTime!).inSeconds < 2) {
        return; // Skip lock if we just returned from an auth prompt
      }
      _checkAndAuthenticate();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        // App goes to background or native overlay shows (like system biometric prompt)
    }
  }

  Future<void> _checkAndAuthenticate() async {
    // Read fresh value every time we resume
    String? value = await _storage.read(key: 'biometric_enabled');
    bool isEnabled = value == 'true';

    if (isEnabled && !_isLocked) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return; 

    // 1. Check if device supports biometrics at all
    final bool isSupported = await _auth.isDeviceSupported();
    final bool canCheck = await _auth.canCheckBiometrics;
    
    if (!isSupported || !canCheck) {
      if (mounted) {
        setState(() => _isLocked = true); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric hardware not available or not setup.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLocked = true; // Show lock screen
        _isAuthenticating = true;
      });
    }

    try {
      bool authenticated = await _auth.authenticate(
        localizedReason: 'Unlock SafeShell (Face Lock or PIN)',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allows PIN fallback if biometrics fail
          useErrorDialogs: true,
          sensitiveTransaction: false, // Better for Face ID on some devices
        ),
      );

      _lastAuthTime = DateTime.now();

      // We use a local delay check if needed, but immediately clearing flags works best
      if (mounted) {
        setState(() {
          _isAuthenticating = false; // MUST clear this first before lock logic
          if (authenticated) {
            _isLocked = false;
          } else {
            _isLocked = true;
          }
        });
      }
    } on PlatformException catch (e) {
       _lastAuthTime = DateTime.now();
       debugPrint('Biometric Error: $e');
       if (mounted) {
         setState(() {
           _isAuthenticating = false;
         });

         String errorMsg = 'Verification fail. Try again.';
         if (e.code == 'NotEnrolled') {
           errorMsg = 'No Face Lock/PIN enrolled on this device.';
         } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
           errorMsg = 'Too many attempts. Locked out.';
         } else if (e.code == 'NotAvailable') {
           errorMsg = 'Face Lock sensor not available.';
         }

         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(errorMsg),
             action: SnackBarAction(label: 'Enter Password', onPressed: _showEmergencyUnlock),
           ),
         );
       }
    }
  }

  Future<void> _showEmergencyUnlock() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Emergency Unlock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your Account Password to bypass biometric lock.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Password...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final input = controller.text.trim();
              final saved = await _storage.read(key: 'saved_password');
              if (input == (saved ?? "").trim()) {
                if (ctx.mounted) Navigator.pop(ctx, true);
              } else {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Invalid password')));
              }
            },
            child: const Text('Unlock', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _isLocked = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isLocked)
          Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_person, size: 64, color: AppColors.primary),
                  ),
                  const SizedBox(height: 24),
                  Text('Vault Locked', style: AppTextStyles.display),
                  const SizedBox(height: 12),
                  Text(
                    'Use Face Lock to unlock',
                    style: AppTextStyles.body.copyWith(color: Colors.white54),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _isAuthenticating ? null : _authenticate,
                    icon: const Icon(Icons.security, color: Colors.white),
                    label: Text(_isAuthenticating ? 'Verifying...' : 'Unlock Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _showEmergencyUnlock,
                    icon: const Icon(Icons.password, size: 18, color: Colors.white38),
                    label: Text(
                      'Unlock with Account Password',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
