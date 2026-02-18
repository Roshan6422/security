import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import '../../services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'photo_viewer_screen.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotosListScreen extends StatefulWidget {
  const PhotosListScreen({super.key});

  @override
  State<PhotosListScreen> createState() => _PhotosListScreenState();
}

class _PhotosListScreenState extends State<PhotosListScreen> {
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
      final response = await ApiService().get('/vault?type=photo');
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
          maxAssets: 50, // Allow multiple selection
          requestType: RequestType.image,
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

        final List<AssetEntity> successfulAssets = [];
        int successCount = 0;
        
        for (final asset in result) {
          final file = await asset.file;
          if (file != null) {
            try {
              await ApiService().uploadMultipart('/vault/upload', file.path);
              successCount++;
              successfulAssets.add(asset);
            } catch (e) {
              debugPrint('Upload failed for ${asset.id}: $e');
            }
          }
        }
        
        if (mounted) Navigator.pop(context); // Close loading
        await _fetchItems();
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount Photos Encrypted & Saved to Vault 🔐')));
           
           if (successfulAssets.isNotEmpty) {
             // Auto-delete originals (will still trigger OS confirmation)
             try {
               final ids = successfulAssets.map((e) => e.id).toList();
               await PhotoManager.editor.deleteWithIds(ids);
             } catch (e) {
               debugPrint('Auto-delete failed: $e');
             }
           }
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }


  // Helper placeholder to keep existing signature if referenced, but _uploadFile uses logic directly
  // Remove _uploadToServer if unused, or keep it.
  Future<void> _uploadToServer(PlatformFile file) async {
     // Unused now
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete ${_selectedIds.length} Photos?', style: AppTextStyles.heading),
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
             final Uint8List bytes = response.bodyBytes;
             final result = await PhotoManager.editor.saveImage(
                bytes,
                filename: 'SafeShell_Export_${DateTime.now().millisecondsSinceEpoch}.jpg',
                title: 'SafeShell_Export_${DateTime.now().millisecondsSinceEpoch}.jpg',
             );
             if (result != null) successCount++;
           }
        } catch (e) {
          debugPrint('Save error: $e');
        }
      }
    }

    if (mounted) Navigator.pop(context); // Close loading

    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount Photos Saved to Gallery 🖼️')));
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
            : Text('Photos', style: AppTextStyles.heading),
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
              ? Center(child: Text('No photos yet', style: AppTextStyles.body.copyWith(color: Colors.white54)))
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
                    
                    return GestureDetector(
                        onLongPress: () => _enterSelectionMode(item['_id']),
                        onTap: () {
                           if (_isSelectionMode) {
                             _toggleSelect(item['_id']);
                           } else {
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (_) => PhotoViewerScreen(
                                   imageUrl: item['url'] ?? '',
                                   heroTag: item['_id'],
                                 ),
                               ),
                             );
                           }
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: item['url'] != null
                                    ? CachedNetworkImage(
                                        imageUrl: '${ApiService.currentBaseUrl.replaceAll('/api', '')}${item['url']}',
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(color: Colors.grey[900]),
                                        errorWidget: (context, url, error) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image)),
                                      )
                                    : Container(color: Colors.grey[800], child: const Icon(Icons.image)),
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
      floatingActionButton: !_isSelectionMode ? FloatingActionButton(
        onPressed: _uploadFile,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_a_photo),
      ) : null,
    );
  }
}

