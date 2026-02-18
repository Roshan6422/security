import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  bool _localCloakEnabled = false;

  bool get localCloakEnabled => _localCloakEnabled;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final saved = await _storage.read(key: 'local_cloak_enabled');
    _localCloakEnabled = saved == 'true';
    notifyListeners();
  }

  Future<void> toggleLocalCloak(bool value) async {
    _localCloakEnabled = value;
    await _storage.write(key: 'local_cloak_enabled', value: value.toString());
    notifyListeners();
  }
}
