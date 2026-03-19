import 'package:flutter/material.dart';
import '../services/encryption_service.dart';
import 'package:open_filex/open_filex.dart';
import '../services/network_service.dart';
import 'dart:io';

class FileViewer {
  static Future<void> openFile(BuildContext context, String url, String filename, {String? vaultId}) async {
    final fullUrl = url;
    
    // For web URL (optional fallback)
    /* 
    if (await canLaunchUrl(Uri.parse(fullUrl))) {
      await launchUrl(Uri.parse(fullUrl));
      return;
    }
    */

    // Download and Open Logic
    try {
      // 1. Check for PERMANENT local vault file first
      if (vaultId != null) {
        final localVaultPath = await EncryptionService.getLocalVaultPath(vaultId);
        final localVaultFile = File(localVaultPath);
        if (await localVaultFile.exists()) {
          final decryptedPath = await EncryptionService.decryptFile(localVaultPath);
          final result = await OpenFilex.open(decryptedPath);
          if (result.type != ResultType.done && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open local file: ${result.message}')));
          }
          return;
        }
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final response = await NetworkService.client.get(Uri.parse(fullUrl));
      
      if (context.mounted) Navigator.pop(context); // Close loader

      if (response.statusCode == 200) {
        final cacheDir = await EncryptionService.getDecryptedCacheDir();
        final tempEncPath = '${cacheDir.path}/temp_download_${DateTime.now().millisecondsSinceEpoch}.shell';
        final tempEncFile = File(tempEncPath);
        await tempEncFile.writeAsBytes(response.bodyBytes);
        
        // Decrypt
        final decryptedPath = await EncryptionService.decryptFile(tempEncPath);
        
        // Cleanup encrypted
        if (await tempEncFile.exists()) {
           // Also save to permanent local vault (for hybrid storage)
          if (vaultId != null) {
            final localVaultPath = await EncryptionService.getLocalVaultPath(vaultId);
            if (!await File(localVaultPath).exists()) {
               await tempEncFile.copy(localVaultPath);
            }
          }
          await tempEncFile.delete();
        }

        final result = await OpenFilex.open(decryptedPath);
        if (result.type != ResultType.done) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open file: ${result.message}')));
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: ${response.statusCode}')));
        }
      }
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) Navigator.pop(context); // Close loader if error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
