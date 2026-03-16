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
  
  // Include all fields required by dart_firebase_admin
  final minified = {
    'type': 'service_account',
    'project_id': json['project_id'],
    'client_email': json['client_email'],
    'client_id': json['client_id'], // Added client_id
    'private_key': json['private_key'],
  };
  
  final jsonString = jsonEncode(minified);
  final base64 = base64Encode(utf8.encode(jsonString));
  
  File('b64_final_v2.txt').writeAsStringSync(base64);
  print('Done. Final V2 Base64 written to b64_final_v2.txt');
  print('Base64 length: ${base64.length}');
  
  // Verify it decodes and parses
  final decoded = utf8.decode(base64Decode(base64));
  final parsed = jsonDecode(decoded);
  print('Verification: Type=${parsed['type']}, Project=${parsed['project_id']}, ClientID=${parsed['client_id']}');
}
