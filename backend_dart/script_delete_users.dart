import 'dart:io';
import 'package:backend_dart/config/env.dart';
import 'package:backend_dart/config/firebase.dart';

Future<void> main() async {
  print('Starting user wipe script using Backend Config...');
  env.load();
  
  await FirebaseConfig.initialize();
  
  if (!FirebaseConfig.isInitialized) {
    print('Failed to initialize Firebase! Exiting.');
    exit(1);
  }

  try {
    final firestore = FirebaseConfig.db!;
    final auth = FirebaseConfig.auth!;
    
    print('Fetching Firestore users...');
    final docs = await firestore.collection('users').get();
    print('Found ${docs.docs.length} users in Firestore.');
    for (final doc in docs.docs) {
      await doc.ref.delete();
      print('Deleted Firestore doc: ${doc.id}');
    }

    print('Fetching Firebase Auth users...');
    final listUsersResult = await auth.listUsers();
    final authUsers = listUsersResult.users;
    print('Found ${authUsers.length} users in Firebase Auth.');
    for (final user in authUsers) {
      await auth.deleteUser(user.uid);
      print('Deleted Auth user: ${user.uid} (${user.email})');
    }

    print('Successfully wiped all users from Firestore and Firebase Auth.');
    exit(0);
  } catch (e, stack) {
    print('Error during deletion: $e\n$stack');
    exit(1);
  }
}