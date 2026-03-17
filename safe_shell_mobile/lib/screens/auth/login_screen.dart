import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:safe_shell_mobile/utils/sound_effects.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    _loadSavedEmail();
    _checkBiometricsAndAutoAuth();
  }

  Future<void> _loadSavedEmail() async {
    final email = await _storage.read(key: 'bio_email');
    if (email != null && mounted) {
      _emailController.text = email;
    }
  }

  Future<void> _checkBiometricsAndAutoAuth() async {
    if (kDebugMode) debugPrint('LoginScreen: Checking biometrics...');
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final biometricEnabled = await _storage.read(key: 'biometric_enabled');
      
      final isBioReady = isDeviceSupported && canCheck && biometricEnabled == 'true';
      
      if (mounted) {
        setState(() {
          _canCheckBiometrics = isBioReady;
        });
      }

      // Auto-trigger authentication if enabled
      if (isBioReady) {
        // Delay slightly to ensure UI is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _authenticate();
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('LoginScreen: Biometric Check Error: $e');
    }
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
    if (kDebugMode) debugPrint('LoginScreen: Login attempt (Biometric: $isBiometric)');
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email address'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      try {
        print('SafeShell: LOGIN_SCREEN: Validated form. Calling AuthProvider.login...');
        await Provider.of<AuthProvider>(context, listen: false).login(
          email,
          password,
        );
        
        // Save credentials for biometrics if successful and not already using biometrics (or update them)
        if (!isBiometric) {
           await _storage.write(key: 'bio_email', value: _emailController.text);
           await _storage.write(key: 'bio_password', value: _passwordController.text);
        }

        if (mounted) {
          SoundEffects.unlockApp();
          // Navigation is now handled reactively by AuthWrapper in main.dart
          // Navigator.of(context).pushReplacement(...) removed
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



  String _generatePassword() {
    // Generate a strong random password
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890!@#\$%^&*()_+';
    final random = List.generate(16, (index) => chars[(chars.length * (DateTime.now().microsecondsSinceEpoch % 1000) / 1000).floor() % chars.length]).join();
    return 'G${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}$random'.substring(0, 16) + '!\$A1';
  }

  // Removed legacy server config UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // 1. Animated Background Blobs
          _buildStaticBlobs(),

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
                                onPressed: () => _login(),
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
                                  // Navigation is now handled reactively by AuthWrapper
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
                              height: 22,
                            ),
                            label: const Text('Sign in with Google'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(color: Colors.white.withOpacity(0.15)),
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
                  
                  // Server connection UI removed for pure Firebase setup
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticBlobs() {
    return IgnorePointer(
      child: Stack(
        children: [
          // Primary Blue Blob (Static)
          Positioned(
            top: -150,
            right: -100,
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
          ),
          // Secondary Indigo Blob (Static)
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
      ),
    );
  }

  Widget _buildGlowingLogo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.01),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withOpacity(0.05), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.02),
            blurRadius: 50,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(
        Icons.shield_outlined,
        size: 56,
        color: Colors.white,
      ),
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Text(
                'Recover Account',
                style: AppTextStyles.caption.copyWith(color: AppColors.primary.withOpacity(0.8), fontWeight: FontWeight.bold),
              ),
            ),
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

class _BiometricRippleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BiometricRippleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.05)]),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 12)],
        ),
        child: const Icon(Icons.face_rounded, size: 30, color: AppColors.primary),
      ),
    );
  }
}

