import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _channel = MethodChannel('com.safeshell.safe_shell_mobile/stealth');
  final _storage = const FlutterSecureStorage();
  
  int _autoLockSeconds = 0; // 0 = disabled
  final bool _isPro = false;
  bool _usbDetectionEnabled = false;
  bool _antiUninstallEnabled = false;
  bool _usbAppsLocked = false; // tracks if apps are currently locked by USB protection
  bool _discreetMode = false;
  bool _biometricsEnabled = false;
  bool _allowScreenshots = false;
  int _remainingSeconds = 0;

  // Common packages for File Manager, Gallery, Video on Android
  // These cover stock Samsung, Google, and AOSP apps
  static const List<String> _usbProtectedPackages = [
    // File Managers
    'com.google.android.documentsui',      // Google Files / Documents UI
    'com.google.android.apps.nbu.files',   // Files by Google
    'com.sec.android.app.myfiles',         // Samsung My Files
    'com.mi.android.globalFileexplorer',   // Xiaomi File Manager
    // Gallery / Photos
    'com.google.android.apps.photos',      // Google Photos
    'com.sec.android.gallery3d',           // Samsung Gallery
    'com.miui.gallery',                    // Xiaomi Gallery
    // Video Players
    'com.google.android.videos',           // Google TV / Videos
    'com.sec.android.app.videoplayer',     // Samsung Video Player
    'com.miui.videoplayer',               // Xiaomi Video Player
  ];

  int get autoLockSeconds => _autoLockSeconds;
  bool get isPro => _isPro;
  bool get usbDetectionEnabled => _usbDetectionEnabled;
  bool get antiUninstallEnabled => _antiUninstallEnabled;
  bool get usbAppsLocked => _usbAppsLocked;
  bool get discreetMode => _discreetMode;
  bool get biometricsEnabled => _biometricsEnabled;
  bool get allowScreenshots => _allowScreenshots;
  int get remainingSeconds => _remainingSeconds;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final lockStr = await _storage.read(key: 'auto_lock_seconds');
    _autoLockSeconds = int.tryParse(lockStr ?? '0') ?? 0;

    _usbDetectionEnabled = prefs.getBool('usb_detection') ?? false;
    _usbAppsLocked = prefs.getBool('usb_apps_locked') ?? false;
    _discreetMode = prefs.getBool('discreet_mode') ?? false;
    _biometricsEnabled = prefs.getBool('biometric_enabled') ?? false;
    _allowScreenshots = prefs.getBool('allow_screenshots') ?? false;
    
    // Check if we should auto-lock right now (on boot)
    final lastPaused = prefs.getInt('last_paused_at') ?? 0;
    if (lastPaused > 0 && _autoLockSeconds > 0) {
      final elapsed = (DateTime.now().millisecondsSinceEpoch - lastPaused) ~/ 1000;
      if (elapsed >= _autoLockSeconds) {
        // We don't notify here because we want the consumer (MainShell) to check
        debugPrint('SettingsProvider: Auto-lock detected on startup ($elapsed s elapsed)');
      }
    }
    
    // Sync Anti-Uninstall with Native Admin status (safe – channel may not be ready)
    try {
      _antiUninstallEnabled = await _channel.invokeMethod<bool>('isDeviceAdmin') ?? false;
    } catch (_) {}

    // Apply screenshot setting on load
    try {
      await _channel.invokeMethod('toggleScreenshot', {'allow': _allowScreenshots});
    } catch (_) {}

    notifyListeners();
  }

  /// Checks the current USB state from native code (used on startup)
  Future<bool> checkNativeUsbState() async {
    try {
      return await _channel.invokeMethod<bool>('isUsbConnected') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    _autoLockSeconds = seconds;
    _remainingSeconds = seconds;
    await _storage.write(key: 'auto_lock_seconds', value: seconds.toString());
    
    // Clear last paused time if disabling
    if (seconds == 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_paused_at');
    }
    
    notifyListeners();
  }

  void updateRemainingSeconds(int seconds) {
    if (_remainingSeconds != seconds) {
      _remainingSeconds = seconds;
      notifyListeners();
    }
  }

  /// Records the current time when app backgrounds
  Future<void> recordBackgroundTime() async {
    if (_autoLockSeconds <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_paused_at', DateTime.now().millisecondsSinceEpoch);
    debugPrint('SettingsProvider: Recorded background time');
  }

  /// Clears background time (called on successful user activity or resume within window)
  Future<void> clearBackgroundTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_paused_at');
  }

  /// Returns true if the app should lock based on saved background time
  Future<bool> shouldLockNow() async {
    if (_autoLockSeconds <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    final lastPaused = prefs.getInt('last_paused_at') ?? 0;
    if (lastPaused == 0) return false;

    final elapsed = (DateTime.now().millisecondsSinceEpoch - lastPaused) ~/ 1000;
    return elapsed >= _autoLockSeconds;
  }

  Future<void> toggleUsbDetection(bool enable) async {
    _usbDetectionEnabled = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('usb_detection', enable);
    
    // When turning OFF USB protection, unlock all protected apps
    if (!enable && _usbAppsLocked) {
      await _unlockUsbProtectedApps();
    }
    
    notifyListeners();
  }

  /// Called when USB cable is plugged in and USB protection is enabled
  Future<void> onUsbConnected() async {
    if (!_usbDetectionEnabled) return;
    await _lockUsbProtectedApps();
  }

  /// Called when USB cable is removed
  Future<void> onUsbDisconnected() async {
    if (_usbAppsLocked) {
      await _unlockUsbProtectedApps();
    }
  }

  /// Get the list of apps manually locked by the user in the App Lock screen
  Future<List<String>> _getUserLockedPackages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encoded = prefs.getString('hidden_apps_list');
      if (encoded == null) return [];
      final List<dynamic> decoded = jsonDecode(encoded);
      return decoded
          .where((e) => e['isLocked'] == true)
          .map((e) => e['packageName'] as String)
          .toList();
    } catch (e) {
      debugPrint('Error reading user locked apps: $e');
      return [];
    }
  }

  /// Lock file manager, gallery, and video apps, while preserving user's manual locks
  Future<void> _lockUsbProtectedApps() async {
    try {
      final userLocked = await _getUserLockedPackages();
      final fullList = {...userLocked, ..._usbProtectedPackages}.toList();
      
      await _channel.invokeMethod('setLockedApps', {'packages': fullList});
      _usbAppsLocked = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('usb_apps_locked', true);
      notifyListeners();
      debugPrint('USB Protection: Locked USB apps + ${userLocked.length} user apps');
    } catch (e) {
      debugPrint('USB Protection lock error: $e');
    }
  }

  /// Unlock only USB-protected apps, keeping user's manual locks active
  Future<void> _unlockUsbProtectedApps() async {
    try {
      final userLocked = await _getUserLockedPackages();
      
      // Sync only the user's manual locks, effectively unlocking USB-specific apps
      await _channel.invokeMethod('setLockedApps', {'packages': userLocked});
      _usbAppsLocked = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('usb_apps_locked', false);
      notifyListeners();
      debugPrint('USB Protection: Unlocked USB apps, kept ${userLocked.length} user apps locked');
    } catch (e) {
      debugPrint('USB Protection unlock error: $e');
    }
  }

  Future<void> toggleDiscreetMode(bool enable) async {
    _discreetMode = enable;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('discreet_mode', enable);
    
    // Let it persist before invoking native method which might kill the process
    await _channel.invokeMethod('toggleStealthMode', {'enable': enable});
  }

  Future<void> toggleBiometrics(bool enable) async {
    _biometricsEnabled = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enable);
    await _storage.write(key: 'biometric_enabled', value: enable.toString());
    notifyListeners();
  }

  Future<void> toggleScreenshots(bool allow) async {
    _allowScreenshots = allow;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allow_screenshots', allow);
    await _channel.invokeMethod('toggleScreenshot', {'allow': allow});
    notifyListeners();
  }

  Future<void> toggleAntiUninstall(bool enable) async {
    if (enable) {
      await _channel.invokeMethod('requestDeviceAdmin');
    } else {
      await _channel.invokeMethod('deactivateDeviceAdmin');
    }
    // Check status after a small delay to allow native screen to return
    Future.delayed(const Duration(seconds: 1), () => checkAdminStatus());
  }

  Future<void> checkAdminStatus() async {
    _antiUninstallEnabled = await _channel.invokeMethod<bool>('isDeviceAdmin') ?? false;
    notifyListeners();
  }
}
