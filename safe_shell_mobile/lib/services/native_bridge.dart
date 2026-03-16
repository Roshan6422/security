import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Unified Flutter ↔ Native bridge for all platform channel calls.
/// Channel: com.safeshell.safe_shell_mobile/stealth (legacy name, handles all native ops)
class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('com.safeshell.safe_shell_mobile/stealth');

  // ─────────── ENCRYPTION (AES-GCM via Android Keystore) ───────────

  /// Encrypts raw bytes using hardware-backed AES-GCM.
  /// Returns a map with 'ciphertext' and 'iv' as Base64 strings.
  static Future<Map<String, String>> encrypt(Uint8List data) async {
    final result = await _channel.invokeMethod<Map>('hwEncrypt', {'data': data});
    return {
      'ciphertext': result!['ciphertext'] as String,
      'iv': result['iv'] as String,
    };
  }

  /// Decrypts AES-GCM ciphertext using hardware-backed key.
  /// Takes Base64-encoded ciphertext and iv strings.
  static Future<Uint8List> decrypt(String ciphertext, String iv) async {
    final result = await _channel.invokeMethod<Uint8List>(
      'hwDecrypt',
      {'ciphertext': ciphertext, 'iv': iv},
    );
    return result!;
  }

  // ─────────── STEALTH MODE ───────────

  /// Enable stealth mode — hides SafeShell icon and shows Calculator alias.
  static Future<void> enableStealth() async {
    await _channel.invokeMethod('toggleStealthMode', {'enable': true});
  }

  /// Disable stealth mode — restores SafeShell icon.
  static Future<void> disableStealth() async {
    await _channel.invokeMethod('toggleStealthMode', {'enable': false});
  }

  // ─────────── DEVICE ADMIN (Anti-Uninstall) ───────────

  /// Check if SafeShell has device admin privileges.
  static Future<bool> isDeviceAdmin() async {
    final result = await _channel.invokeMethod<bool>('isDeviceAdmin');
    return result ?? false;
  }

  /// Request device admin to enable anti-uninstall protection.
  static Future<void> requestDeviceAdmin() async {
    await _channel.invokeMethod('requestDeviceAdmin');
  }

  /// Deactivate device admin (allows uninstall).
  static Future<void> deactivateDeviceAdmin() async {
    await _channel.invokeMethod('deactivateDeviceAdmin');
  }

  // ─────────── USB DETECTION ───────────

  /// Check current USB connection status.
  static Future<bool> isUsbConnected() async {
    final result = await _channel.invokeMethod<bool>('isUsbConnected');
    return result ?? false;
  }

  /// Get USB status from UsbManager (checks connected devices).
  static Future<bool> getUsbStatus() async {
    final result = await _channel.invokeMethod<bool>('getUsbStatus');
    return result ?? false;
  }

  // ─────────── APP LOCK ───────────

  /// Set the list of packages to be locked by the foreground monitoring service.
  static Future<void> setLockedApps(List<String> packages) async {
    await _channel.invokeMethod('setLockedApps', {'packages': packages});
  }

  /// Temporarily unlock a package (until screen off or app switch).
  static Future<void> unlockPackage(String packageName) async {
    await _channel.invokeMethod('unlockPackage', {'packageName': packageName});
  }

  /// Check if AppLockService is currently running.
  static Future<bool> isServiceRunning() async {
    final result = await _channel.invokeMethod<bool>('checkServiceStatus');
    return result ?? false;
  }

  // ─────────── APP HIDER ───────────

  /// Hide an app from the launcher.
  static Future<bool> hideApp(String packageName) async {
    final result =
        await _channel.invokeMethod<bool>('hideApp', {'packageName': packageName});
    return result ?? false;
  }

  /// Unhide (restore) an app in the launcher.
  static Future<bool> unhideApp(String packageName) async {
    final result =
        await _channel.invokeMethod<bool>('unhideApp', {'packageName': packageName});
    return result ?? false;
  }

  /// Check if an app is currently hidden.
  static Future<bool> isAppHidden(String packageName) async {
    final result =
        await _channel.invokeMethod<bool>('isAppHidden', {'packageName': packageName});
    return result ?? false;
  }

  // ─────────── INSTALLED APPS ───────────

  /// Get list of installed apps with name, packageName, and icon (base64).
  static Future<List<Map<String, String>>> getInstalledApps() async {
    final result = await _channel.invokeMethod<List>('getInstalledApps');
    return result
            ?.map((e) => Map<String, String>.from(e as Map))
            .toList() ??
        [];
  }

  /// Launch an app by package name.
  static Future<bool> launchApp(String packageName) async {
    final result =
        await _channel.invokeMethod<bool>('launchApp', {'packageName': packageName});
    return result ?? false;
  }

  // ─────────── PERMISSIONS ───────────

  /// Check if usage stats permission is granted.
  static Future<bool> hasUsagePermission() async {
    final result = await _channel.invokeMethod<bool>('checkUsagePermission');
    return result ?? false;
  }

  /// Open usage access settings for the user to grant permission.
  static Future<void> requestUsagePermission() async {
    await _channel.invokeMethod('requestUsagePermission');
  }

  /// Check if overlay (draw over other apps) permission is granted.
  static Future<bool> hasOverlayPermission() async {
    final result = await _channel.invokeMethod<bool>('checkOverlayPermission');
    return result ?? false;
  }

  /// Open overlay permission settings.
  static Future<void> requestOverlayPermission({String? packageName}) async {
    await _channel.invokeMethod(
      'requestOverlayPermission',
      packageName != null ? {'packageName': packageName} : null,
    );
  }

  // ─────────── SCREENSHOT PROTECTION ───────────

  /// Toggle screenshot/screen recording protection.
  static Future<void> toggleScreenshot(bool allow) async {
    await _channel.invokeMethod('toggleScreenshot', {'allow': allow});
  }

  // ─────────── DEVICE INFO ───────────

  /// Check if device is running MIUI (Xiaomi).
  static Future<bool> isMiui() async {
    final result = await _channel.invokeMethod<bool>('isMiui');
    return result ?? false;
  }
}
