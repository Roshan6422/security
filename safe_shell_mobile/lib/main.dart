import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/main_shell.dart';
import 'screens/auth/key_setup_screen.dart';
import 'screens/auth/app_lock_screen.dart';
import 'screens/calculator/calculator_screen.dart';
import 'security/key_manager.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
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
            home: const SplashScreen(),
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
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'showAppLock') {
        final String packageName = call.arguments['packageName'];
        _showLockScreen(packageName);
      }
    });
    // Signal native that Flutter is ready  flushes any pending lock target
    _signalReady();
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

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<void> _authFuture;
  final _km = KeyManager();

  @override
  void initState() {
    super.initState();
    _authFuture = Provider.of<AuthProvider>(context, listen: false).checkAuth();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return FutureBuilder(
          future: _authFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Auth check takes priority

            return Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (!auth.isAuthenticated) {
                  return LoginScreen();
                }

                return FutureBuilder<bool>(
                  future: _km.hasKey(),
                  builder: (context, keySnapshot) {
                    if (keySnapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (keySnapshot.data == true) {
                      return const MainShell();
                    } else {
                      return const KeySetupScreen();
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

