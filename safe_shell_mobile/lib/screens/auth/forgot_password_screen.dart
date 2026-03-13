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
  // Step: 0 = Enter Email, 1 = Enter OTP & New Password
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
      await authProvider.forgotPassword(email);
      
      if (mounted) {
        setState(() {
          _step = 1;
          _success = 'Reset code sent to your email!';
          _error = '';
        });
        
        // Clear success message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _success = '');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to send reset code. Please check your internet connection.';
        });
      }
    }
  }

  // _resetPassword removed - Firebase handles reset via email link.

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
                color: AppColors.primary.withValues(alpha: 0.04),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.02), blurRadius: 150)],
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
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.03),
                boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.02), blurRadius: 180)],
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
                      color: AppColors.primary.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.lock_reset, color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(height: 24),
                  Text('Forgot Password', style: AppTextStyles.display.copyWith(fontSize: 30)),
                  const SizedBox(height: 8),
                  Text(
                    _step == 0
                        ? 'Enter your email to receive a reset code'
                        : 'Enter the 6-digit code and your new password',
                    style: AppTextStyles.body.copyWith(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
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
                          const SizedBox(height: 24),
                          PrimaryButton(
                            text: 'Send Reset Link',
                            isLoading: isLoading,
                            onPressed: _sendResetCode,
                          ),
                        ] else ...[
                          const Icon(Icons.mark_email_read_rounded, color: Colors.greenAccent, size: 64),
                          const SizedBox(height: 24),
                          const Text(
                            'Check Your Inbox',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We have sent a secure password reset link to ${_emailController.text}. Please follow the instructions in the email.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
                          ),
                          const SizedBox(height: 32),
                          PrimaryButton(
                            text: 'Back to Login',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],

                        // Error
                        if (_error.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
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
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
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
                    onTap: () {
                      if (_step == 1) {
                        setState(() {
                          _step = 0;
                          _error = '';
                          _success = '';
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chevron_left, color: Colors.white.withValues(alpha: 0.4), size: 18),
                        const SizedBox(width: 4),
                        Text('Back to Sign In', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14, fontWeight: FontWeight.w500)),
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
