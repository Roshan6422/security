import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  int _autoLockSeconds = 0; // 0 = disabled
  bool _isPro = false; // Default to false, can be enabled later

  int get autoLockSeconds => _autoLockSeconds;
  bool get isPro => _isPro;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lockStr = await _storage.read(key: 'auto_lock_seconds');
    _autoLockSeconds = int.tryParse(lockStr ?? '0') ?? 0;

    notifyListeners();
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    _autoLockSeconds = seconds;
    await _storage.write(key: 'auto_lock_seconds', value: seconds.toString());
    notifyListeners();
  }
}
