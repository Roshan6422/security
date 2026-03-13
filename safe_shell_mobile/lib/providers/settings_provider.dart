import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _channel = MethodChannel('com.safeshell.safe_shell_mobile/stealth');
  final _storage = const FlutterSecureStorage();
  
  int _autoLockSeconds = 0; // 0 = disabled
  bool _isPro = false;
  bool _usbDetectionEnabled = false;
  bool _antiUninstallEnabled = false;
  bool _usbAppsLocked = false; // tracks if apps are currently locked by USB protection

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

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lockStr = await _storage.read(key: 'auto_lock_seconds');
    _autoLockSeconds = int.tryParse(lockStr ?? '0') ?? 0;

    _usbDetectionEnabled = (await _storage.read(key: 'usb_detection')) == 'true';
    _usbAppsLocked = (await _storage.read(key: 'usb_apps_locked')) == 'true';
    
    // Sync Anti-Uninstall with Native Admin status
    _antiUninstallEnabled = await _channel.invokeMethod<bool>('isDeviceAdmin') ?? false;

    notifyListeners();
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    _autoLockSeconds = seconds;
    await _storage.write(key: 'auto_lock_seconds', value: seconds.toString());
    notifyListeners();
  }

  Future<void> toggleUsbDetection(bool enable) async {
    _usbDetectionEnabled = enable;
    await _storage.write(key: 'usb_detection', value: enable.toString());
    
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
      await _storage.write(key: 'usb_apps_locked', value: 'true');
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
      await _storage.write(key: 'usb_apps_locked', value: 'false');
      notifyListeners();
      debugPrint('USB Protection: Unlocked USB apps, kept ${userLocked.length} user apps locked');
    } catch (e) {
      debugPrint('USB Protection unlock error: $e');
    }
  }

  Future<void> toggleAntiUninstall(bool enable) async {
    if (enable) {
      await _channel.invokeMethod('requestDeviceAdmin');
      // Status will be updated via _loadSettings or next check
    } else {
      // User must manually disable in Android Settings for full security,
      // but we can reflect the status check.
    }
    _antiUninstallEnabled = await _channel.invokeMethod<bool>('isDeviceAdmin') ?? false;
    notifyListeners();
  }

  Future<void> checkAdminStatus() async {
    _antiUninstallEnabled = await _channel.invokeMethod<bool>('isDeviceAdmin') ?? false;
    notifyListeners();
  }
}
