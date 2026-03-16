import 'dart:convert';
import 'dart:io';

// We import this just to check if the key is valid locally
// Note: You might need to run 'dart pub get' first
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

void main() async {
  print('--- SafeShell Firebase Key Generator (v2) ---');
  print('This script will generate a Base64 string and VERIFY your key locally.\n');
  
  final file = File('service-account.json');
  if (!file.existsSync()) {
    print('❌ ERROR: "service-account.json" not found.');
    print('Download your key from Firebase Console -> Project Settings -> Service Accounts -> Generate Private Key.');
    print('Rename the downloaded file to "service-account.json" and put it in this folder.');
    return;
  }

  try {
    final content = await file.readAsString();
    final json = jsonDecode(content);
    
    final privateKey = json['private_key'];
    if (privateKey == null) {
      print('❌ ERROR: Missing "private_key" in JSON.');
      return;
    }

    print('⏳ Verifying RSA key integrity locally...');
    try {
      final testJwt = JWT({'test': 'verify'});
      testJwt.sign(RSAPrivateKey(privateKey), algorithm: JWTAlgorithm.RS256);
      print('✅ RSA INTEGRITY VERIFIED: Your local key is mathematically valid.');
      
      final cleanedKey = privateKey.toString().replaceAll(RegExp(r'-----.*-----|\s'), '');
      print('\n--- KEY STATISTICS ---');
      print('Private Key Field Length: ${privateKey.toString().length}');
      print('Base64 Content Length:   ${cleanedKey.length}');
      print('----------------------\n');
      
    } catch (e) {
      print('❌ RSA VERIFICATION FAILED: $e');
      print('\nThis key is mathematically invalid (e.g. truncated or manually edited).');
      print('Please generate a FRESH key from the Firebase Console.');
      return;
    }
    
    // Encode to Base64
    final base64String = base64Encode(utf8.encode(content));
    
    // Write to a file instead of just printing (avoid terminal truncation)
    final outputFile = File('base64_key.txt');
    await outputFile.writeAsString(base64String);
    
    print('\n🎉 SUCCESS!');
    print('The perfect Base64 string has been saved to: base64_key.txt');
    print('\nSTEPS:');
    print('1. Open "base64_key.txt" in your editor.');
    print('2. Copy the entire contents (it is one very long line).');
    print('3. Paste it into the Koyeb variable: FIREBASE_SERVICE_ACCOUNT_BASE64');
    
  } catch (e) {
    print('❌ ERROR: $e');
  }
}
