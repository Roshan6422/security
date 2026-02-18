import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/encryption_service.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalCloakScreen extends StatefulWidget {
  const LocalCloakScreen({super.key});

  @override
  State<LocalCloakScreen> createState() => _LocalCloakScreenState();
}

class _LocalCloakScreenState extends State<LocalCloakScreen> {
  List<File> _mediaFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scanMedia();
  }

  Future<void> _scanMedia() async {
    setState(() => _isLoading = true);
    final List<File> files = [];
    final List<String> targetDirs = [
      '/storage/emulated/0/DCIM/Camera',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/Movies',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
    ];

    try {
      // 1. Check permissions first
      if (await Permission.storage.isDenied) {
        if (await Permission.storage.request().isDenied) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      // 2. Scan folders
      for (var path in targetDirs) {
        final dir = Directory(path);
        if (await dir.exists()) {
          final List<FileSystemEntity> entities = dir.listSync(recursive: false);
          for (var entity in entities) {
            if (entity is File) {
              final ext = entity.path.toLowerCase();
              if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || 
                  ext.endsWith('.png') || ext.endsWith('.mp4') || 
                  ext.endsWith('.mov') || ext.endsWith('.pdf') ||
                  ext.endsWith('.docx') || ext.endsWith('.txt')) {
                files.add(entity);
              }
            }
          }
        }
      }
      
      // Sort by date modified (newest first)
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      if (mounted) {
        setState(() {
          _mediaFiles = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error scanning files: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Local Cloak Gallery'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _scanMedia),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _mediaFiles.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _mediaFiles.length,
              itemBuilder: (context, index) {
                final file = _mediaFiles[index];
                final ext = file.path.toLowerCase();
                final isVideo = ext.endsWith('.mp4') || ext.endsWith('.mov');
                final isDoc = ext.endsWith('.pdf') || ext.endsWith('.docx') || ext.endsWith('.txt');
                
                return GestureDetector(
                  onTap: () => _viewFile(file),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (isDoc)
                          Container(
                            color: Colors.white10,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  ext.endsWith('.pdf') ? Icons.picture_as_pdf : Icons.description,
                                  color: ext.endsWith('.pdf') ? Colors.redAccent : AppColors.primary,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  file.path.split('/').last,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                              ],
                            ),
                          )
                        else
                          Image.file(file, fit: BoxFit.cover, 
                            errorBuilder: (ctx, e, s) => Container(
                              color: Colors.white10,
                              child: Icon(isVideo ? Icons.videocam : Icons.image, color: Colors.white24),
                            ),
                          ),
                        if (isVideo)
                          const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 32)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility_off_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('No media found in cloaked folders', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          const Text('Enable Local Cloak in Settings', style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  void _viewFile(File file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(file.path.split('/').last, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.security, color: AppColors.primary),
              title: const Text('Move to Secure Vault', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Encrypt and hide permanently (Phone original will be deleted)', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _moveToVault(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Colors.white70),
              title: const Text('Open with System App', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // In a real app we'd use open_file or similar
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening...')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveToVault(File file) async {
    setState(() => _isLoading = true);
    try {
      // 1. Encrypt and move
      await EncryptionService.encryptFile(file.path);
      
      // 2. Delete original
      await file.delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File secured and moved to Vault!'), backgroundColor: Colors.green),
        );
        _scanMedia(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error moving file: $e')));
      }
    }
  }
}
