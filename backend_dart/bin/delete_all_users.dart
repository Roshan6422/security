import 'dart:io';
import 'package:backend_dart/config/firebase.dart';
import 'package:backend_dart/config/env.dart';

void main() async {
  print('🛑 CRITICAL: DELETING ALL USERS 🛑');
  try {
    env.load();
  } catch (_) {}

  await FirebaseConfig.initialize();

  if (!FirebaseConfig.isInitialized) {
    print('FAILURE: Failed to initialize Firebase. Aborting.');
    exit(1);
  }

  final auth = FirebaseConfig.auth!;
  final db = FirebaseConfig.db!;

  print('--- Phase 1: Cleaning up Firebase Auth ---');
  try {
    final listResult = await auth.listUsers();
    final users = listResult.users;

    print('Found ${users.length} users in Auth.');

    for (final user in users) {
      print('Deleting user from Auth: ${user.email} (${user.uid})');
      try {
        await auth.deleteUser(user.uid);
      } catch (e) {
        print('Failed to delete user ${user.uid} from Auth: $e');
      }
    }
  } catch (e) {
    print('Error listing/deleting users from Auth: $e');
  }

  print('\n--- Phase 2: Cleaning up Firestore collections ---');
  final collections = [
    'users', 
    'vaultItems', 
    'payments', 
    'supportTickets', 
    'devices'
  ];

  for (final collectionName in collections) {
    print('Emptying collection: $collectionName');
    try {
      final collection = db.collection(collectionName);
      final snapshot = await collection.get();
      print('Found ${snapshot.docs.length} documents in $collectionName');
      
      for (final doc in snapshot.docs) {
        print('Deleting doc ${doc.id} from $collectionName');
        await doc.ref.delete();
      }
    } catch (e) {
      print('Error cleaning collection $collectionName: $e');
    }
  }

  print('\n✅ SUCCESS: All users and associated data deleted.');
  exit(0);
}
