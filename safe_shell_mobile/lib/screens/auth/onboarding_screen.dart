import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/device_performance.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  const OnboardingScreen({super.key, required this.onComplete, required this.onSkip});

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

  bool _isProcessingOnboarding = false;

  void _completeOnboarding() async {
    if (_isProcessingOnboarding) return;
    print('SafeShell: ONBOARDING_CLICK: "Get Started" clicked');
    setState(() => _isProcessingOnboarding = true);
    HapticFeedback.mediumImpact();
    
    try {
      const storage = FlutterSecureStorage();
      print('SafeShell: ONBOARDING_STORAGE: Saving "true"...');
      await storage.write(key: 'onboarding_complete', value: 'true');
      print('SafeShell: ONBOARDING_STORAGE_SUCCESS: State saved');
      // Buffer to ensure storage is flushed
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      print('SafeShell: ONBOARDING_STORAGE_ERROR: $e');
    }

    if (!mounted) return;
    print('SafeShell: ONBOARDING_CALLBACK: Triggering onComplete');
    widget.onComplete();
  }

  void _skipOnboarding() async {
    if (_isProcessingOnboarding) return;
    print('SafeShell: ONBOARDING_CLICK: "Skip" clicked');
    setState(() => _isProcessingOnboarding = true);
    HapticFeedback.mediumImpact();
    
    try {
      const storage = FlutterSecureStorage();
      print('SafeShell: ONBOARDING_STORAGE: Saving "true" (via skip)...');
      await storage.write(key: 'onboarding_complete', value: 'true');
      print('SafeShell: ONBOARDING_STORAGE_SUCCESS: Skip state saved');
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('SafeShell: ONBOARDING_STORAGE_ERROR: $e');
    }
    
    if (!mounted) return;
    print('SafeShell: ONBOARDING_CALLBACK: Triggering onSkip');
    widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A12),
      body: SafeArea(
        child: Column(
          children: [
            // Top Row for Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _skipOnboarding,
                      borderRadius: BorderRadius.circular(20),
                      splashColor: Colors.white.withOpacity(0.1),
                      highlightColor: Colors.white.withOpacity(0.05),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
            // Bottom controls
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
                colors: [page.gradient[0].withOpacity(0.15), page.gradient[1].withOpacity(0.05)],
              ),
        color: _isLowEnd ? page.gradient[0].withOpacity(0.12) : null,
        border: Border.all(color: page.gradient[0].withOpacity(0.2)),
        // No boxShadow on low-end
        boxShadow: _isLowEnd
            ? null
            : [BoxShadow(color: page.gradient[0].withOpacity(0.15), blurRadius: 40, spreadRadius: 10)],
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
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 15, height: 1.5),
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
                  color: isActive ? _pages[_currentPage].gradient[0] : Colors.white.withOpacity(0.1),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          // Primary Action Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _nextPage,
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.white.withOpacity(0.2),
              child: Ink(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: _pages[_currentPage].gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _pages[_currentPage].gradient[0].withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPage == _pages.length - 1 ? 'Get Started' : 'Continue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (_currentPage != _pages.length - 1) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ).animate(
            target: _currentPage == _pages.length - 1 ? 1 : 0,
          ).shimmer(
            duration: 2.seconds,
            color: Colors.white.withOpacity(0.2),
          ).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.02, 1.02),
            duration: 1.seconds,
            curve: Curves.easeInOut,
          ).then().shake(hz: 2),
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
