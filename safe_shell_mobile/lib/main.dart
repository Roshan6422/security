import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/main_shell.dart';
import 'screens/auth/key_setup_screen.dart';
import 'screens/auth/app_lock_screen.dart';
import 'screens/calculator/calculator_screen.dart';
import 'utils/device_performance.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fcm_service.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<int> globalInteractionNotifier = ValueNotifier(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register FCM background handler BEFORE Firebase.initializeApp
  // This is required for Firebase Messaging to work when app is terminated.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Turbo: run all initializations in parallel
  await Future.wait([
    _initFirebase(),
    DevicePerformance.init(),
    _restoreStealthMode(),
  ]);

  // Lock orientation to portrait — avoids layout recalculation on rotate
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Set system UI overlay style immediately to prevent first-frame flash
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

Future<void> _initFirebase() async {
  try {
    FirebaseApp app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Turbo: Enable Firestore Offline Persistence for instant dashboard paint
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
    if (kDebugMode) debugPrint('SafeShell: FIREBASE_READY: Project ID: ${app.options.projectId}');
  } catch (e) {
    if (kDebugMode) debugPrint('SafeShell: FIREBASE_ERROR: $e');
  }
}

Future<void> _restoreStealthMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final stealthEnabled = prefs.getBool('discreet_mode') ?? false;
    if (stealthEnabled) {
      const channel = MethodChannel('com.safeshell.safe_shell_mobile/stealth');
      await channel.invokeMethod('toggleStealthMode', {'enable': true});
      if (kDebugMode) debugPrint('Stealth mode restored on startup');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('Stealth restore error (non-critical): $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      // MaterialApp is NOT wrapped in Consumer — it never rebuilds due to auth changes.
      // Auth routing is handled by SplashScreen → AuthWrapper internally.
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'SafeShell',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        builder: (context, child) {
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => globalInteractionNotifier.value++,
            child: child!,
          );
        },
        home: const AppLockListenerWrapper(child: SplashScreen()),
        navigatorObservers: [routeObserver],
      ),
    );
  }
}

class AppLockListenerWrapper extends StatefulWidget {
  final Widget child;
  const AppLockListenerWrapper({super.key, required this.child});

  @override
  State<AppLockListenerWrapper> createState() => _AppLockListenerWrapperState();
}

class _AppLockListenerWrapperState extends State<AppLockListenerWrapper> {
  static const _channel = MethodChannel('com.safeshell.safe_shell_mobile/stealth');
  bool _isLockShowing = false;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleMethodCall);
    // Signal native that Flutter is ready  flushes any pending lock target
    _signalReady();
    _checkInitialUsbState();
  }

  Future<void> _checkInitialUsbState() async {
    // Wait a brief moment for providers to settle
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isConnected = await settings.checkNativeUsbState();
    if (isConnected) {
      _handleUsbEvent(true);
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'showAppLock':
        final String packageName = call.arguments['packageName'];
        _showLockScreen(packageName);
        break;
      case 'onUsbStatusChanged':
        final bool connected = call.arguments['connected'] ?? false;
        _handleUsbEvent(connected);
        break;
    }
  }

  Future<void> _handleUsbEvent(bool connected) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.usbDetectionEnabled) return;

    if (connected) {
      if (!settings.usbAppsLocked) {
        await settings.onUsbConnected();
        if (context.mounted) _showUsbProtectionDialog(context);
      }
    } else {
      if (settings.usbAppsLocked) {
        await settings.onUsbDisconnected();
        if (context.mounted) _showUsbDisconnectedSnackbar(context);
      }
    }
  }

  void _showUsbProtectionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.shield_rounded, color: Colors.redAccent, size: 48),
        title: const Text(
          '🔒 USB Protection Active',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gallery, File Manager & Video Player are now LOCKED to protect your files.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pull down notification bar & switch USB to "Charging Only" for maximum protection.',
                      style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To unlock apps, go to Settings → USB Protection → OFF',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showUsbDisconnectedSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.usb_off, color: Colors.white70),
            SizedBox(width: 12),
            Text('USB Device Disconnected', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.blueGrey,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _signalReady() async {
    try {
      await _channel.invokeMethod('ready');
    } catch (_) {}
  }

  void _showLockScreen(String packageName) {
    if (_isLockShowing) return;
    _isLockShowing = true;
    
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AppLockScreen(packageName: packageName),
      ),
    ).then((_) => _isLockShowing = false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  int _remainingSeconds = 0;
  int _lastLimit = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    globalInteractionNotifier.addListener(_onGlobalInteraction);
    _resetInactivityTimer(force: true);
  }

  @override
  void dispose() {
    globalInteractionNotifier.removeListener(_onGlobalInteraction);
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _onGlobalInteraction() {
    _resetInactivityTimer(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      settings.recordBackgroundTime();
      _inactivityTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      settings.shouldLockNow().then((shouldLock) {
        if (shouldLock) {
          _lockApp();
        } else {
          settings.clearBackgroundTime();
          _resetInactivityTimer(force: true);
        }
      });
    }
  }

  void _resetInactivityTimer({bool force = false}) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final limit = settings.autoLockSeconds;
    
    // If not forced (e.g. from build loop), only reset if limit changed
    if (!force && limit == _lastLimit) return;
    _lastLimit = limit;

    if (limit <= 0) {
      _inactivityTimer?.cancel();
      if (_remainingSeconds != 0) {
        setState(() => _remainingSeconds = 0);
        settings.updateRemainingSeconds(0);
      }
      return;
    }

    _inactivityTimer?.cancel();
    _remainingSeconds = limit;
    settings.updateRemainingSeconds(limit);
    
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
          settings.updateRemainingSeconds(_remainingSeconds);
        }
        if (_remainingSeconds == 0) {
          timer.cancel();
          _lockApp();
        }
      }
    });
  }

  void _lockApp() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      HapticFeedback.heavyImpact();
      auth.logout();
      // If discreet mode is on, navigate to calculator instead of login
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.discreetMode) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CalculatorScreen()),
          (route) => false,
        );
      }
    } else {
      _resetInactivityTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, SettingsProvider>(
      builder: (context, auth, settings, _) {
        // Automatically refresh timer if the limit changed in settings
        // We use a post-frame callback to avoid "setState during build" errors
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _resetInactivityTimer();
        });

        Widget child;
        if (!auth.isAuthenticated) {
          child = const LoginScreen();
        } else if (auth.user?.userKey == null) {
          child = const KeySetupScreen();
        } else {
          child = const MainShell();
        }

        return Stack(
          children: [
            child,
            // Global Countdown Overlay (only show if authenticated, as LoginScreen has its own)
            if (auth.isAuthenticated && _remainingSeconds > 0 && _remainingSeconds <= 30)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
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
              ),
          ],
        );
      },
    );
  }
}

