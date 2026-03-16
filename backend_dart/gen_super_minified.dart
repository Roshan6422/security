import 'dart:convert';
import 'dart:io';

void main() {
  final file = File(r'c:\Users\Roshan\AppData\Local\Temp\safeshell_sa.json');
  if (!file.existsSync()) {
    print('File not found');
    return;
  }
  final content = file.readAsStringSync();
  final Map<String, dynamic> json = jsonDecode(content);
  
  // Keep ONLY essential fields for Firebase Admin SDK
  final superMinified = {
    'project_id': json['project_id'],
    'client_email': json['client_email'],
    'private_key': json['private_key'],
  };
  
  final jsonString = jsonEncode(superMinified);
  final base64 = base64Encode(utf8.encode(jsonString));
  
  File('b64_super_minified.txt').writeAsStringSync(base64);
  print('Done. Super Minified Base64 written to b64_super_minified.txt');
  print('Original length: ${content.length}');
  print('Super Minified length: ${jsonString.length}');
  print('Base64 length: ${base64.length}');
  
  // Verify it works
  final decoded = utf8.decode(base64Decode(base64));
  jsonDecode(decoded);
  print('Verification successful.');
}
