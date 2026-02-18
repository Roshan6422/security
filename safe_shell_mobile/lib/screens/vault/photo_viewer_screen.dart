import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:safe_shell_mobile/services/api_service.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:http/http.dart' as http;

class PhotoViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const PhotoViewerScreen({super.key, required this.imageUrl, required this.heroTag});

  Future<void> _saveToGallery(BuildContext context) async {
    try {
      final url = '${ApiService.currentBaseUrl.replaceAll('/api', '')}$imageUrl';
      
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading... ⬇️')));
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        
        final AssetEntity? image = await PhotoManager.editor.saveImage(
          bytes,
          filename: 'SafeShell_Export_${DateTime.now().millisecondsSinceEpoch}.jpg',
          title: 'SafeShell_Export_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        if (image != null) {
          if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Gallery! 🖼️✅')));
          }
        } else {
           if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save to gallery')));
        }
      } else {
         if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download failed')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Save to Gallery',
            onPressed: () => _saveToGallery(context),
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: '${ApiService.currentBaseUrl.replaceAll('/api', '')}$imageUrl',
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}
