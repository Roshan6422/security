import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/biometric_guardian.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import 'home/dashboard_screen.dart';
import 'vault/vault_screen.dart';
import 'settings/settings_screen.dart';
import 'profile/profile_screen.dart';
import '../services/file_recovery_service.dart';
import 'calculator/calculator_screen.dart';
import '../main.dart' show navigatorKey;

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    VaultScreen(),
    SettingsScreen(),
    ProfileScreen(),
  ];

  late List<bool> _initializedScreens;

  @override
  void initState() {
    super.initState();
    _initializedScreens = List.generate(_screens.length, (index) => index == 0);
    FileRecoveryService().restoreLegacyFiles();
    
    // Check for auto-lock on boot
    WidgetsBinding.instance.addPostFrameCallback((_) async {
       final settings = Provider.of<SettingsProvider>(context, listen: false);
       if (await settings.shouldLockNow()) {
          _lockApp();
       }
    });
  }

  void _lockApp() {
    HapticFeedback.heavyImpact();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.logout();
    // If discreet mode is on, navigate to calculator instead of login
    if (settings.discreetMode) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CalculatorScreen()),
        (route) => false,
      );
    }
    // No manual navigation needed for normal mode — AuthWrapper rebuilds and shows LoginScreen.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BiometricGuardian(
        child: IndexedStack(
          index: _currentIndex,
          children: List.generate(_screens.length, (index) {
            return _initializedScreens[index] 
                ? _screens[index] 
                : const SizedBox.shrink();
          }),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          
          debugPrint('BNAV_TAP: Navigating to index $index');
          HapticFeedback.selectionClick();
          
          setState(() {
            _currentIndex = index;
            _initializedScreens[index] = true;
          });
          
          // Trigger memory optimization for background layers
          _optimizeBackgroundMemory();
        },
      ),
    );
  }

  void _optimizeBackgroundMemory() {
    // Phase 161: Micro-task for background memory dehydration
    Future.microtask(() {
      if (!mounted) return;
      debugPrint('MEM_AUDIT: Dehydrating background screens...');
      // Logic would typically involve notifying a MemoryController 
      // or calling clear() on unused services. 
      // For now, we clear the images cache when switching tabs
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
  }
}