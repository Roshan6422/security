import 'package:flutter/material.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import '../../services/api_service.dart';
// import 'package:file_picker/file_picker.dart'; // No longer needed for upload, but might be kept if referenced elsewhere? Assuming not based on replace.
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../utils/file_viewer.dart';
import 'package:path_provider/path_provider.dart';

class VideosListScreen extends StatefulWidget {
  const VideosListScreen({super.key});

  @override
  State<VideosListScreen> createState() => _VideosListScreenState();
}

class _VideosListScreenState extends State<VideosListScreen> {
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
      final response = await ApiService().get('/vault?type=video');
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

  Future<void> _uploadFile() async {
    try {
      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 50,
          requestType: RequestType.video,
          themeColor: AppColors.primary,
        ),
      );

      if (result != null && result.isNotEmpty) {
        // Show loading
        if (mounted) {
           showDialog(
            context: context, 
            barrierDismissible: false, 
            builder: (_) => const Center(child: CircularProgressIndicator())
          );
        }

        int successCount = 0;
        for (final asset in result) {
          final file = await asset.file;
          if (file != null) {
            try {
              await ApiService().uploadMultipart('/vault/upload', file.path);
              successCount++;
            } catch (e) {
              debugPrint('Upload failed for ${asset.id}: $e');
            }
          }
        }
        
        if (mounted) Navigator.pop(context); // Close loading
        await _fetchItems();
        
        if (mounted) {
           if (successCount > 0) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount Videos Encrypted & Saved to Vault 🔐')));
             _askToDeleteOriginals(result);
           }
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _askToDeleteOriginals(List<AssetEntity> assets) async {
     final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
         backgroundColor: const Color(0xFF1E293B),
         title: const Text('Delete Originals?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
         content: Text(
           'Do you want to delete ${assets.length} videos from your device gallery?\n\n(They are safe in the Vault)', 
           style: const TextStyle(color: Colors.white70)
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(ctx, false), 
             child: const Text('Keep them')
           ),
           TextButton(
             onPressed: () => Navigator.pop(ctx, true), 
             child: const Text('Yes, Delete All', style: TextStyle(color: Colors.red))
           ),
         ],
      ),
    );

    if (confirm == true) {
      try {
        final ids = assets.map((e) => e.id).toList();
        await PhotoManager.editor.deleteWithIds(ids);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Originals deleted from Gallery 🗑️')));
      } catch (e) {
         debugPrint('Delete error: $e');
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete some items')));
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete ${_selectedIds.length} Videos?', style: AppTextStyles.heading),
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

    // Show loading
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator())
    );

    int successCount = 0;
    for (final id in _selectedIds) {
      final item = _items.firstWhere((i) => i['_id'] == id, orElse: () => null);
      if (item != null && item['url'] != null) {
        try {
           final url = '${ApiService.currentBaseUrl.replaceAll('/api', '')}${item['url']}';
           final response = await http.get(Uri.parse(url));
           if (response.statusCode == 200) {
             // Save to temp file first for video
             final tempDir = await getTemporaryDirectory();
             final tempFile = File('${tempDir.path}/${item['name'] ?? 'video_$id.mp4'}');
             await tempFile.writeAsBytes(response.bodyBytes);
             
             final result = await PhotoManager.editor.saveVideo(
                tempFile,
                title: item['name'] ?? 'video_$id',
             );
             
             // Cleanup temp
             if (await tempFile.exists()) await tempFile.delete();

             if (result != null) successCount++;
           }
        } catch (e) {
          debugPrint('Save error: $e');
        }
      }
    }

    if (mounted) Navigator.pop(context); // Close loading

    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount Videos Saved to Gallery 🖼️')));
       setState(() {
         _isSelectionMode = false;
         _selectedIds.clear();
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                }),
              )
            : const BackButton(),
        title: _isSelectionMode
            ? Text('${_selectedIds.length} Selected', style: AppTextStyles.heading)
            : Text('Videos', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(_selectedIds.length == _items.length ? Icons.deselect : Icons.select_all),
              onPressed: _selectAll,
            ),
             IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteSelected,
            ),
             IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Save to Gallery',
              onPressed: _saveSelectedToGallery,
            ),
          ] else ...[
             IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Select Items',
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchItems),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Text('No videos yet', style: AppTextStyles.body.copyWith(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isSelected = _selectedIds.contains(item['_id']);

                    return GestureDetector(
                      onLongPress: () => _enterSelectionMode(item['_id']),
                      onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelect(item['_id']);
                          } else {
                            if (item['url'] != null) {
                               FileViewer.openFile(
                                context, 
                                item['url'], 
                                item['name'] ?? 'video_${item['_id']}.mp4'
                              );
                            }
                          }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            if (_isSelectionMode)
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isSelected ? AppColors.primary : Colors.white70,
                                ),
                              ),
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.play_circle_fill, color: Colors.white70, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? 'Unknown',
                                    style: AppTextStyles.body,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    item['size'] ?? '', 
                                    style: AppTextStyles.caption
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: !_isSelectionMode ? FloatingActionButton(
        onPressed: _uploadFile,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.video_call),
      ) : null,
    );
  }
}

