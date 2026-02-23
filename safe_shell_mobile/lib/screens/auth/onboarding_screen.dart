import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnimation;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      icon: Icons.shield_rounded,
      title: 'Military-Grade Security',
      subtitle: 'Your files are encrypted with AES-256 encryption.\nNo one can access them — not even us.',
      gradient: [const Color(0xFFA855F7), const Color(0xFF1E6FD9)],
    ),
    _OnboardingData(
      icon: Icons.visibility_off_rounded,
      title: 'Stealth Mode',
      subtitle: 'Disguise SafeShell as a calculator app.\nHide your vault in plain sight.',
      gradient: [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
    ),
    _OnboardingData(
      icon: Icons.cloud_upload_rounded,
      title: 'Cloud Vault',
      subtitle: 'Upload photos, videos, and documents.\nAccess them anywhere, anytime.',
      gradient: [const Color(0xFF34D399), const Color(0xFF059669)],
    ),
    _OnboardingData(
      icon: Icons.fingerprint_rounded,
      title: 'Biometric Lock',
      subtitle: 'Unlock with your fingerprint or face.\nFast, secure, effortless.',
      gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this)..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _floatController = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    const storage = FlutterSecureStorage();
    await storage.write(key: 'onboarding_complete', value: 'true');
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A12),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Page content
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _currentPage = i);
              },
              itemBuilder: (context, index) {
                final page = _pages[index];
                return _buildPage(page, index);
              },
            ),
            // Bottom controls
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingData page, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // Animated icon
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, math.sin(_floatController.value * math.pi * 2) * 8),
                child: child,
              );
            },
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [page.gradient[0].withOpacity(0.15), page.gradient[1].withOpacity(0.05)],
                ),
                border: Border.all(color: page.gradient[0].withOpacity(0.2)),
                boxShadow: [BoxShadow(color: page.gradient[0].withOpacity(0.15), blurRadius: 40, spreadRadius: 10)],
              ),
              child: Icon(page.icon, size: 56, color: page.gradient[0]),
            ),
          ),
          const SizedBox(height: 48),
          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: EdgeInsets.only(
        left: 32, right: 32,
        bottom: MediaQuery.of(context).padding.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isActive ? _pages[_currentPage].gradient[0] : Colors.white.withOpacity(0.1),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          // Button
          GestureDetector(
            onTap: _nextPage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: _pages[_currentPage].gradient),
                boxShadow: [BoxShadow(color: _pages[_currentPage].gradient[0].withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Text(
                _currentPage == _pages.length - 1 ? 'Get Started' : 'Continue',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (_currentPage < _pages.length - 1) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _completeOnboarding,
              child: Text('Skip', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 14)),
            ),
          ],
        ],
      ),
    );
  }
}

class _OnboardingData {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  const _OnboardingData({required this.icon, required this.title, required this.subtitle, required this.gradient});
}
