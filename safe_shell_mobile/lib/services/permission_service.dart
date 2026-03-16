import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Requests all required permissions on first launch.
/// Called once from the splash screen before auth check.
class PermissionService {
  static Future<void> requestAllPermissions() async {
    try {
      final sdkInt = await _getAndroidSdk();

      final List<Permission> permissions = [
        // Storage — depends on Android version
        if (sdkInt >= 33) ...[
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ] else ...[
          Permission.storage,
        ],

        // Manage all files (Android 11+)
        if (sdkInt >= 30) Permission.manageExternalStorage,

        // Camera (for future use / vault capture)
        Permission.camera,

        // Notifications (Android 13+)
        if (sdkInt >= 33) Permission.notification,
      ];

      // Request all standard permissions in one batch
      final statuses = await permissions.request();

      if (kDebugMode) {
        statuses.forEach((permission, status) {
          debugPrint('SafeShell: Permission $permission -> $status');
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SafeShell: Permission request error: $e');
      }
    }
  }

  static Future<int> _getAndroidSdk() async {
    if (!Platform.isAndroid) return 0;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 0;
    }
  }
}
