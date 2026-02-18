import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_text_field.dart';
import '../settings/privacy_policy_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        await Provider.of<AuthProvider>(context, listen: false).register(
          _nameController.text,
          _emailController.text,
          _passwordController.text,
        );
        if (mounted) {
          final user = Provider.of<AuthProvider>(context, listen: false).user;
          final userKey = user?.userKey ?? 'N/A';
          final recoveryKey = user?.recoveryKey ?? 'N/A';
          
          // Show user key dialog
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 36),
                  ),
                  const SizedBox(height: 12),
                  const Text('Account Created!', 
                    style: TextStyle(color: Colors.white, fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Save these keys securely!', 
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  const SizedBox(height: 20),
                  _keyDisplay('Your User Key', userKey, Icons.tag),
                  const SizedBox(height: 12),
                  _keyDisplay('Recovery Key', recoveryKey, Icons.vpn_key),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.amber.shade300, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('You need these to recover your account!',
                            style: TextStyle(color: Colors.amber.shade200, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('I saved my keys', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
          
          if (mounted) Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _keyDisplay(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied!'), duration: const Duration(seconds: 1)),
              );
            },
            child: Icon(Icons.copy, color: Colors.white.withOpacity(0.4), size: 18),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          image: DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1550751827-4bd374c3f58b'), // Same as Login
            fit: BoxFit.cover,
            opacity: 0.2,
          ),
        ),
        child: Stack(
          children: [
             // Gradient Blobs
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Create Account',
                      style: AppTextStyles.display.copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join SafeShell today.',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 48),
                    
                    GlassCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            CustomTextField(
                              controller: _nameController,
                              label: 'Name',
                              prefixIcon: Icons.person_outline,
                              validator: (value) =>
                                  value!.isEmpty ? 'Please enter name' : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _emailController,
                              label: 'Email',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) =>
                                  value!.isEmpty ? 'Please enter email' : null,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _passwordController,
                              label: 'Password',
                              prefixIcon: Icons.lock_outlined,
                              obscureText: _obscurePassword,
                              onToggleVisibility: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              validator: (value) =>
                                  value!.isEmpty ? 'Please enter password' : null,
                            ),
                            const SizedBox(height: 24),
                            Consumer<AuthProvider>(
                              builder: (context, auth, child) {
                                return PrimaryButton(
                                  text: 'Register',
                                  onPressed: _register,
                                  isLoading: auth.isLoading,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.body,
                          children: [
                            const TextSpan(text: "Already have an account? "),
                            TextSpan(
                              text: 'Login',
                              style: AppTextStyles.subheading.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Privacy Policy Link
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                      child: Text(
                        'Privacy Policy',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white54, 
                          decoration: TextDecoration.underline
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

