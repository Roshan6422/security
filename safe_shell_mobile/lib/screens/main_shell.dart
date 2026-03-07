import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Trigger legacy file recovery safely after the app is fully launched
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
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BiometricGuardian(
      child: Scaffold(
        extendBody: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: _screens[_currentIndex],
          ),
        ),
        bottomNavigationBar: CustomBottomNav(
          currentIndex: _currentIndex,
          onTap: (index) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = index);
          },
        ),
      ),
    );
  }
}
