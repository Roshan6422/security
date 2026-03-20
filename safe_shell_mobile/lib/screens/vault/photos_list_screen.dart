import 'dart:io';
import 'package:flutter/material.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../../utils/sound_effects.dart';
import '../../services/audit_logger.dart';
import '../../services/encryption_service.dart';
import '../../services/network_service.dart';
import '../../utils/vault_encryption_helper.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import 'photo_viewer_screen.dart';
import '../../widgets/secure_network_viewer.dart';

class PhotosListScreen extends StatefulWidget {
  const PhotosListScreen({super.key});

  @override
  State<PhotosListScreen> createState() => _PhotosListScreenState();
}

class _PhotosListScreenState extends State<PhotosListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isUploading = false;
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
      final cachedData = await storage.read(key: 'cached_photos_list');
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
      await storage.write(key: 'cached_photos_list', value: jsonEncode(_items));
    } catch (e) {
      debugPrint('Cache save error: $e');
    }
  }

  //  Data Fetching 

  Future<void> _fetchItems() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
      final token = await storage.read(key: AppConstants.keyToken);
      if (token == null) return;

      final response = await NetworkService.get('${AppConstants.baseUrl}/vault?type=photo');

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
        throw Exception('Failed to fetch from backend (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Connection failed. Check backend status.');
      }
    }
  }

  //  Selection Logic 

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

  void _exitSelectionMode() {
    SoundEffects.tap();
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    SoundEffects.tap();
    setState(() {
      if (_selectedIds.length == _items.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_items.map((i) => i['_id'].toString()));
      }
    });
  }

  //  Upload Logic 

  Future<void> _uploadFile() async {
    if (_isUploading) return;

    try {
      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 50,
          requestType: RequestType.image,
          themeColor: AppColors.primary,
        ),
      );

      if (result == null || result.isEmpty || !mounted) return;

      setState(() => _isUploading = true);
      _showLoadingDialog('Uploading ${result.length} photos...');

      int successCount = 0;
      int failCount = 0;

      for (final asset in result) {
        final file = await asset.file;
        if (file == null) {
          failCount++;
          continue;
        }

        try {
          // VaultEncryptionHelper now handles backend upload and record creation
          await VaultEncryptionHelper.encryptAndUpload(
            file.path, 
            'photo', 
            customFileName: asset.title,
          );
          successCount++;
        } catch (e) {
          debugPrint('Upload failed for ${asset.id}: $e');
          failCount++;
        }
      }

      _dismissLoadingDialog();
      setState(() => _isUploading = false);

      await _fetchItems();

      if (!mounted) return;

      if (successCount > 0) {
        SoundEffects.uploadSuccess();
        AuditLogger.logFileUpload('$successCount photo(s)', 'photo');
        _showSuccess(
          '$successCount photo${successCount > 1 ? 's' : ''} encrypted & saved'
          '${failCount > 0 ? ' ($failCount failed)' : ''}',
        );
        // Prompt to delete originals if any were successful
        _promptDeleteOriginals(result);
      } else {
        _showError('All uploads failed');
      }
    } catch (e) {
      _dismissLoadingDialog();
      setState(() => _isUploading = false);
      if (mounted) _showError('Upload error: $e');
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
            'The ${assets.length} photo${assets.length > 1 ? 's are' : ' is'} now safely encrypted in your vault. Do you want to delete the original${assets.length > 1 ? 's' : ''} from your gallery?',
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

  //  Delete Logic 

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete $count photo${count > 1 ? 's' : ''}?',
          style: AppTextStyles.heading.copyWith(color: Theme.of(ctx).brightness == Brightness.light ? AppColors.textPrimary : Colors.white),
        ),
        content: Text(
          'Items will be moved to the Recycle Bin.',
          style: AppTextStyles.body.copyWith(color: Theme.of(ctx).brightness == Brightness.light ? AppColors.textSecondary : Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _showLoadingDialog('Deleting...');

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

      _dismissLoadingDialog();
      SoundEffects.deleteAction();
      await _fetchItems();

      if (mounted && failCount > 0) {
        _showError('$failCount items failed to delete');
      }
    } catch (e) {
      _dismissLoadingDialog();
      if (mounted) _showError('Delete error: $e');
    }
  }

  //  Save to Gallery 

  Future<void> _saveSelectedToGallery() async {
    if (_selectedIds.isEmpty) return;

    _showLoadingDialog('Saving to gallery...');

    const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
    final token = await storage.read(key: AppConstants.keyToken);

    int successCount = 0;

    for (final id in _selectedIds.toList()) {
      final item = _findItemById(id);
      if (item == null || item['url'] == null) continue;

      try {
        final url = item['url'];
        final response = await NetworkService.get(url);

        if (response.statusCode == 200) {
          // Download is encrypted — must decrypt before saving to gallery
          final cacheDir = await EncryptionService.getDecryptedCacheDir();
          final tempEncPath = '${cacheDir.path}/temp_save_$id.shell';
          final tempEncFile = File(tempEncPath);
          await tempEncFile.writeAsBytes(response.bodyBytes);

          // Decrypt 
          final decryptedPath = await EncryptionService.decryptFile(tempEncPath);
          final decryptedFile = File(decryptedPath);
          final decryptedBytes = await decryptedFile.readAsBytes();

          await PhotoManager.editor.saveImage(
            decryptedBytes,
            filename: item['name'] ?? 'photo_$id',
          );
          successCount++;

          // Cleanup temp files
          if (await tempEncFile.exists()) await tempEncFile.delete();
          if (await decryptedFile.exists()) await decryptedFile.delete();
        }
      } catch (e) {
        debugPrint('Save to gallery error for $id: $e');
      }
    }

    _dismissLoadingDialog();

    if (!mounted) return;

    if (successCount > 0) {
      SoundEffects.unlockApp();
      _showSuccess('$successCount photo${successCount > 1 ? 's' : ''} saved to gallery');
    } else {
      _showError('Failed to save photos');
    }

    _exitSelectionMode();
  }

  //  Helpers 

  Map<String, dynamic>? _findItemById(String id) {
    try {
      return _items.firstWhere((i) => i['_id'].toString() == id);
    } catch (_) {
      return null;
    }
  }

  void _showLoadingDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(message, style: AppTextStyles.body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _dismissLoadingDialog() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  //  UI 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
            )
          : BackButton(color: Theme.of(context).brightness == Brightness.light ? AppColors.textPrimary : Colors.white),
      title: Text(
        _isSelectionMode
            ? '${_selectedIds.length} Selected'
            : 'Photos',
        style: AppTextStyles.heading,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: _isSelectionMode
          ? _buildSelectionActions()
          : _buildDefaultActions(),
    );
  }

  List<Widget> _buildSelectionActions() {
    return [
      IconButton(
        icon: Icon(
          _selectedIds.length == _items.length
              ? Icons.deselect
              : Icons.select_all,
        ),
        tooltip: _selectedIds.length == _items.length
            ? 'Deselect All'
            : 'Select All',
        onPressed: _selectAll,
      ),
      IconButton(
        icon: const Icon(Icons.download),
        tooltip: 'Save to Gallery',
        onPressed: _saveSelectedToGallery,
      ),
      IconButton(
        icon: const Icon(Icons.delete, color: Colors.redAccent),
        tooltip: 'Delete Selected',
        onPressed: _deleteSelected,
      ),
    ];
  }

  List<Widget> _buildDefaultActions() {
    return [
      if (_items.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: 'Select Items',
          onPressed: () => setState(() => _isSelectionMode = true),
        ),
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Refresh',
        onPressed: _fetchItems,
      ),
    ];
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _fetchItems,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: _items.length,
        itemBuilder: _buildGridItem,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No photos yet',
            style: AppTextStyles.body.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add photos to your vault',
            style: AppTextStyles.body.copyWith(
              color: Colors.white38,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, int index) {
    final item = _items[index];
    final id = item['_id'].toString();
    final isSelected = _selectedIds.contains(id);

    return GestureDetector(
      onLongPress: () => _enterSelectionMode(id),
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelect(id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PhotoViewerScreen(
                imageUrl: item['url'] ?? '',
                heroTag: id,
                vaultId: id,
              ),
            ),
          );
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Actual Image Preview (Full-bleed)
          Hero(
            tag: id,
            child: SecureNetworkViewer(
              relativeUrl: item['url'] ?? '',
              vaultId: id,
              builder: (context, localPath) => Image.file(
                File(localPath),
                fit: BoxFit.cover,
                cacheWidth: 400, // Prevent OOM by strictly bounding decode pixel size
              ),
            ),
          ),

          // Selection Overlay
          if (isSelected)
            Container(
              color: AppColors.primary.withOpacity(0.2),
              child: const Center(
                child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 32),
              ),
            ),

          // Modern Gradient Overlay for Meta (Bottom)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Text(
                item['name'] ?? 'Untitled',
                style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Lock Indicator
          Positioned(
            top: 4, left: 4,
            child: Icon(Icons.lock_rounded, color: Colors.white.withOpacity(0.5), size: 10),
          ),

          // Select Circle (Visible only in selection mode when not selected)
          if (_isSelectionMode && !isSelected)
            Positioned(
              top: 6, right: 6,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  color: Colors.black26,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildFAB() {
    if (_isSelectionMode || _isUploading) return null;

    return FloatingActionButton(
      onPressed: _uploadFile,
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.add_a_photo),
    );
  }
}
