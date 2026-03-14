import 'package:dart_firebase_admin/auth.dart';

void main() {
  // Test UpdateRequest (used in BaseAuth.updateUser)
  final request = UpdateRequest(password: 'new_password');
  print('UpdateRequest created: $request');
}
