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
  double _passwordStrength = 0.0;
  String _strengthLabel = '';
  Color _strengthColor = Colors.transparent;



  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_calculateStrength);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_calculateStrength);
    super.dispose();
  }

  void _calculateStrength() {
    final pw = _passwordController.text;
    double strength = 0.0;
    if (pw.length >= 4) strength += 0.15;
    if (pw.length >= 8) strength += 0.2;
    if (pw.length >= 12) strength += 0.15;
    if (pw.contains(RegExp(r'[A-Z]'))) strength += 0.15;
    if (pw.contains(RegExp(r'[0-9]'))) strength += 0.15;
    if (pw.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2;

    String label;
    Color color;
    if (strength <= 0.25) { label = 'Weak'; color = const Color(0xFFEF4444); }
    else if (strength <= 0.5) { label = 'Fair'; color = const Color(0xFFF59E0B); }
    else if (strength <= 0.75) { label = 'Good'; color = const Color(0xFF4DA3FF); }
    else { label = 'Strong ??'; color = const Color(0xFF10B981); }

    setState(() {
      _passwordStrength = strength.clamp(0.0, 1.0);
      _strengthLabel = pw.isEmpty ? '' : label;
      _strengthColor = color;
    });
  }



  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      try {
        await Provider.of<AuthProvider>(context, listen: false).register(
          _nameController.text,
          _emailController.text,
          _passwordController.text,
        );
        if (mounted) {
          HapticFeedback.heavyImpact();
          final user = Provider.of<AuthProvider>(context, listen: false).user;
          final userKey = user?.userKey ?? 'N/A';
          final recoveryKey = user?.recoveryKey ?? 'N/A';
          
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF0D1520),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Column(
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [const Color(0xFF10B981).withOpacity(0.2), const Color(0xFF10B981).withOpacity(0.05)]),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 36),
                  ),
                  const SizedBox(height: 12),
                  const Text('Account Created! ??', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Save these keys securely!', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                  const SizedBox(height: 20),
                  _keyDisplay('Your User Key', userKey, Icons.tag_rounded),
                  const SizedBox(height: 12),
                  _keyDisplay('Recovery Key', recoveryKey, Icons.vpn_key_rounded),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('You need these to recover your account!', style: TextStyle(color: const Color(0xFFF59E0B).withOpacity(0.7), fontSize: 12))),
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
                      backgroundColor: const Color(0xFF4DA3FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(ctx); },
                    child: const Text('I saved my keys', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
          
          if (mounted) Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Widget _keyDisplay(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4DA3FF), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('?? $label copied!'), duration: const Duration(seconds: 1), backgroundColor: const Color(0xFF4DA3FF)),
              );
            },
            child: Icon(Icons.copy_rounded, color: Colors.white.withOpacity(0.3), size: 18),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            bottom: -120,
            left: -120,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFF4DA3FF).withOpacity(0.04), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFF8B5CF6).withOpacity(0.03), Colors.transparent]),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text('Create Account', style: AppTextStyles.display.copyWith(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Text('Join SafeShell today.', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: const Color(0xFF0D1520),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _nameController,
                            label: 'Name',
                            prefixIcon: Icons.person_outline,
                            validator: (value) => value!.isEmpty ? 'Please enter name' : null,
                          ),
                          const SizedBox(height: 14),
                          CustomTextField(
                            controller: _emailController,
                            label: 'Email',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) => value!.isEmpty ? 'Please enter email' : null,
                          ),
                          const SizedBox(height: 14),
                          CustomTextField(
                            controller: _passwordController,
                            label: 'Password',
                            prefixIcon: Icons.lock_outlined,
                            obscureText: _obscurePassword,
                            onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                            validator: (value) => value!.isEmpty ? 'Please enter password' : null,
                          ),
                          // Password Strength Meter
                          if (_passwordController.text.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Password Strength', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                                    Text(_strengthLabel, style: TextStyle(color: _strengthColor, fontSize: 11, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SizedBox(
                                    height: 5,
                                    child: Stack(
                                      children: [
                                        Container(color: Colors.white.withOpacity(0.05)),
                                        FractionallySizedBox(
                                          widthFactor: _passwordStrength,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(colors: [_strengthColor.withOpacity(0.6), _strengthColor]),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                  Column(
                    children: [
                      TextButton(
                        onPressed: () { HapticFeedback.selectionClick(); Navigator.of(context).pop(); },
                        child: RichText(
                          text: TextSpan(
                            style: AppTextStyles.body,
                            children: [
                              TextSpan(text: "Already have an account? ", style: TextStyle(color: Colors.white.withOpacity(0.4))),
                              TextSpan(text: 'Login', style: TextStyle(color: const Color(0xFF4DA3FF), fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                        child: Text('Privacy Policy', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12, decoration: TextDecoration.underline)),
                      ),
                    ],
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
