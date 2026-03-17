import 'dart:io';
import 'package:backend_dart/config/env.dart';
import 'package:backend_dart/config/firebase.dart';

Future<void> main() async {
  env.load();
  print('Initializing Firebase with PROJECT: safeshell-app...');
  await FirebaseConfig.initialize().timeout(Duration(seconds: 15), onTimeout: () {
    print('Firebase initialization timed out!');
    exit(1);
  });
  
  if (!FirebaseConfig.isInitialized) {
    print('Firebase failed to initialize.');
    exit(1);
  }
  
  print('Firebase connected successfully.');
  final docs = await FirebaseConfig.db!.collection('users').get().timeout(Duration(seconds: 10), onTimeout: () {
    print('Firestore get timed out!');
    exit(1);
  });
  
  print('Found ${docs.docs.length} users in Firestore.');
  for (final doc in docs.docs) {
    print('User: ${doc.data['email']} (Role: ${doc.data['role']})');
  }
  exit(0);
}
