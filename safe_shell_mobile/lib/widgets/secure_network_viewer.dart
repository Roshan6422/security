import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import '../services/encryption_service.dart';
import '../services/network_service.dart';

class SecureNetworkViewer extends StatefulWidget {
  final String relativeUrl;
  final String? vaultId;
  final Widget Function(BuildContext context, String localPath) builder;

  const SecureNetworkViewer({
    super.key,
    required this.relativeUrl,
    required this.builder,
    this.vaultId,
  });

  @override
  State<SecureNetworkViewer> createState() => _SecureNetworkViewerState();
}

class _SecureNetworkViewerState extends State<SecureNetworkViewer> with WidgetsBindingObserver {
  String? _localPath;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadContent();
  }

  @override
  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    // Note: In newer Flutter versions, didChangeAppLifecycleState is used.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _secureWipeLocalPath();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _secureWipeLocalPath();
    super.dispose();
  }

  Future<void> _secureWipeLocalPath() async {
    if (_localPath != null) {
      try {
        final f = File(_localPath!);
        if (await f.exists()) {
           // Immediately unlink the plaintext decrypted file from the OS disk
           await f.delete();
        }
      } catch (e) {
        debugPrint('Secure Wiping Failed: $e');
      }
      _localPath = null;
    }
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
      // 1. Check for PERMANENT local vault file first (if vaultId is provided)
      if (widget.vaultId != null) {
        final localVaultPath = await EncryptionService.getLocalVaultPath(widget.vaultId!);
        final localVaultFile = File(localVaultPath);
        if (await localVaultFile.exists()) {
          final decryptedPath = await EncryptionService.decryptFile(localVaultPath);
          if (mounted) {
            setState(() {
              _localPath = decryptedPath;
              _isLoading = false;
            });
          }
          return;
        }
      }

      final cacheDir = await EncryptionService.getDecryptedCacheDir();
      final cacheFilename = _getCacheFilename(widget.relativeUrl);
      final cacheFile = File(p.join(cacheDir.path, cacheFilename));

      // Support both local paths and network URLs
      if (widget.relativeUrl.startsWith('http')) {
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
        final fullUrl = widget.relativeUrl;
        final response = await NetworkService.client.get(Uri.parse(fullUrl));

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

        // 6. IF it was a network download, also save to permanent local vault (for hybrid storage)
        if (widget.vaultId != null) {
          final localVaultPath = await EncryptionService.getLocalVaultPath(widget.vaultId!);
          if (!await File(localVaultPath).exists()) {
            await File(tempEncPath).copy(localVaultPath);
            if (kDebugMode) debugPrint('SecureNetworkViewer: Saved background download to permanent vault: $localVaultPath');
          }
        }

        // 7. Cleanup temp encrypted
        if (await tempEncFile.exists()) await tempEncFile.delete();

        if (mounted) {
          setState(() {
            _localPath = cacheFile.path;
            _isLoading = false;
          });
        }
      } else {
        // It's a local file path
        final decryptedPath = await EncryptionService.decryptFile(widget.relativeUrl);
        if (mounted) {
          setState(() {
            _localPath = decryptedPath;
            _isLoading = false;
          });
        }
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
