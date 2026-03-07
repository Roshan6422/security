import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../calculator/calculator_screen.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../main_shell.dart';
import 'login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _particleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  bool _isDiscreetMode = false;

  @override
  void initState() {
    super.initState();
    // Pulsing shield
    _pulseController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    // Fade in
    _fadeController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..forward();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));

    // Particles
    _particleController = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat();

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    const storage = FlutterSecureStorage();
    final isDiscreetMode = await storage.read(key: 'discreet_mode') == 'true';

    if (mounted) setState(() => _isDiscreetMode = isDiscreetMode);

    if (isDiscreetMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CalculatorScreen()));
      return;
    }

    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    // Check if onboarding completed
    final onboardingComplete = await storage.read(key: 'onboarding_complete') == 'true';
    if (!onboardingComplete) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OnboardingScreen(onComplete: () {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
        })),
      );
      return;
    }

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
            options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false, sensitiveTransaction: false),
          );
          if (!authenticated) canNavigateToHome = false;
        } catch (e) {
          canNavigateToHome = false;
        }
      }
    }
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => canNavigateToHome ? const MainShell() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDiscreetMode) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white24)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF020010),
      body: Stack(
        children: [
          // Animated particles
          ..._buildParticles(),
          // Background glow
          Positioned(
            top: -120,
            right: -120,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 350, height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [const Color(0xFFA855F7).withOpacity(0.15), Colors.transparent]),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 280, height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [const Color(0xFF8B5CF6).withOpacity(0.1), Colors.transparent]),
                ),
              ),
            ),
          ),
          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated shield with rings
                  SizedBox(
                    width: 160, height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer ring
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 140 + (_pulseController.value * 20),
                              height: 140 + (_pulseController.value * 20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFA855F7).withOpacity((1 - _pulseController.value) * 0.15),
                                  width: 1.5,
                                ),
                              ),
                            );
                          },
                        ),
                        // Middle ring
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 110 + (_pulseController.value * 10),
                              height: 110 + (_pulseController.value * 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFA855F7).withOpacity(0.08),
                                  width: 1,
                                ),
                              ),
                            );
                          },
                        ),
                        // Shield icon
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [const Color(0xFFA855F7).withOpacity(0.15), const Color(0xFF8B5CF6).withOpacity(0.08)],
                              ),
                              border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.25)),
                              boxShadow: [BoxShadow(color: const Color(0xFFA855F7).withOpacity(0.2), blurRadius: 30, spreadRadius: 5)],
                            ),
                            child: const Icon(Icons.shield_outlined, size: 48, color: Color(0xFFA855F7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  // App name with gradient
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFA855F7), Color(0xFF8B5CF6), Color(0xFF34D399)],
                    ).createShader(bounds),
                    child: Text('SafeShell', style: AppTextStyles.display.copyWith(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  Text('Private vault. Stealth mode.', style: AppTextStyles.body.copyWith(color: Colors.white.withOpacity(0.25), fontSize: 14)),
                  const SizedBox(height: 60),
                  // Custom loading dots
                  SizedBox(
                    width: 40,
                    child: _LoadingDots(controller: _particleController),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildParticles() {
    final rng = math.Random(42);
    return List.generate(12, (i) {
      final left = rng.nextDouble() * 400;
      final top = rng.nextDouble() * 800;
      final size = 2.0 + rng.nextDouble() * 3;
      final delay = rng.nextDouble();
      return Positioned(
        left: left,
        top: top,
        child: AnimatedBuilder(
          animation: _particleController,
          builder: (context, child) {
            final t = ((_particleController.value + delay) % 1.0);
            return Opacity(
              opacity: (math.sin(t * math.pi) * 0.4).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -t * 30),
                child: Container(
                  width: size, height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i % 3 == 0 ? const Color(0xFFA855F7) : i % 3 == 1 ? const Color(0xFF8B5CF6) : const Color(0xFF34D399),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class _LoadingDots extends StatelessWidget {
  final AnimationController controller;
  const _LoadingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (i) {
            final offset = (i * 0.2);
            final t = ((controller.value + offset) % 1.0);
            final opacity = (math.sin(t * math.pi)).clamp(0.2, 1.0);
            return Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFA855F7).withOpacity(opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
