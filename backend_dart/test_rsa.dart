import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

String _cleanPrivateKey(String key) {
  if (key.isEmpty) return key;

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
  final file = File(r'c:\Users\Roshan\AppData\Local\Temp\safeshell_sa.json');
  final content = file.readAsStringSync();
  final json = jsonDecode(content);
  final rawKey = json['private_key'];
  
  final superMinified = {
    'type': 'service_account',
    'project_id': json['project_id'],
    'client_email': json['client_email'],
    'private_key': rawKey,
  };
  
  final minifiedJson = jsonEncode(superMinified);
  final b64 = base64Encode(utf8.encode(minifiedJson));
  
  // Re-decode
  final decodedJson = jsonDecode(utf8.decode(base64Decode(b64)));
  final extractedRawKey = decodedJson['private_key'];
  
  print('Raw Key Match: ${rawKey == extractedRawKey}');
  
  final cleanedKey = _cleanPrivateKey(extractedRawKey);
  
  try {
    final testJwt = JWT({'test': 'diag'});
    testJwt.sign(RSAPrivateKey(cleanedKey), algorithm: JWTAlgorithm.RS256);
    print('✅ Valid RSA PEM string.');
  } catch (e) {
    print('❌ Invalid RSA string: $e');
  }
  File('b64_final.txt').writeAsStringSync(b64);
  print('Final length: ${b64.length}');
}
