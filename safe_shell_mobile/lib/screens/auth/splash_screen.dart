import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../main_shell.dart';
import '../calculator/calculator_screen.dart';
import 'login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isDiscreetMode = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    const storage = FlutterSecureStorage();
    final isDiscreetMode = await storage.read(key: 'discreet_mode') == 'true';

    if (mounted) setState(() => _isDiscreetMode = isDiscreetMode);

    if (isDiscreetMode) {
      // Minimal delay — no branding shown
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CalculatorScreen()),
      );
      return;
    }

    // Normal mode: show SafeShell splash
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.checkAuth();
    
    bool canNavigateToHome = auth.isAuthenticated;

    if (canNavigateToHome) {
      final bioEnabled = await storage.read(key: 'biometric_enabled') == 'true';

      if (bioEnabled) {
        final localAuth = LocalAuthentication();
        try {
          bool authenticated = await localAuth.authenticate(
             localizedReason: 'Unlock SafeShell Vault',
             options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
          );
          if (!authenticated) canNavigateToHome = false;
        } catch (e) {
          canNavigateToHome = false;
        }
      }
    }
    
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => canNavigateToHome
            ? const MainShell()
            : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // In discreet mode: plain dark screen, no SafeShell branding
    if (_isDiscreetMode) {
      return const Scaffold(
        backgroundColor: Color(0xFF1C1C1E), // iOS calculator dark bg
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF636366)),
        ),
      );
    }

    // Normal mode: SafeShell branded splash
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'SafeShell',
                    style: AppTextStyles.display,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Private vault. Stealth mode.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 64),
                  const CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
