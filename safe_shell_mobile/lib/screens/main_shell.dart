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
  Timer? _inactivityTimer;
  int _remainingSeconds = 0;
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
    
    // Check for auto-lock on boot
    WidgetsBinding.instance.addPostFrameCallback((_) async {
       final settings = Provider.of<SettingsProvider>(context, listen: false);
       if (await settings.shouldLockNow()) {
          _lockApp();
       }
       _resetInactivityTimer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      settings.recordBackgroundTime();
      _inactivityTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      // Refresh security states (USB, Admin status) on resume
      settings.checkAdminStatus();
      
      settings.shouldLockNow().then((shouldLock) {
        if (shouldLock) {
          _lockApp();
        } else {
          settings.clearBackgroundTime();
          _resetInactivityTimer();
        }
      });
    }
  }

  void _resetInactivityTimer() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final limit = settings.autoLockSeconds;
    
    if (limit <= 0) {
      _inactivityTimer?.cancel();
      if (_remainingSeconds != 0) setState(() => _remainingSeconds = 0);
      return;
    }

    _inactivityTimer?.cancel();
    _remainingSeconds = limit;
    
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds == 0) {
          timer.cancel();
          _lockApp();
        }
      }
    });
  }

  void _lockApp() {
    HapticFeedback.heavyImpact();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.logout();
    // No manual navigation needed. AuthWrapper will rebuild and show LoginScreen.
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            BiometricGuardian(
              child: IndexedStack(
                index: _currentIndex,
                children: List.generate(_screens.length, (index) {
                  return _initializedScreens[index] 
                      ? _screens[index] 
                      : const SizedBox.shrink();
                }),
              ),
            ),
            // Subtle Countdown Overlay
            if (_remainingSeconds > 0 && _remainingSeconds <= 30)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.amberAccent, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          'Locking in ${_remainingSeconds}s',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: CustomBottomNav(
          currentIndex: _currentIndex,
          onTap: (index) {
            debugPrint('BNAV_TAP: Navigating to index $index');
            HapticFeedback.selectionClick();
            _resetInactivityTimer();
            setState(() {
              _currentIndex = index;
              _initializedScreens[index] = true;
            });
          },
        ),
      ),
    );
  }
}