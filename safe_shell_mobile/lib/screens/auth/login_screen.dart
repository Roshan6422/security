import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../core/theme.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
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
      final biometricEnabled = await _storage.read(key: 'biometric_enabled');
      setState(() {
        // Broaden support: if hardware is supported and user enabled it, show the button
        _canCheckBiometrics = isDeviceSupported && biometricEnabled == 'true';
      });
    } catch (_) {}
  }

  Future<void> _authenticate() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access SafeShell Vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/Pattern/Face fallback
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
            const SnackBar(content: Text('No credentials saved. Please login manually first.')),
          );
        }
      }
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
              onPressed: () {
                ApiService.setBaseUrl(urlController.text);
                Navigator.pop(context);
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
      backgroundColor: AppColors.background,
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
                    'Private vault • Stealth mode',
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
                              return PrimaryButton(
                                text: 'Login',
                                onPressed: _login,
                                isLoading: auth.isLoading,
                              );
                            },
                          ),
                          if (_canCheckBiometrics) ...[
                            const SizedBox(height: 16),
                            IconButton(
                              icon: const Icon(Icons.fingerprint, size: 44, color: AppColors.primary),
                              tooltip: 'Login with Biometrics',
                              onPressed: _authenticate,
                            ),
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
          top: -100,
          right: -50,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 4),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(value * 20, value * 30),
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 100, spreadRadius: 50),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Secondary Purple Blob
        Positioned(
          bottom: 0,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8B5CF6).withOpacity(0.08),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.05), blurRadius: 120, spreadRadius: 60),
              ],
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
            color: AppColors.primary.withOpacity(0.1 * value),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.3 * value), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4 * value),
                blurRadius: 30 * value,
                spreadRadius: 5 * value,
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
            'Privacy Policy • Terms of Service',
            style: AppTextStyles.caption.copyWith(color: Colors.white24, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

