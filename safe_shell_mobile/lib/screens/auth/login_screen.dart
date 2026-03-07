import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:safe_shell_mobile/utils/sound_effects.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';
import 'package:flutter/services.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/custom_text_field.dart';
import '../main_shell.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../settings/privacy_policy_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _testingConnection = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final biometricEnabled = await _storage.read(key: 'biometric_enabled');
      
      setState(() {
        _canCheckBiometrics = isDeviceSupported && canCheck && biometricEnabled == 'true';
      });
    } catch (_) {}
  }

  Future<void> _authenticate() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access SafeShell Vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          sensitiveTransaction: false, // Set to false to allow Face Unlock (often Class 2/Weak)
          useErrorDialogs: true,
        ),
      );

      if (authenticated && mounted) {
        final email = await _storage.read(key: 'bio_email');
        final password = await _storage.read(key: 'bio_password');

        if (email != null && password != null) {
          _emailController.text = email;
          _passwordController.text = password;
          _login(isBiometric: true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No credentials saved. Please login manually first to enable biometrics.')),
          );
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      String message = 'Authentication error';
      if (e.code == 'LockedOut') {
        message = 'Too many attempts. Biometrics locked temporarily.';
      } else if (e.code == 'PermanentlyLockedOut') {
        message = 'Biometrics locked. Use PIN/Password to unlock.';
      } else if (e.code == 'NotEnrolled') {
        message = 'No biometrics enrolled on this device.';
      } else if (e.code == 'PasscodeNotSet') {
        message = 'Device PIN/Pattern not set.';
      } else {
        message = 'Biometric Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _login({bool isBiometric = false}) async {
    if (_formKey.currentState!.validate()) {
      try {
        await Provider.of<AuthProvider>(context, listen: false).login(
          _emailController.text,
          _passwordController.text,
        );
        
        // Save credentials for biometrics if successful and not already using biometrics (or update them)
        if (!isBiometric) {
           await _storage.write(key: 'bio_email', value: _emailController.text);
           await _storage.write(key: 'bio_password', value: _passwordController.text);
        }

        if (mounted) {
          SoundEffects.unlockApp();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainShell()),
          );
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



  Future<void> _testConnection(String url, StateSetter setState) async {
    setState(() => _testingConnection = true);
    try {
      // Create a temporary instance or use static method if possible, but ApiService is singleton-ish
      // We need to temporarily set the URL to test it, then revert if failed? 
      // Actually, we can just use http directly to test execution without affecting global state yet, 
      // OR update global state and test.
      final testUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final fullUrl = testUrl.endsWith('/api') ? '$testUrl/health' : '$testUrl/api/health';
      
      final response = await http.get(Uri.parse(fullUrl)).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connection Successful!'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('Status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _testingConnection = false);
    }
  }

  void _showServerUrlDialog() {
    final urlController = TextEditingController(text: ApiService.currentBaseUrl);


    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Server Configuration', style: AppTextStyles.heading),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the backend URL (e.g., https://fair-madelin-safeshellmobile-5ea64b9b.koyeb.app)',
                style: AppTextStyles.body.copyWith(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Base URL',
                prefixIcon: Icons.link,
                controller: urlController,
              ),
              const SizedBox(height: 16),
              if (_testingConnection)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: () => _testConnection(urlController.text, setState),
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Test Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await ApiService.setBaseUrl(urlController.text);
                if (mounted) Navigator.pop(context);
                setState(() {}); // Refresh UI
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // 1. Animated Background Blobs
          _buildAnimatedBlobs(),

          // 2. Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with pulsing glow
                  _buildGlowingLogo(),
                  
                  const SizedBox(height: 24),
                  Text(
                    'SafeShell',
                    style: AppTextStyles.display.copyWith(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Private vault  Stealth mode',
                    style: AppTextStyles.body.copyWith(color: Colors.white60, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 48),
                  
                  // Login Card
                  GlassCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Text(
                            'Welcome Back',
                            style: AppTextStyles.heading.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
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
                              return PremiumButton(
                                text: 'Login',
                                onPressed: _login,
                                isLoading: auth.isLoading,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Google Sign-In Button
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await Provider.of<AuthProvider>(context, listen: false).signInWithGoogle();
                                if (mounted) {
                                  SoundEffects.unlockApp();
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (_) => const MainShell()),
                                  );
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
                            },
                            icon: Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                              height: 18,
                            ),
                            label: const Text('Sign in with Google'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(color: Colors.white.withOpacity(0.1)),
                              foregroundColor: Colors.white,
                            ),
                          ),
                          
                          if (_canCheckBiometrics) ...[
                            const SizedBox(height: 20),
                            _BiometricRippleButton(onTap: _authenticate),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  _buildBottomLinks(),
                  const SizedBox(height: 24),
                  
                  // Server Config Link (Subtle)
                  GestureDetector(
                    onTap: _showServerUrlDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.dns_outlined, size: 14, color: Colors.white38),
                          const SizedBox(width: 6),
                          Text(
                            'Node: ${ApiService.currentBaseUrl}',
                            style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
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

  Widget _buildAnimatedBlobs() {
    return Stack(
      children: [
        // Primary Blue Blob
        Positioned(
          top: -150,
          right: -100,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 8),
            builder: (context, value, child) {
              final move = math.sin(value * 2 * math.pi);
              return Transform.translate(
                offset: Offset(move * 40, move * 50),
                child: Container(
                  width: 450,
                  height: 450,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.primary.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Secondary Indigo Blob
        Positioned(
          bottom: -100,
          left: -150,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.secondary.withOpacity(0.08),
                  AppColors.secondary.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlowingLogo() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOutSine,
      builder: (context, value, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.01 * value),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.05 * value), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.02 * value),
                blurRadius: 50 * value,
                spreadRadius: 1 * value,
              ),
            ],
          ),
          child: Icon(
            Icons.shield_outlined,
            size: 56,
            color: Colors.white.withOpacity(0.9 * value),
          ),
        );
      },
      onEnd: () => setState(() {}), // Trigger micro-rebuild for continuous pulse loop if needed, but builder handles it
    );
  }



  Widget _buildBottomLinks() {
    return Column(
      children: [
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.body.copyWith(fontSize: 14, color: Colors.white54),
              children: [
                const TextSpan(text: "Don't have an account? "),
                TextSpan(
                  text: 'Register',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
          child: Text(
            'Recover Account',
            style: AppTextStyles.caption.copyWith(color: AppColors.primary.withOpacity(0.8), fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
          child: Text(
            'Privacy Policy  Terms of Service',
            style: AppTextStyles.caption.copyWith(color: Colors.white24, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Animated pulsing ripple effect around biometric fingerprint button
class _BiometricRippleButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BiometricRippleButton({required this.onTap});

  @override
  State<_BiometricRippleButton> createState() => _BiometricRippleButtonState();
}

class _BiometricRippleButtonState extends State<_BiometricRippleButton> with TickerProviderStateMixin {
  late AnimationController _ripple1;
  late AnimationController _ripple2;
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ripple1 = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this)..repeat();
    _ripple2 = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
    // Start second ripple with delay
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _ripple2.repeat();
    });
    _scaleCtrl = AnimationController(duration: const Duration(milliseconds: 120), vsync: this);
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ripple1.dispose();
    _ripple2.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) {
        _scaleCtrl.reverse();
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: SizedBox(
          width: 80, height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple 1
              AnimatedBuilder(
                animation: _ripple1,
                builder: (context, child) {
                  return Container(
                    width: 50 + (_ripple1.value * 30),
                    height: 50 + (_ripple1.value * 30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity((1 - _ripple1.value) * 0.4),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              // Ripple 2
              AnimatedBuilder(
                animation: _ripple2,
                builder: (context, child) {
                  return Container(
                    width: 50 + (_ripple2.value * 30),
                    height: 50 + (_ripple2.value * 30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity((1 - _ripple2.value) * 0.25),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              ),
              // Core icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.05)]),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 12)],
                ),
                child: const Icon(Icons.fingerprint, size: 30, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

