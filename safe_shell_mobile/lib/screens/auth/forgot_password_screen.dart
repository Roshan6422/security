import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step: 0 = verify identity, 1 = new password
  int _step = 0;
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _recoveryKeyController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _loading = false;
  String _error = '';
  String _success = '';
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  Timer? _debounce;
  bool _fetchingKey = false;

  @override
  void initState() {
    super.initState();
    _loadSavedInfo();
    _emailController.addListener(_onInputChanged);
    _nameController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (_step != 0) return;
    
    // Clear key if either field is cleared (optional but clean)
    if (_emailController.text.isEmpty || _nameController.text.isEmpty) {
      if (_recoveryKeyController.text.isNotEmpty) {
        setState(() => _recoveryKeyController.clear());
      }
      return;
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) _fetchKeyInBackground();
    });
  }

  Future<void> _fetchKeyInBackground() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();

    // Only fetch if both are reasonably present (avoid spamming)
    if (email.length < 5 || name.length < 2) return;
    if (_recoveryKeyController.text.isNotEmpty) return; // Already have a key

    setState(() => _fetchingKey = true);
    try {
      final res = await ApiService().post('/auth/get-recovery-key', {
        'email': email,
        'name': name,
      });
      if (mounted) {
        setState(() {
          _recoveryKeyController.text = res['recoveryKey'] ?? '';
          _fetchingKey = false;
          _error = ''; // Clear previous errors if this succeeds
        });
      }
    } catch (_) {
      // Background failure is silent to avoid annoying the user
      if (mounted) setState(() => _fetchingKey = false);
    }
  }

  Future<void> _loadSavedInfo() async {
    final email = await _storage.read(key: 'saved_email');
    final name = await _storage.read(key: 'saved_name');
    final recoveryKey = await _storage.read(key: 'saved_recovery_key');
    if (mounted) {
      setState(() {
        if (email != null) _emailController.text = email;
        if (name != null) _nameController.text = name;
        if (recoveryKey != null) _recoveryKeyController.text = recoveryKey;
      });
    }
  }

  Future<void> _verifyAndProceed() async {
    setState(() => _error = '');
    if (_emailController.text.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    if (_nameController.text.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    // Stage 1: Auto-fill Recovery Key if empty
    if (_recoveryKeyController.text.isEmpty) {
      setState(() => _loading = true);
      try {
        final res = await ApiService().post('/auth/get-recovery-key', {
          'email': _emailController.text.trim(),
          'name': _nameController.text.trim(),
        });
        if (mounted) {
          setState(() {
            _recoveryKeyController.text = res['recoveryKey'] ?? '';
            _loading = false;
          });
        }
        return;
      } catch (e) {
        setState(() {
          _error = 'Could not retrieve recovery key. Please check your info.';
          _loading = false;
        });
        return;
      }
    }

    // Stage 2: Verify and Proceed to New Password
    setState(() => _loading = true);
    try {
      await ApiService().post('/auth/verify-recovery-key', {
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'recoveryKey': _recoveryKeyController.text.trim(),
      });
      if (mounted) setState(() { _step = 1; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    setState(() => _error = '');
    if (_newPasswordController.text.isEmpty) {
      setState(() => _error = 'Please enter a new password');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiService().post('/auth/reset-password-via-key', {
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'recoveryKey': _recoveryKeyController.text.trim(),
        'newPassword': _newPasswordController.text,
      });
      setState(() { _success = 'Password reset successfully!'; _loading = false; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _recoveryKeyController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -50,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.15),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 120)],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.08), blurRadius: 120)],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 56),

                  // Header Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.primary.withOpacity(0.15),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.lock_reset, color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(height: 24),
                  Text('Forgot Password', style: AppTextStyles.display.copyWith(fontSize: 30)),
                  const SizedBox(height: 8),
                  Text(
                    _step == 0
                        ? 'Enter your Email, Name & Recovery Key'
                        : 'Create a new strong password for your vault',
                    style: AppTextStyles.body.copyWith(color: Colors.white.withOpacity(0.5), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Form Card
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        if (_step == 0) ...[
                          CustomTextField(
                            label: 'Email Address',
                            prefixIcon: Icons.email,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: 'Name (as registered)',
                            prefixIcon: Icons.person,
                            controller: _nameController,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: 'Recovery Key',
                            prefixIcon: Icons.vpn_key,
                            controller: _recoveryKeyController,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'e.g. SAFE-XXXX-XXXX (shown during registration)',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            text: _recoveryKeyController.text.isEmpty 
                                ? (_fetchingKey ? 'Checking...' : 'Check Identity') 
                                : 'Verify & Proceed',
                            isLoading: _loading,
                            onPressed: () => _verifyAndProceed(),
                          ),
                        ] else ...[
                          CustomTextField(
                            label: 'New Password',
                            prefixIcon: Icons.lock,
                            controller: _newPasswordController,
                            obscureText: _obscureNew,
                            onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: 'Confirm New Password',
                            prefixIcon: Icons.lock,
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            text: 'Reset Password',
                            isLoading: _loading,
                            onPressed: _resetPassword,
                          ),
                        ],

                        // Error
                        if (_error.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                              ],
                            ),
                          ),

                        // Success
                        if (_success.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_success, style: const TextStyle(color: Colors.greenAccent, fontSize: 12))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Back to Sign In
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chevron_left, color: Colors.white.withOpacity(0.4), size: 18),
                        const SizedBox(width: 4),
                        Text('Back to Sign In', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
