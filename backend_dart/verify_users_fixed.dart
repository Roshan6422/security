import 'dart:io';
import 'package:backend_dart/config/env.dart';
import 'package:backend_dart/config/firebase.dart';

Future<void> main() async {
  env.load();
  print('Initializing Firebase for safeshell-app...');
  await FirebaseConfig.initialize();
  
  if (!FirebaseConfig.isInitialized) {
    print('Firebase not initialized.');
    exit(1);
  }
  
  final docs = await FirebaseConfig.db!.collection('users').get();
  print('--- Users in safeshell-app project ---');
  print('Total users found: ${docs.docs.length}');
  for (final doc in docs.docs) {
    print('Email: ${doc.data['email']}, Role: ${doc.data['role']}');
  }
  print('--------------------------------------');
  exit(0);
}
