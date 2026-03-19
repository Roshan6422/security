import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Detects if the device is low-end and should skip heavy animations.
/// Call [DevicePerformance.init()] once at app startup.
class DevicePerformance {
  static bool _isLowEnd = false;
  static bool _initialized = false;
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  /// True if device has low RAM or old Android version, or user forced it.
  static bool get isLowEnd => _isLowEnd;

  /// Initialize device detection. Safe to call multiple times.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Check if user explicitly set performance mode
      final userPref = await _storage.read(key: 'force_low_end_mode');
      if (userPref != null) {
        _isLowEnd = userPref == 'true';
        return;
      }

      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final sdkInt = info.version.sdkInt;

        // Check RAM flag
        final isLowRamFlag = info.systemFeatures.contains('android.hardware.ram.low');

        // Heuristic detection:
        // - Android 8 or below (API <= 27) → always low-end
        // - Android 9-10 (API 28-29) with low RAM flag → low-end
        // - Any device with explicit low RAM flag → low-end
        if (sdkInt <= 27 || isLowRamFlag) {
          _isLowEnd = true;
        } else if (sdkInt <= 29) {
          // Android 9-10: treat as low-end (many budget phones run Android 9-10)
          _isLowEnd = true;
        }
      }
    } catch (_) {
      // If detection fails, assume capable device
      _isLowEnd = false;
    }
  }

  /// Force low-end mode (for user settings toggle)
  static Future<void> setLowEnd(bool value) async {
    _isLowEnd = value;
    await _storage.write(key: 'force_low_end_mode', value: value.toString());
  }

  /// Clear user preference and re-detect
  static Future<void> resetToAuto() async {
    await _storage.delete(key: 'force_low_end_mode');
    _initialized = false;
    await init();
  }
}
