import 'dart:io';
import 'package:dart_firebase_admin/firestore.dart';
import 'package:backend_dart/config/env.dart';
import 'package:backend_dart/config/firebase.dart';

Future<void> main() async {
  env.load();
  await FirebaseConfig.initialize();
  
  print('Connected to Firestore');
  final snapshot = await FirebaseConfig.db!.collection('users').get();
  final out = StringBuffer();
  out.writeln('Found ${snapshot.docs.length} users');
  
  for (final doc in snapshot.docs) {
    final data = doc.data();
    out.writeln('${doc.id} | email=${data['email']} | name=${data['name']}');
  }

  File('users_out.txt').writeAsStringSync(out.toString());
  print('Done typing to users_out.txt');

  exit(0);
}
