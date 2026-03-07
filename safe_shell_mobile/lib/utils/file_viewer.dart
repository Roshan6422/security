import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class FileViewer {
  static Future<void> openFile(BuildContext context, String url, String filename) async {
    final fullUrl = '${ApiService.currentBaseUrl.replaceAll('/api', '')}$url';
    
    // For web URL (optional fallback)
    /* 
    if (await canLaunchUrl(Uri.parse(fullUrl))) {
      await launchUrl(Uri.parse(fullUrl));
      return;
    }
    */

    // Download and Open Logic
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.get(Uri.parse(fullUrl), headers: await ApiService.getAuthHeaders());
      
      if (context.mounted) Navigator.pop(context); // Close loader

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final tempEncPath = '${dir.path}/temp_download_${DateTime.now().millisecondsSinceEpoch}.shell';
        final tempEncFile = File(tempEncPath);
        await tempEncFile.writeAsBytes(response.bodyBytes);
        
        // Decrypt
        final decryptedPath = await EncryptionService.decryptFile(tempEncPath);
        
        // Cleanup encrypted
        if (await tempEncFile.exists()) await tempEncFile.delete();

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
