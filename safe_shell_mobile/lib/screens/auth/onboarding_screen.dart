import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/device_performance.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLowEnd = false;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      icon: Icons.shield_rounded,
      title: 'Military-Grade Security',
      subtitle: 'Your files are encrypted with AES-256 encryption.\nNo one can access them  not even us.',
      gradient: [const Color(0xFF4DA3FF), const Color(0xFF1E6FD9)],
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
      gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
    ),
    _OnboardingData(
      icon: Icons.face_rounded,
      title: 'Biometric Lock',
      subtitle: 'Unlock with Face Lock.\nFast, secure, effortless.',
      gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _isLowEnd = DevicePerformance.isLowEnd;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    debugPrint('SafeShell: Next Page Clicked');
    HapticFeedback.selectionClick();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: _isLowEnd ? 250 : 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    debugPrint('SafeShell: Complete/Skip Onboarding Clicked');
    HapticFeedback.mediumImpact();
    try {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'onboarding_complete', value: 'true');
      debugPrint('SafeShell: Onboarding flagged complete in storage');
    } catch (e) {
      debugPrint('SafeShell: Error saving onboarding state: $e');
    }
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A12),
      body: SafeArea(
        child: Column(
          children: [
              // Page content
              Expanded(
                child: PageView.builder(
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
              ),
              // Bottom controls - outside PageView so taps work
              _buildControls(),
            ],
          ),
        ),
      );
  }

  Widget _buildPage(_OnboardingData page, int index) {
    final iconWidget = Container(
      width: 130, height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _isLowEnd
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [page.gradient[0].withValues(alpha: 0.15), page.gradient[1].withValues(alpha: 0.05)],
              ),
        color: _isLowEnd ? page.gradient[0].withValues(alpha: 0.12) : null,
        border: Border.all(color: page.gradient[0].withValues(alpha: 0.2)),
        // No boxShadow on low-end
        boxShadow: _isLowEnd
            ? null
            : [BoxShadow(color: page.gradient[0].withValues(alpha: 0.15), blurRadius: 40, spreadRadius: 10)],
      ),
      child: Icon(page.icon, size: 56, color: page.gradient[0]),
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              iconWidget,
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
                style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.only(
        left: 32, right: 32,
        bottom: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final isActive = i == _currentPage;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isActive ? _pages[_currentPage].gradient[0] : Colors.white.withValues(alpha: 0.1),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _nextPage,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: _pages[_currentPage].gradient),
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
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Skip', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 14)),
              ),
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
