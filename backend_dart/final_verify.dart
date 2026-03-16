import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

String _cleanPrivateKey(String key) {
  key = key.replaceAll(r'\\n', '\n');
  key = key.replaceAll(r'\n', '\n');
  key = key.replaceAll(r'\r', '');
  key = key.trim();
  const header = '-----BEGIN PRIVATE KEY-----';
  const footer = '-----END PRIVATE KEY-----';
  if (key.contains(header) && key.contains(footer)) {
    final start = key.indexOf(header) + header.length;
    final end = key.indexOf(footer);
    String content = key.substring(start, end);
    content = content.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
    return '$header\n$content\n$footer';
  }
  return key;
}

void main() {
  final b64 = File('b64_final_v2.txt').readAsStringSync().trim();
  print('b64_final_v2.txt length: ${b64.length}');
  
  final decoded = utf8.decode(base64Decode(b64));
  final json = jsonDecode(decoded) as Map<String, dynamic>;
  print('Fields: ${json.keys.toList()}');
  
  final rawKey = json['private_key'] as String;
  final cleanedKey = _cleanPrivateKey(rawKey);
  
  try {
    final testJwt = JWT({'test': 'diag'});
    testJwt.sign(RSAPrivateKey(cleanedKey), algorithm: JWTAlgorithm.RS256);
    print('✅ b64_final_v2.txt: RSA key is valid!');
  } catch (e) {
    print('❌ b64_final_v2.txt: FAILED! Error: $e');
  }
}
