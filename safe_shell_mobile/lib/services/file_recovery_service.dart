import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class FileRecoveryService {
  static const String _recoveryKey = 'legacy_file_recovery_completed_v1';

  /// Scans for .SafeShellCloak and restores files to /SafeShell_Restored
  Future<void> restoreLegacyFiles({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && prefs.getBool(_recoveryKey) == true) {
      if (kDebugMode) debugPrint('FileRecoveryService: Already completed. Skipping.');
      return;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cloakDir = Directory(p.join(appDir.path, '.SafeShellCloak'));

      if (!await cloakDir.exists()) {
        if (kDebugMode) debugPrint('FileRecoveryService: No legacy cloak directory found.');
        await prefs.setBool(_recoveryKey, true);
        return;
      }

      // 1. Request Storage Permissions
      if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
      }

      final restorePath = '/storage/emulated/0/SafeShell_Restored';
      final restoreDir = Directory(restorePath);
      if (!await restoreDir.exists()) {
        await restoreDir.create(recursive: true);
      }

      // 2. Load Metadata
      Map<String, String> metadata = {};
      final metaFile = File(p.join(cloakDir.path, 'cloak_metadata.json'));
      if (await metaFile.exists()) {
        try {
          final content = await metaFile.readAsString();
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          metadata = decoded.map((k, v) => MapEntry(k, v.toString()));
        } catch (e) {
          if (kDebugMode) debugPrint('FileRecoveryService: Meta error: $e');
        }
      }

      // 3. Process Files
      final entities = cloakDir.list();
      int restoredCount = 0;

      await for (var entity in entities) {
        if (entity is File && entity.path.endsWith('.safe_cloak')) {
          try {
            final obfName = p.basename(entity.path);
            String? originalPath = metadata[obfName];
            String destinationPath;

            if (originalPath != null && originalPath.isNotEmpty) {
               final fileName = p.basename(originalPath);
               destinationPath = p.join(restoreDir.path, fileName);
            } else {
              // Fallback to Base64 decode of filename
              final encoded = obfName.replaceAll('.safe_cloak', '');
              try {
                final originalName = utf8.decode(base64Url.decode(encoded));
                destinationPath = p.join(restoreDir.path, originalName);
              } catch (_) {
                destinationPath = p.join(restoreDir.path, obfName.replaceAll('.safe_cloak', '.bin'));
              }
            }

            // Copy to restored folder
            await entity.copy(destinationPath);
            await entity.delete();
            restoredCount++;
          } catch (e) {
            if (kDebugMode) debugPrint('FileRecoveryService: Error restoring ${entity.path}: $e');
          }
        }
      }

      if (kDebugMode) debugPrint('FileRecoveryService: Restored $restoredCount files.');

      // 4. Cleanup and Flag
      if ((await cloakDir.list().isEmpty)) {
        await cloakDir.delete();
      }
      
      await prefs.setBool(_recoveryKey, true);
      
    } catch (e) {
      if (kDebugMode) debugPrint('FileRecoveryService Critical Error: $e');
    }
  }
}
