import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import '../../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'photo_viewer_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../utils/file_viewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CloakListScreen extends StatefulWidget {
  const CloakListScreen({super.key});

  @override
  State<CloakListScreen> createState() => _CloakListScreenState();
}

class _CloakListScreenState extends State<CloakListScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final response = await ApiService().get('/vault?type=cloak');
      if (mounted) {
        setState(() {
          _items = (response as List).where((i) => i['isDeleted'] != true).toList();
          _isLoading = false;
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }
  
  void _selectAll() {
    if (_selectedIds.length == _items.length) {
      setState(() => _selectedIds.clear());
    } else {
      setState(() => _selectedIds.addAll(_items.map((i) => i['_id'].toString())));
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete ${_selectedIds.length} Items?', style: AppTextStyles.heading),
        content: Text('Items will be moved to Recycle Bin.', style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
       try {
        for (final id in _selectedIds) {
          await ApiService().delete('/vault/$id');
        }
        await _fetchItems();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _saveSelectedToGallery() async {
    if (_selectedIds.isEmpty) return;

    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator())
    );

    int successCount = 0;
    try {
      // Create restore directory for documents
      final restoreDir = Directory('/storage/emulated/0/SafeShell_Restored');
      if (!await restoreDir.exists()) await restoreDir.create();

      for (final id in _selectedIds) {
        final item = _items.firstWhere((i) => i['_id'] == id, orElse: () => null);
        if (item != null && item['url'] != null) {
          try {
             final url = '${ApiService.currentBaseUrl.replaceAll('/api', '')}${item['url']}';
             final name = item['name'] ?? 'file_$id';
             final ext = p.extension(name).toLowerCase();
             
             final response = await http.get(Uri.parse(url));
             if (response.statusCode == 200) {
               final Uint8List bytes = response.bodyBytes;

               if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext)) {
                 // Image -> Gallery
                 final result = await PhotoManager.editor.saveImage(
                    bytes,
                    filename: 'Restored_$name',
                    title: 'Restored_$name',
                 );
                 if (result != null) successCount++;
                 
               } else if (['.mp4', '.mov', '.avi', '.mkv'].contains(ext)) {
                 // Video -> Gallery
                 final tempDir = await getTemporaryDirectory();
                 final tempFile = File('${tempDir.path}/$name');
                 await tempFile.writeAsBytes(bytes);
                 
                 final result = await PhotoManager.editor.saveVideo(
                    tempFile,
                    title: name,
                 );
                 await tempFile.delete();
                 if (result != null) successCount++;
                 
               } else {
                 // Documents -> Public Folder
                 final file = File('${restoreDir.path}/$name');
                 await file.writeAsBytes(bytes);
                 successCount++;
               }
             }
          } catch (e) {
            debugPrint('Save error for $id: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('General save error: $e');
    }

    if (mounted) Navigator.pop(context);

    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount Items Restored ')));
       setState(() {
         _isSelectionMode = false;
         _selectedIds.clear();
       });
    }
  }
  
  bool _isImage(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext);
  }

  bool _isVideo(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.mp4', '.mov', '.avi', '.mkv'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedIds.clear(); }))
            : const BackButton(),
        title: _isSelectionMode
            ? Text('${_selectedIds.length} Selected', style: AppTextStyles.heading)
            : Text('Cloaked Vault', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(icon: Icon(_selectedIds.length == _items.length ? Icons.deselect : Icons.select_all), onPressed: _selectAll),
            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _deleteSelected),
            IconButton(icon: const Icon(Icons.download), tooltip: 'Restore to Device', onPressed: _saveSelectedToGallery),
          ] else ...[
            IconButton(icon: const Icon(Icons.checklist), tooltip: 'Select Items', onPressed: () => setState(() => _isSelectionMode = true)),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchItems),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No cloaked files in vault', style: TextStyle(color: Colors.white54)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isSelected = _selectedIds.contains(item['_id']);
                    final name = item['name'] ?? 'File ${index+1}';
                    final url = item['url'] ?? '';
                    
                    final isImg = _isImage(name);
                    final isVid = _isVideo(name);
                    
                    return GestureDetector(
                        onLongPress: () => _enterSelectionMode(item['_id']),
                        onTap: () {
                           if (_isSelectionMode) {
                             _toggleSelect(item['_id']);
                           } else {
                             if (isImg) {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(
                                   builder: (_) => PhotoViewerScreen(
                                     imageUrl: url,
                                     heroTag: item['_id'],
                                   ),
                                 ),
                               );
                             } else {
                               // Open Video or Doc
                               FileViewer.openFile(context, url, name);
                             }
                           }
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _buildThumbnail(url, name, isImg, isVid),
                              ),
                            ),
                            if (_isSelectionMode)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                                  child: Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSelected ? AppColors.primary : Colors.white70,
                                    size: 24,
                                  ),
                                ),
                              ),
                            if (isSelected)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    );
                  },
                ),
    );
  }

  Widget _buildThumbnail(String url, String name, bool isImg, bool isVid) {
    if (isImg && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: '${ApiService.currentBaseUrl.replaceAll('/api', '')}$url',
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[900]),
        errorWidget: (context, url, error) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white24)),
      );
    } else if (isVid) {
      return Container(
        color: Colors.black45,
        child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 40)),
      );
    } else {
      // Document / Other
      return Container(
        color: Colors.white10,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description, color: Colors.white70, size: 32),
            const SizedBox(height: 4),
            Text(
              name, 
              maxLines: 2, 
              overflow: TextOverflow.ellipsis, 
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 10)
            )
          ],
        ),
      );
    }
  }
}

