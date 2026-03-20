import 'package:flutter/material.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'dart:io';
import '../../utils/file_viewer.dart';
import '../../utils/sound_effects.dart';
import '../../services/audit_logger.dart';
import '../../services/network_service.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../services/encryption_service.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/vault_encryption_helper.dart';

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
    _loadCachedItems().then((_) => _fetchItems());
  }

  Future<void> _loadCachedItems() async {
    try {
      const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
      final cachedData = await storage.read(key: 'cached_videos_list');
      if (cachedData != null && mounted) {
        setState(() {
          _items = jsonDecode(cachedData).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Cache load error: $e');
    }
  }

  Future<void> _saveItemsToCache() async {
    try {
      const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
      await storage.write(key: 'cached_videos_list', value: jsonEncode(_items));
    } catch (e) {
      debugPrint('Cache save error: $e');
    }
  }

  Future<void> _fetchItems() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
      final token = await storage.read(key: AppConstants.keyToken);
      if (token == null) return;

      final response = await NetworkService.get('${AppConstants.baseUrl}/vault?type=video');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;

        setState(() {
          _items = data.cast<Map<String, dynamic>>();
          _isLoading = false;
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        _saveItemsToCache();
      } else {
        throw Exception('Failed to fetch from backend');
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        final errorMessage = e.toString().contains('timed out') || e.toString().contains('SocketException')
            ? 'Connection failed. Check server URL & internet.'
            : 'Failed to load videos: ${e.toString().replaceAll('Exception: ', '')}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _toggleSelect(String id) {
    SoundEffects.tap();
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
    SoundEffects.tap();
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _selectAll() {
    SoundEffects.tap();
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
        int failCount = 0;
        for (final asset in result) {
        final file = await asset.file;
        if (file == null) {
          failCount++;
          continue;
        }

        try {
          await VaultEncryptionHelper.encryptAndUpload(
            file.path, 
            'video',
            customFileName: asset.title,
          );
          successCount++;
        } catch (e) {
          debugPrint('Upload failed for ${asset.id}: $e');
          failCount++;
          if (mounted) {
            final errorMsg = e.toString().replaceAll('Exception: ', '');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed for ${asset.title}: $errorMsg'), backgroundColor: Colors.redAccent),
            );
          }
        }
      }
        
        if (mounted) Navigator.pop(context); // Close loading
        await _fetchItems();
        
        if (mounted) {
           if (successCount > 0) {
             AuditLogger.logFileUpload('$successCount video(s)', 'video');
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount Videos Encrypted & Saved to Vault')));
             _promptDeleteOriginals(result);
           }
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $errorMsg'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _promptDeleteOriginals(List<AssetEntity> assets) async {
    if (assets.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isLight = Theme.of(ctx).brightness == Brightness.light;
        return AlertDialog(
          backgroundColor: isLight ? Colors.white : AppColors.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Delete from Gallery?', 
            style: AppTextStyles.heading.copyWith(color: isLight ? AppColors.textPrimary : Colors.white)
          ),
          content: Text(
            'The ${assets.length} video${assets.length > 1 ? 's are' : ' is'} now safely encrypted in your vault. Do you want to delete the original${assets.length > 1 ? 's' : ''} from your gallery?',
            style: AppTextStyles.body.copyWith(color: isLight ? AppColors.textSecondary : Colors.white70)
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep', style: TextStyle(color: isLight ? AppColors.textTertiary : Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final ids = assets.map((e) => e.id).toList();
        await PhotoManager.editor.deleteWithIds(ids);
        SoundEffects.deleteAction();
      } catch (e) {
        debugPrint('Delete originals error: $e');
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete ${_selectedIds.length} Videos?', style: AppTextStyles.heading.copyWith(color: Theme.of(context).brightness == Brightness.light ? AppColors.textPrimary : Colors.white)),
        content: Text('Items will be moved to Recycle Bin.', style: AppTextStyles.body.copyWith(color: Theme.of(context).brightness == Brightness.light ? AppColors.textSecondary : Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
       try {
      const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
      final token = await storage.read(key: AppConstants.keyToken);
      if (token == null) return;

      int failCount = 0;
      try {
        final response = await NetworkService.post(
          '${AppConstants.baseUrl}/vault/delete-batch',
          {'ids': _selectedIds.toList()},
        );

        if (response.statusCode != 200) {
          failCount = _selectedIds.length;
        }
      } catch (e) {
        debugPrint('Batch delete failed: $e');
        failCount = _selectedIds.length;
      }
      SoundEffects.deleteAction();
      await _fetchItems();

      if (mounted) {
        if (failCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_selectedIds.length} videos moved to Recycle Bin.')));
        } else if (failCount == _selectedIds.length) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete any videos.'), backgroundColor: Colors.redAccent));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully deleted ${_selectedIds.length - failCount} videos, $failCount failed.'), backgroundColor: Colors.orangeAccent));
        }
      }
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

    const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
    final token = await storage.read(key: AppConstants.keyToken);

    int successCount = 0;
    for (final id in _selectedIds) {
      final item = _items.firstWhere((i) => i['_id'] == id, orElse: () => null);
      if (item != null && item['url'] != null) {
        try {
           final url = item['url'];
           final response = await NetworkService.get(url);
           if (response.statusCode == 200) {
             final tempDir = await getTemporaryDirectory();
             final tempEncPath = '${tempDir.path}/temp_enc_$id.shell';
             final tempEncFile = File(tempEncPath);
             await tempEncFile.writeAsBytes(response.bodyBytes);
             
             // Decrypt
             final decryptedPath = await EncryptionService.decryptFile(tempEncPath);
             final decryptedFile = File(decryptedPath);
             
             await PhotoManager.editor.saveVideo(
                decryptedFile,
                title: item['name'] ?? 'video_$id',
             );
             
             // Cleanup
             if (await tempEncFile.exists()) await tempEncFile.delete();
             if (await decryptedFile.exists()) await decryptedFile.delete();

             successCount++;
           }
        } catch (e) {
          debugPrint('Save error: $e');
        }
      }
    }

    if (mounted) Navigator.pop(context); // Close loading

    if (mounted) {
       SoundEffects.unlockApp();
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount Videos Saved to Gallery ')));
       setState(() {
         _isSelectionMode = false;
         _selectedIds.clear();
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
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
                                item['name'] ?? 'video_${item['_id']}.mp4',
                                vaultId: item['_id'].toString(),
                              );
                            }
                          }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.primary.withOpacity(0.5) : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            if (_isSelectionMode)
                              Container(
                                margin: const EdgeInsets.only(right: 14),
                                child: Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isSelected ? AppColors.primary : Colors.white30,
                                  size: 22,
                                ),
                              ),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.purple.withOpacity(0.2), Colors.purple.withOpacity(0.05)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.purple.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.play_circle_fill_rounded, color: Colors.purple, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? 'Unknown',
                                    style: AppTextStyles.subheading.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['size'] ?? '0 KB', 
                                    style: AppTextStyles.caption.copyWith(color: Colors.white24)
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
        child: const Icon(Icons.video_call_rounded),
      ) : null,
    );
  }
}


