import 'dart:io';
import 'dart:convert';
import 'package:backend_dart/config/env.dart';
import 'package:backend_dart/config/firebase.dart';
import 'package:googleapis_auth/auth_io.dart';

void main() async {
  env.load();
  await FirebaseConfig.initialize();

  try {
    print('Listing buckets...');
    final serviceAccount = FirebaseConfig.serviceAccount!;
    final projectId = serviceAccount['project_id'];
    final client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(serviceAccount),
      ['https://www.googleapis.com/auth/devstorage.read_write', 'https://www.googleapis.com/auth/cloud-platform'],
    );
    
    var url = 'https://storage.googleapis.com/storage/v1/b?project=$projectId';
    print('Requesting $url');
    var response = await client.get(Uri.parse(url));

    print('Response ${response.statusCode}: ${response.body}');
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final items = json['items'] as List<dynamic>?;
      if (items != null) {
        for (var item in items) {
          print('Bucket found: ${item['name']}');
        }
      } else {
        print('No buckets found.');
      }
    }

  } catch (e) {
    print('Failed: $e');
  } finally {
    exit(0);
  }
}
