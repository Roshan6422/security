import 'dart:io';
import 'package:backend_dart/config/env.dart';
import 'package:backend_dart/config/firebase.dart';

Future<void> main() async {
  env.load();
  await FirebaseConfig.initialize();
  if (!FirebaseConfig.isInitialized) {
    print('Firebase not initialized');
    exit(1);
  }
  final docs = await FirebaseConfig.db!.collection('users').get();
  print('--- Current Users in Firestore ---');
  for (final doc in docs.docs) {
    print('ID: ${doc.id}, Data: ${doc.data}');
  }
  print('----------------------------------');
  exit(0);
}
