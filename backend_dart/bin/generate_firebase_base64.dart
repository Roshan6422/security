import 'dart:convert';
import 'dart:io';

void main() async {
  print('--- SafeShell Firebase Key Generator ---');
  print('This script will help you generate the correct Base64 string for your Koyeb environment.');
  
  final file = File('service-account.json');
  if (!file.existsSync()) {
    print('❌ ERROR: "service-account.json" not found in the current directory.');
    print('Please download your service account key from Firebase Console and rename it to "service-account.json".');
    return;
  }

  try {
    final content = await file.readAsString();
    // Validate JSON
    final json = jsonDecode(content);
    if (json['private_key'] == null) {
      print('❌ ERROR: The JSON file does not appear to be a valid service account key (missing private_key).');
      return;
    }

    print('✅ JSON validated.');
    
    // Encode to Base64 (compact, no newlines)
    final base64String = base64Encode(utf8.encode(content));
    
    print('\n--- YOUR BASE64 STRING (Copy the entire line below) ---\n');
    print(base64String);
    print('\n----------------------------------------------------\n');
    print('Paste this value into your Koyeb ENVIRONMENT VARIABLE:');
    print('Name: FIREBASE_SERVICE_ACCOUNT_BASE64');
    
  } catch (e) {
    print('❌ ERROR: Failed to process the file: $e');
  }
}
