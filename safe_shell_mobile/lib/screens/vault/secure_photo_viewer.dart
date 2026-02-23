import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../../services/encryption_service.dart'; 

class SecurePhotoViewer extends StatefulWidget {
  final String encryptedFilePath;

  const SecurePhotoViewer({
    super.key, 
    required this.encryptedFilePath,
  });

  @override
  State<SecurePhotoViewer> createState() => _SecurePhotoViewerState();
}

class _SecurePhotoViewerState extends State<SecurePhotoViewer> {
  String? _tempDecryptedPath;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _decryptAndShow();
  }

  Future<void> _decryptAndShow() async {
    try {
      final tempPath = await EncryptionService.decryptFile(widget.encryptedFilePath);
      
      if (mounted) {
        setState(() {
          _tempDecryptedPath = tempPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_tempDecryptedPath != null) {
      final file = File(_tempDecryptedPath!);
      if (file.existsSync()) {
        file.deleteSync();
        debugPrint('Secure Viewer: Temp file deleted safely. 🗑️');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 50),
          const SizedBox(height: 10),
          Text("Decryption Failed: $_error", 
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_tempDecryptedPath != null) {
      return PhotoView(
        imageProvider: FileImage(File(_tempDecryptedPath!)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
        loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator()),
      );
    }

    return const Text("No file found", style: TextStyle(color: Colors.white));
  }
}
