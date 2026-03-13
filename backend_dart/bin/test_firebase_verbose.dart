import 'dart:convert';
import 'dart:io';
import 'package:backend_dart/config/firebase.dart';
import 'package:backend_dart/config/env.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  print('--- Firebase Verbose Test Script ---');
  try {
    env.load();
  } catch (e) {
    print('Error loading .env: $e');
  }

  print('Attempting FirebaseConfig.initialize()...');
  try {
    await FirebaseConfig.initialize();
  } catch (e) {
    print('CRITICAL ERROR in initialize(): $e');
  }

  if (FirebaseConfig.isInitialized) {
    print('✅ SUCCESS: Firebase is initialized and reachable.');
    exit(0);
  } else {
    print('❌ FAILURE: Firebase initialization failed.');
    print('Check the logs above for specific "❌" or "⚠️" markers.');
    exit(1);
  }
}
