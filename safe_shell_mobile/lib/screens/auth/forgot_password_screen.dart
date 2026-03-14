import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step: 0 = Enter Email, 1 = Enter OTP, 2 = New Password
  int _step = 0;
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String _error = '';
  String _success = '';

  Future<void> _sendResetCode() async {
    setState(() => _error = '');
    final email = _emailController.text.trim();
    
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.sendResetOtp(email);
      
      if (mounted) {
        setState(() {
          _step = 1;
          _success = 'Reset code sent to your email!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _error = '');
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter a 6-digit code');
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.verifyOtp(_emailController.text.trim(), otp);
      
      if (mounted) {
        setState(() {
          _step = 2;
          _success = 'Code verified! Enter new password.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _resetPassword() async {
    setState(() => _error = '');
    final newPw = _newPasswordController.text;
    final confPw = _confirmPasswordController.text;

    if (newPw.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (newPw != confPw) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.resetPasswordCustom(
        _emailController.text.trim(),
        _otpController.text.trim(),
        newPw,
      );
      
      if (mounted) {
        setState(() => _success = 'Password reset successful!');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
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
                color: AppColors.primary.withOpacity(0.04),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 56),
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
                  Text('Reset Password', style: AppTextStyles.display.copyWith(fontSize: 30)),
                  const SizedBox(height: 8),
                  Text(
                    _step == 0
                        ? 'Enter your email to receive a reset code'
                        : _step == 1
                            ? 'Enter the 6-digit code sent to ${_emailController.text}'
                            : 'Create a new secure password',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        children: [
                          if (_step == 0) ...[
                            CustomTextField(
                              label: 'Email Address',
                              prefixIcon: Icons.email,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              text: 'Send Code',
                              isLoading: isLoading,
                              onPressed: _sendResetCode,
                            ),
                          ] else if (_step == 1) ...[
                            CustomTextField(
                              label: '6-Digit Code',
                              prefixIcon: Icons.pin,
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              text: 'Verify Code',
                              isLoading: isLoading,
                              onPressed: _verifyOtp,
                            ),
                            if (context.watch<AuthProvider>().lastOtp != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Recovery Code:',
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.watch<AuthProvider>().lastOtp!,
                                      style: AppTextStyles.display.copyWith(
                                        color: AppColors.primary,
                                        fontSize: 24,
                                        letterSpacing: 4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            TextButton(
                              onPressed: isLoading ? null : _sendResetCode,
                              child: const Text('Resend Code', style: TextStyle(color: AppColors.primary)),
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
                              label: 'Confirm Password',
                              prefixIcon: Icons.check_circle,
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              text: 'Finish Reset',
                              isLoading: isLoading,
                              onPressed: _resetPassword,
                            ),
                          ],

                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _message(Colors.redAccent, Icons.error_outline, _error),
                          ],
                          if (_success.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _message(Colors.greenAccent, Icons.check_circle, _success),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Back to Login', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(Color color, IconData icon, String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );
  }
}
