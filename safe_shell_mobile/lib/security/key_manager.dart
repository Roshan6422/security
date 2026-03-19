import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManager {
  static const _kVaultKey = 'vault_key_base64';
  final _storage = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  Future<bool> hasKey() async => (await _storage.read(key: _kVaultKey)) != null;

  Future<String> generateAndStore() async {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final b64 = base64Encode(bytes);
    await _storage.write(key: _kVaultKey, value: b64);
    return b64;
  }

  Future<void> storeManual(String keyB64) async {
    final bytes = base64Decode(keyB64);
    if (bytes.length < 32) throw Exception('Key too short (need 32+ bytes)');
    await _storage.write(key: _kVaultKey, value: keyB64);
  }

  Future<List<int>> readKeyBytes() async {
    final b64 = await _storage.read(key: _kVaultKey);
    if (b64 == null) throw Exception('No key set');
    return base64Decode(b64);
  }

  // Compatibility helpers
  Future<String> generateAndStoreKey() => generateAndStore();
  Future<void> storeManualKey(String b64) => storeManual(b64);
}
