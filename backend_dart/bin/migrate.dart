import 'dart:io';

import 'package:backend_dart/config/env.dart';
import 'package:backend_dart/config/firebase.dart';

String _detectType(String filename) {
  final cleanName = filename.toLowerCase().endsWith('.shell')
      ? filename.substring(0, filename.length - 6)
      : filename;
  final ext = cleanName.split('.').last.toLowerCase();
  const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'tiff', 'ico'};
  const videoExts = {'mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm', '3gp', 'm4v'};
  const audioExts = {'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma'};
  const docExts = {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'csv', 'md'};
  const zipExts = {'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz'};

  if (imageExts.contains(ext)) return 'photo';
  if (videoExts.contains(ext)) return 'video';
  if (audioExts.contains(ext)) return 'audio';
  if (docExts.contains(ext)) return 'document';
  if (zipExts.contains(ext)) return 'zip';
  return 'document';
}

Future<void> main() async {
  env.load();
  await FirebaseConfig.initialize();
  
  print('Connected to Firestore');
  
  final snapshot = await FirebaseConfig.db!.collection('vaultItems').get();
  int fixed = 0;
  
  for (final doc in snapshot.docs) {
    final data = doc.data();
    final currentType = data['type'] as String?;
    final name = data['name'] as String;
    final correctType = _detectType(name);
    
    if (currentType != correctType) {
      print('Fixing $name: $currentType -> $correctType');
      await doc.ref.update({'type': correctType});
      fixed++;
    }
  }

  print('Migration complete. Fixed $fixed items.');
  exit(0);
}
