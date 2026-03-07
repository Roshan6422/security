import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';

class SecureNetworkViewer extends StatefulWidget {
  final String relativeUrl;
  final Widget Function(BuildContext context, String localPath) builder;
  final Widget? loadingWidget;
  final Widget Function(BuildContext context, dynamic error)? errorBuilder;

  const SecureNetworkViewer({
    super.key,
    required this.relativeUrl,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
  });

  @override
  State<SecureNetworkViewer> createState() => _SecureNetworkViewerState();
}

class _SecureNetworkViewerState extends State<SecureNetworkViewer> {
  String? _decryptedLocalPath;
  bool _isLoading = true;
  dynamic _error;

  @override
  void initState() {
    super.initState();
    _downloadAndDecrypt();
  }

  Future<void> _downloadAndDecrypt() async {
    try {
      final baseUrl = ApiService.currentBaseUrl.replaceAll('/api', '');
      final fullUrl = '$baseUrl${widget.relativeUrl}';
      
      // 1. Download the encrypted file
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      // 2. Save to a temporary encrypted file
      final tempDir = await getTemporaryDirectory();
      final tempEncPath = '${tempDir.path}/temp_enc_${DateTime.now().millisecondsSinceEpoch}.shell';
      final tempEncFile = File(tempEncPath);
      await tempEncFile.writeAsBytes(response.bodyBytes);

      // 3. Decrypt the file
      final decryptedPath = await EncryptionService.decryptFile(tempEncPath);

      // 4. Cleanup encrypted temp file
      if (await tempEncFile.exists()) {
        await tempEncFile.delete();
      }

      if (mounted) {
        setState(() {
          _decryptedLocalPath = decryptedPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('SecureNetworkViewer: Error: $e');
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // 5. Cleanup decrypted temp file
    if (_decryptedLocalPath != null) {
      final file = File(_decryptedLocalPath!);
      if (file.existsSync()) {
        file.deleteSync();
        debugPrint('SecureNetworkViewer: Temp decrypted file deleted.');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ?? const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return widget.errorBuilder?.call(context, _error) ??
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Failed to load secure content: $_error', textAlign: TextAlign.center),
              ],
            ),
          );
    }

    if (_decryptedLocalPath != null) {
      return widget.builder(context, _decryptedLocalPath!);
    }

    return const Center(child: Text('Unknown state'));
  }
}
