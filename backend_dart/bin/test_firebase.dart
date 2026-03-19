import 'dart:io';
import 'package:backend_dart/config/firebase.dart';
import 'package:backend_dart/config/env.dart';

void main() async {
  print('--- Firebase Test Script ---');
  try {
    env.load();
  } catch (_) {}

  await FirebaseConfig.initialize();

  if (FirebaseConfig.isInitialized) {
    print('SUCCESS: Firebase is initialized and reachable.');
    exit(0);
  } else {
    print('FAILURE: Firebase initialization failed or fell back to in-memory.');
    exit(1);
  }
}
