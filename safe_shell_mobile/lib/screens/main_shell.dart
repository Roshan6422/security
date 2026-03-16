import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_bottom_nav.dart';
// ✅ Fix 1: Removed unused import
// import '../widgets/biometric_guardian.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import 'home/dashboard_screen.dart';
import 'vault/vault_screen.dart';
import 'settings/settings_screen.dart';
import 'profile/profile_screen.dart';
import 'auth/login_screen.dart';
import '../services/file_recovery_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _autoLockTimer;
  DateTime? _pausedAt;

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
    WidgetsBinding.instance.addObserver(this);
    FileRecoveryService().restoreLegacyFiles();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoLockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final lockSeconds = settings.autoLockSeconds;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt = DateTime.now();
      if (lockSeconds > 0) {
        _autoLockTimer?.cancel();
        _autoLockTimer = Timer(Duration(seconds: lockSeconds), _lockApp);
      }
    } else if (state == AppLifecycleState.resumed) {
      _autoLockTimer?.cancel();
      
      // Refresh security states (USB, Admin status) on resume
      settings.checkAdminStatus();
      
      if (_pausedAt != null && lockSeconds > 0) {
        final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
        if (elapsed >= lockSeconds) {
          _lockApp();
        }
      }
      _pausedAt = null;
    }
  }

  void _lockApp() {
    HapticFeedback.heavyImpact();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.logout();
    // No manual navigation needed. AuthWrapper will rebuild and show LoginScreen.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(_screens.length, (index) {
          return _initializedScreens[index] 
              ? _screens[index] 
              : const SizedBox.shrink();
        }),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          debugPrint('BNAV_TAP: Navigating to index $index');
          HapticFeedback.selectionClick();
          setState(() {
            _currentIndex = index;
            _initializedScreens[index] = true;
          });
        },
      ),
    );
  }
}