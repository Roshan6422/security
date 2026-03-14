import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'security/key_manager.dart';
import 'utils/device_performance.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Turbo: run all initializations in parallel
  await Future.wait([
    _initFirebase(),
    DevicePerformance.init(),
    _restoreStealthMode(),
  ]);

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
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Or set to a reasonable limit like 100 * 1024 * 1024 (100MB)
    );
    
    debugPrint('SafeShell: FIREBASE_READY: Project ID: ${app.options.projectId}');
  } catch (e) {
    debugPrint('SafeShell: FIREBASE_ERROR: $e');
  }
}

Future<void> _restoreStealthMode() async {
  try {
    const storage = FlutterSecureStorage();
    final stealthEnabled = await storage.read(key: 'discreet_mode');
    if (stealthEnabled == 'true') {
      const channel = MethodChannel('com.safeshell.safe_shell_mobile/stealth');
      await channel.invokeMethod('toggleStealthMode', {'enable': true});
      debugPrint('Stealth mode restored on startup');
    }
  } catch (e) {
    debugPrint('Stealth restore error (non-critical): $e');
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
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'SafeShell',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const AppLockListenerWrapper(child: SplashScreen()),
            navigatorObservers: [routeObserver],
          );
        },
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
        if (mounted) _showUsbProtectionDialog(context);
      }
    } else {
      if (settings.usbAppsLocked) {
        await settings.onUsbDisconnected();
        _showUsbDisconnectedSnackbar(context);
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Turbo: No more FutureBuilder flickering. 
    // State is already hydrated by SplashScreen or main.dart
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        // Use a lightweight check for the user key (avoid secondary FutureBuilder)
        return auth.user?.userKey != null ? const MainShell() : const KeySetupScreen();
      },
    );
  }
}

