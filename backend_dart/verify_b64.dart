import 'dart:convert';
import 'dart:io';

void main() {
  try {
    final b64 = File('b64_utf8.txt').readAsStringSync().trim();
    print('Base64 Length: ${b64.length}');
    
    final decodedBytes = base64Decode(b64);
    print('Decoded Bytes Length: ${decodedBytes.length}');
    
    final decodedJson = utf8.decode(decodedBytes);
    print('✅ Decoded JSON is valid UTF-8. Length: ${decodedJson.length}');
    
    final json = jsonDecode(decodedJson);
    print('✅ JSON is valid. Project: ${json['project_id']}');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
