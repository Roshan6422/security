import 'dart:convert';
import 'dart:io';

void main() {
  try {
    final env = File('backend_dart/.env').readAsStringSync();
    final startMarker = 'FIREBASE_SERVICE_ACCOUNT_BASE64="';
    final start = env.indexOf(startMarker) + startMarker.length;
    final end = env.lastIndexOf('"');
    final b64 = env.substring(start, end).replaceAll(RegExp(r'\s'), '').replaceAll('\\n', '');
    
    final decoded = utf8.decode(base64Decode(b64));
    final Map<String, dynamic> data = jsonDecode(decoded);
    final minified = jsonEncode(data);
    final result = base64Encode(utf8.encode(minified));
    
    print(result);
  } catch (e) {
    print('Error: $e');
  }
}
