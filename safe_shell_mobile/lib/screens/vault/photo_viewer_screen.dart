import 'dart:io';
import 'package:flutter/material.dart';
import '../../widgets/secure_network_viewer.dart';
import 'package:photo_view/photo_view.dart';

class PhotoViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final String? vaultId;

  const PhotoViewerScreen({
    super.key, 
    required this.imageUrl, 
    required this.heroTag,
    this.vaultId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: SecureNetworkViewer(
            relativeUrl: imageUrl,
            vaultId: vaultId,
            builder: (context, localPath) => PhotoView(
              imageProvider: FileImage(File(localPath)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
        ),
      ),
    );
  }
}
