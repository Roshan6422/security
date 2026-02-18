import 'dart:convert';
import 'package:http/http.dart' as http;

const baseUrl = 'http://localhost:8000/api';

Future<void> main() async {
  print('🧪 Starting Integration Test...');
  final client = http.Client();

  // 1. Health Check
  try {
    final healthRes = await client.get(Uri.parse('$baseUrl/health'));
    if (healthRes.statusCode == 200) {
      print('✅ Health Check Passed: ${healthRes.body}');
    } else {
      print('❌ Health Check Failed: ${healthRes.statusCode}');
      return;
    }
  } catch (e) {
    print('❌ Health Check Exception: $e');
    return;
  }

  // 2. Register
  String token = '';
  final email = 'test${DateTime.now().millisecondsSinceEpoch}@example.com';
  final password = 'password123';
  String userId = '';

  try {
    print('🔹 Registering user: $email');
    final regRes = await client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'name': 'Test User'}),
    );

    if (regRes.statusCode == 201) {
      final body = jsonDecode(regRes.body);
      token = body['token'];
      userId = body['_id']; // Response is flat, not nested
      print('✅ Register Passed. Token received. User ID: $userId');
    } else {
      print('❌ Register Failed: ${regRes.statusCode} ${regRes.body}');
      return;
    }
  } catch (e) {
    print('❌ Register Exception: $e');
    return;
  }

  // 3. Login (verify token works)
  try {
    print('🔹 Verifying protected route /auth/me');
    final meRes = await client.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (meRes.statusCode == 200) {
      print('✅ Auth Check Passed: ${meRes.body}');
    } else {
      print('❌ Auth Check Failed: ${meRes.statusCode} ${meRes.body}');
    }
  } catch (e) {
    print('❌ Auth Check Exception: $e');
  }

  // 4. Create Vault Item
  try {
    print('🔹 Creating Vault Key');
    final vaultRes = await client.post(
      Uri.parse('$baseUrl/vault/create'),
      headers: {
        'content-type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({
        'name': 'My Secret',
        'content': 'Secret Data',
        'type': 'note'
      }),
    );

    if (vaultRes.statusCode == 201) {
      print('✅ Vault Create Passed: ${vaultRes.body}');
    } else {
      print('❌ Vault Create Failed: ${vaultRes.statusCode} ${vaultRes.body}');
    }
  } catch (e) {
    print('❌ Vault Create Exception: $e');
  }
  
  // 5. List Vault Items
  try {
     print('🔹 Listing Vault Items');
     final listRes = await client.get(
        Uri.parse('$baseUrl/vault/items'),
        headers: {'Authorization': 'Bearer $token'},
     );
     
     if (listRes.statusCode == 200) {
        final List items = jsonDecode(listRes.body);
        print('✅ Vault List Passed. Count: ${items.length}');
     } else {
        print('❌ Vault List Failed: ${listRes.statusCode}');
     }
  } catch (e) {
     print('❌ Vault List Exception: $e');
  }

  client.close();
  print('🏁 Integration Test Complete');
}
