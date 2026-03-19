import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../calculator/calculator_screen.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'onboarding_screen.dart';
import '../../utils/device_performance.dart';
import '../../services/permission_service.dart';

class SplashScreen extends StatefulWidget {
  final bool ignoreDelay;
  const SplashScreen({super.key, this.ignoreDelay = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  AnimationController? _pulseController;
  AnimationController? _fadeController;
  AnimationController? _particleController;
  Animation<double>? _pulseAnimation;
  Animation<double>? _fadeAnimation;
  bool _isDiscreetMode = false;
  bool _isLowEnd = false;

  @override
  void initState() {
    super.initState();
    _isLowEnd = DevicePerformance.isLowEnd;

    if (_isLowEnd) {
      // Minimal: only a quick fade-in, no particles/pulse
      _fadeController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      )..forward();
      _fadeAnimation = CurvedAnimation(parent: _fadeController!, curve: Curves.easeOut);
    } else {
      // Full animations
      _pulseController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
      _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut));

      _fadeController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..forward();
      _fadeAnimation = CurvedAnimation(parent: _fadeController!, curve: Curves.easeOutCubic);

      _particleController = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat();
    }

    _checkAuthAndNavigate();
    _printFirebaseDiagnostics();
  }

  void _printFirebaseDiagnostics() {
    try {
      final app = Firebase.app();
      print('SafeShell: [RUNTIME_CONFIG] App Name: ${app.name}');
      print('SafeShell: [RUNTIME_CONFIG] Project ID: ${app.options.projectId}');
      print('SafeShell: [RUNTIME_CONFIG] API Key Initial: ${app.options.apiKey.substring(0, 5)}...');
      print('SafeShell: [RUNTIME_CONFIG] App ID: ${app.options.appId}');
    } catch (e) {
      print('SafeShell: [RUNTIME_CONFIG] Error getting configuration: $e');
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
    final prefs = await SharedPreferences.getInstance();
    final isDiscreetMode = prefs.getBool('discreet_mode') ?? false;

    if (mounted) setState(() => _isDiscreetMode = isDiscreetMode);

    if (isDiscreetMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CalculatorScreen()));
      return;
    }

    // Request all permissions immediately on launch
    await PermissionService.requestAllPermissions();
    if (!mounted) return;

    if (!_isDiscreetMode && !widget.ignoreDelay) {
      // Shorter splash delay on low-end
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted) return;

    // Check if onboarding completed
    final onboardingValue = await storage.read(key: 'onboarding_complete');
    print('SafeShell: SPLASH_READ: Onboarding value from storage: "$onboardingValue"');
    final onboardingComplete = onboardingValue == 'true';
    
    if (!onboardingComplete) {
      if (!mounted) return;
      print('SafeShell: SPLASH_NAV: Going to Onboarding screen...');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OnboardingScreen(
          onComplete: () {
            print('SafeShell: CALLBACK_ONBOARDING: "Get Started" triggered');
            navigatorKey.currentState?.pushReplacement(
              MaterialPageRoute(builder: (_) => const SplashScreen(ignoreDelay: true))
            );
          },
          onSkip: () {
            print('SafeShell: CALLBACK_ONBOARDING: "Skip" triggered');
            navigatorKey.currentState?.pushReplacement(
              MaterialPageRoute(builder: (_) => const AuthWrapper())
            );
          },
        )),
      );
      return;
    }

    print('SafeShell: SPLASH_STATE: Onboarding is complete. Proceeding to Auth check...');

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
        transitionDuration: Duration(milliseconds: _isLowEnd ? 300 : 600),
        pageBuilder: (_, __, ___) => const AuthWrapper(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _fadeController?.dispose();
    _particleController?.dispose();
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

    // ───── LOW-END: simple, clean, zero-lag splash ─────
    if (_isLowEnd) {
      return Scaffold(
        backgroundColor: const Color(0xFF020010),
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnimation!,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Simple shield icon — no pulse, no rings, no shadows
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4DA3FF).withOpacity(0.12),
                    border: Border.all(color: const Color(0xFF4DA3FF).withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.shield_outlined, size: 48, color: Color(0xFF4DA3FF)),
                ),
                const SizedBox(height: 36),
                // App name — simple colored text, no ShaderMask
                Text(
                  'SafeShell',
                  style: AppTextStyles.display.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4DA3FF),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Private vault. Stealth mode.',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 60),
                // Simple spinner
                const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF4DA3FF),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ───── FULL: rich animations for capable devices ─────
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
              opacity: _fadeAnimation!,
              child: Container(
                width: 350, height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [const Color(0xFF4DA3FF).withOpacity(0.15), Colors.transparent]),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: FadeTransition(
              opacity: _fadeAnimation!,
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
              opacity: _fadeAnimation!,
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
                          animation: _pulseController!,
                          builder: (context, child) {
                            return Container(
                              width: 140 + (_pulseController!.value * 20),
                              height: 140 + (_pulseController!.value * 20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF4DA3FF).withOpacity(((1 - _pulseController!.value) * 0.15).clamp(0.0, 1.0)),
                                  width: 1.5,
                                ),
                              ),
                            );
                          },
                        ),
                        // Middle ring
                        AnimatedBuilder(
                          animation: _pulseController!,
                          builder: (context, child) {
                            return Container(
                              width: 110 + (_pulseController!.value * 10),
                              height: 110 + (_pulseController!.value * 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF4DA3FF).withOpacity(0.08),
                                  width: 1,
                                ),
                              ),
                            );
                          },
                        ),
                        // Shield icon
                        ScaleTransition(
                          scale: _pulseAnimation!,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [const Color(0xFF4DA3FF).withOpacity(0.15), const Color(0xFF8B5CF6).withOpacity(0.08)],
                              ),
                              border: Border.all(color: const Color(0xFF4DA3FF).withOpacity(0.25)),
                              boxShadow: [BoxShadow(color: const Color(0xFF4DA3FF).withOpacity(0.2), blurRadius: 30, spreadRadius: 5)],
                            ),
                            child: const Icon(Icons.shield_outlined, size: 48, color: Color(0xFF4DA3FF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  // App name with gradient
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6), Color(0xFF10B981)],
                    ).createShader(bounds),
                    child: Text('SafeShell', style: AppTextStyles.display.copyWith(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  Text('Private vault. Stealth mode.', style: AppTextStyles.body.copyWith(color: Colors.white.withOpacity(0.25), fontSize: 14)),
                  const SizedBox(height: 60),
                  // Custom loading dots
                  SizedBox(
                    width: 40,
                    child: _LoadingDots(controller: _particleController!),
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
          animation: _particleController!,
          builder: (context, child) {
            final t = ((_particleController!.value + delay) % 1.0);
            return Opacity(
              opacity: (math.sin(t * math.pi) * 0.4).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -t * 30),
                child: Container(
                  width: size, height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i % 3 == 0 ? const Color(0xFF4DA3FF) : i % 3 == 1 ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
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
                color: const Color(0xFF4DA3FF).withOpacity(opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
