import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';

class SecureNetworkViewer extends StatefulWidget {
  final String relativeUrl;
  final Widget Function(BuildContext context, String localPath) builder;

  const SecureNetworkViewer({
    super.key,
    required this.relativeUrl,
    required this.builder,
  });

  @override
  State<SecureNetworkViewer> createState() => _SecureNetworkViewerState();
}

class _SecureNetworkViewerState extends State<SecureNetworkViewer> {
  String? _localPath;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void didUpdateWidget(SecureNetworkViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relativeUrl != widget.relativeUrl) {
      _loadContent();
    }
  }

  String _getCacheFilename(String url) {
    return sha256.convert(utf8.encode(url)).toString();
  }

  Future<void> _loadContent() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cacheDir = await EncryptionService.getDecryptedCacheDir();
      final cacheFilename = _getCacheFilename(widget.relativeUrl);
      final cacheFile = File(p.join(cacheDir.path, cacheFilename));

      // 1. Serve from cache if available
      if (await cacheFile.exists()) {
        if (mounted) {
          setState(() {
            _localPath = cacheFile.path;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Download encrypted file
      final baseUrl = ApiService.currentBaseUrl.replaceAll('/api', '');
      final fullUrl = '$baseUrl${widget.relativeUrl}';

      final response = await http.get(
        Uri.parse(fullUrl),
        headers: await ApiService.getAuthHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      // 3. Save temp encrypted file
      final tempEncPath = p.join(cacheDir.path, 'temp_${DateTime.now().millisecondsSinceEpoch}.enc');
      final tempEncFile = File(tempEncPath);
      await tempEncFile.writeAsBytes(response.bodyBytes);

      // 4. Decrypt
      final decryptedPath = await EncryptionService.decryptFile(tempEncPath);
      final decryptedFile = File(decryptedPath);

      // 5. Move decrypted file to stable cache path
      await decryptedFile.rename(cacheFile.path);

      // 6. Cleanup temp encrypted
      if (await tempEncFile.exists()) await tempEncFile.delete();

      if (mounted) {
        setState(() {
          _localPath = cacheFile.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('SecureNetworkViewer: Error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load secure content:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_localPath != null) {
      return widget.builder(context, _localPath!);
    }

    return const Center(child: Text('Unknown state'));
  }
}
