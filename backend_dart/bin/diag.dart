import 'package:dotenv/dotenv.dart';
import 'package:backend_dart/config/firebase.dart';
import 'package:backend_dart/config/env.dart';

Future<void> main() async {
  print('Step 1: Loading .env...');
  try {
    env.load();
    print('✅ .env loaded');
  } catch (e) {
    print('❌ .env load failed: $e');
  }

  print('Step 2: Env verification...');
  print('PORT: ${Env.port}');
  print('Firebase Base64 exists: ${Env.firebaseServiceAccountBase64 != null}');

  print('Step 3: Initializing Firebase...');
  try {
    await FirebaseConfig.initialize().timeout(Duration(seconds: 10));
    print('✅ Firebase result: ${FirebaseConfig.isInitialized ? 'Connected' : 'In-Memory'}');
  } catch (e) {
    print('❌ Firebase init failed or timed out: $e');
  }

  print('Done.');
}
