import 'dart:convert';
import 'dart:io';

void main() {
  try {
    final b64 = File('b64_minified.txt').readAsStringSync().trim();
    print('Base64 Length: ${b64.length}');
    
    final decodedBytes = base64Decode(b64);
    final decodedStr = utf8.decode(decodedBytes);
    
    print('Decoded String:');
    print(decodedStr);
    
    final json = jsonDecode(decodedStr);
    print('\n✅ Success: JSON is perfectly valid.');
    print('Project ID: ${json['project_id']}');
    print('Private Key Length: ${json['private_key'].length}');
    
  } catch (e) {
    print('❌ Syntax Error found: $e');
  }
}
