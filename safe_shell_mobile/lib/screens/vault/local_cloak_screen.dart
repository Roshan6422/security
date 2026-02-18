import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
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
  final _storage = const FlutterSecureStorage();
  final String _cloakDirPath = '/storage/emulated/0/.SafeShellCloak';
  List<File> _mediaFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initCloakDir();
    _scanMedia();
  }

  Future<void> _initCloakDir() async {
    try {
      final dir = Directory(_cloakDirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      // Ensure .nomedia exists to keep hidden from system gallery
      final noMedia = File(p.join(_cloakDirPath, '.nomedia'));
      if (!await noMedia.exists()) {
        await noMedia.create();
      }
    } catch (e) {
      debugPrint('Error initializing cloak dir: $e');
    }
  }

  Future<void> _scanMedia() async {
    setState(() => _isLoading = true);
    final List<File> files = [];
    final List<String> targetDirs = [
      _cloakDirPath, // Include our hidden manual storage
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
      if (await Permission.storage.isDenied && !Platform.isAndroid) {
        // ... handled below for MANAGE_EXTERNAL_STORAGE mostly 
      }
      
      // We assume MANAGE_EXTERNAL_STORAGE is granted if we are here (as per previous tasks)
      // but let's be safe.
      
      // 2. Scan folders
      for (var path in targetDirs) {
        final dir = Directory(path);
        if (await dir.exists()) {
          final List<FileSystemEntity> entities = dir.listSync(recursive: false);
          for (var entity in entities) {
            if (entity is File) {
              final ext = entity.path.toLowerCase();
              if (ext.startsWith('.')) continue; // Skip hidden files like .nomedia
              
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
                final isManuallyCloaked = file.path.startsWith(_cloakDirPath);
                
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
                        if (isManuallyCloaked)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                              child: const Icon(Icons.visibility_off, size: 12, color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndCloakFile,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_photo_alternate, color: Colors.white),
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
          const Text('Add files manually or enable in Settings', style: TextStyle(color: Colors.white24, fontSize: 12)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickAndCloakFile,
            icon: const Icon(Icons.add),
            label: const Text('Add File to Cloak'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.1), foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  void _viewFile(File file) {
    final bool isManuallyCloaked = file.path.startsWith(_cloakDirPath);
    
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
            if (isManuallyCloaked)
              ListTile(
                leading: const Icon(Icons.settings_backup_restore, color: Colors.orangeAccent),
                title: const Text('Restore to Public Storage', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Move file back and make it visible again', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _restoreFile(file);
                },
              )
            else
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening...')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCloakFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() => _isLoading = true);
        for (var path in result.paths) {
          if (path != null) {
            final file = File(path);
            final fileName = p.basename(path);
            final newPath = p.join(_cloakDirPath, fileName);
            
            // Move file to hidden cloak dir
            await file.copy(newPath);
            await file.delete();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Files cloaked successfully! 🛡️'), backgroundColor: AppColors.primary),
        );
        _scanMedia();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cloaking files: $e')));
      }
    }
  }

  Future<void> _restoreFile(File file) async {
    // 1. Password check
    final controller = TextEditingController();
    final bool? authenticated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Confirm Account Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter password to restore this file to public storage.', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Account Password',
                hintStyle: TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final input = controller.text.trim();
              final saved = await _storage.read(key: 'saved_password');
              if (input == (saved ?? "").trim()) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Invalid Password')));
              }
            },
            child: const Text('Restore', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (authenticated != true) return;

    // 2. Perform restoration
    setState(() => _isLoading = true);
    try {
      final restoreDir = Directory('/storage/emulated/0/SafeShell_Restored');
      if (!await restoreDir.exists()) await restoreDir.create();
      
      final fileName = p.basename(file.path);
      final destPath = p.join(restoreDir.path, fileName);
      
      await file.copy(destPath);
      await file.delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File restored to: ${restoreDir.path} ✅'), backgroundColor: Colors.green),
        );
        _scanMedia();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error restoring file: $e')));
      }
    }
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
