import 'package:http/http.dart' as http;

Future<void> main() async {
  const baseUrl = 'https://fair-madelin-safeshellmobile-5ea64b9b.koyeb.app/api';
  print('🔍 Diagnosing Live Backend: $baseUrl');

  final client = http.Client();

  try {
    print('\n[1] Testing Health Endpoint...');
    final response = await client.get(Uri.parse('$baseUrl/health'));
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');

    print('\n[2] Testing Auth Ping...');
    final pingRes = await client.get(Uri.parse('$baseUrl/auth/ping'));
    print('Status: ${pingRes.statusCode}');
    print('Body: ${pingRes.body}');

    print('\n[3] Testing Root Message...');
    final rootRes = await client.get(Uri.parse('https://fair-madelin-safeshellmobile-5ea64b9b.koyeb.app/'));
    print('Status: ${rootRes.statusCode}');
    print('Body: ${rootRes.body}');

  } catch (e) {
    print('❌ Error during diagnosis: $e');
  } finally {
    client.close();
  }
}
