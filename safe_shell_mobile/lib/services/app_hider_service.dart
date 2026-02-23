import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SystemApp {
  final String name;
  final String packageName;
  final String iconBase64;
  bool isLocked;
  bool isHidden;

  SystemApp({
    required this.name,
    required this.packageName,
    required this.iconBase64,
    this.isLocked = false,
    this.isHidden = false,
  });

  factory SystemApp.fromMap(Map<dynamic, dynamic> map) {
    return SystemApp(
      name: map['name'] ?? '',
      packageName: map['packageName'] ?? '',
      iconBase64: map['icon'] ?? '',
      isLocked: map['isLocked'] == true,
      isHidden: map['isHidden'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'packageName': packageName,
      'icon': iconBase64,
      'isLocked': isLocked,
      'isHidden': isHidden,
    };
  }
}

class AppHiderService {
  static const _channel = MethodChannel('com.safeshell.safe_shell_mobile/stealth');
  static const _storageKey = 'hidden_apps_list';

  Future<List<SystemApp>> getInstalledApps() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getInstalledApps');
      return result.map((e) => SystemApp.fromMap(e as Map)).toList();
    } catch (e) {
      print('Error getting installed apps: $e');
      return [];
    }
  }

  Future<bool> launchApp(String packageName) async {
    try {
      return await _channel.invokeMethod('launchApp', {'packageName': packageName});
    } catch (e) {
      print('Error launching app: $e');
      return false;
    }
  }

  Future<bool> checkUsagePermission() async {
    try {
      return await _channel.invokeMethod('checkUsagePermission');
    } catch (e) {
      return false;
    }
  }

  Future<void> requestUsagePermission() async {
    try {
      await _channel.invokeMethod('requestUsagePermission');
    } catch (e) {
      print('Error requesting usage permission: $e');
    }
  }

  Future<void> setLockedApps(List<String> packages) async {
    try {
      await _channel.invokeMethod('setLockedApps', {'packages': packages});
    } catch (e) {
      print('Error syncing locked apps: $e');
    }
  }


  Future<void> saveHiddenApps(List<SystemApp> apps) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(apps.map((e) => e.toMap()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<List<SystemApp>> getHiddenApps() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_storageKey);
    if (encoded == null) return [];
    final List<dynamic> decoded = jsonDecode(encoded);
    return decoded.map((e) => SystemApp.fromMap(e as Map)).toList();
  }

  Future<bool> hideApp(String packageName) async {
    try {
      return await _channel.invokeMethod('hideApp', {'packageName': packageName});
    } catch (e) {
      print('Error hiding app: $e');
      return false;
    }
  }

  Future<bool> unhideApp(String packageName) async {
    try {
      return await _channel.invokeMethod('unhideApp', {'packageName': packageName});
    } catch (e) {
      print('Error unhiding app: $e');
      return false;
    }
  }

  Future<bool> isAppHidden(String packageName) async {
    try {
      return await _channel.invokeMethod('isAppHidden', {'packageName': packageName});
    } catch (e) {
      return false;
    }
  }
}
