import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  bool _localCloakEnabled = false;
  int _autoLockSeconds = 0; // 0 = disabled
  bool _isPro = false; // Default to false, can be enabled later

  bool get localCloakEnabled => _localCloakEnabled;
  int get autoLockSeconds => _autoLockSeconds;
  bool get isPro => _isPro;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final saved = await _storage.read(key: 'local_cloak_enabled');
    _localCloakEnabled = saved == 'true';

    final lockStr = await _storage.read(key: 'auto_lock_seconds');
    _autoLockSeconds = int.tryParse(lockStr ?? '0') ?? 0;

    notifyListeners();
  }

  Future<void> toggleLocalCloak(bool value) async {
    _localCloakEnabled = value;
    await _storage.write(key: 'local_cloak_enabled', value: value.toString());
    notifyListeners();
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    _autoLockSeconds = seconds;
    await _storage.write(key: 'auto_lock_seconds', value: seconds.toString());
    notifyListeners();
  }
}
