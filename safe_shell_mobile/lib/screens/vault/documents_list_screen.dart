import 'package:flutter/material.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/file_viewer.dart';
import '../../utils/sound_effects.dart';
import '../../core/constants.dart';
import '../../utils/vault_encryption_helper.dart';
import '../../services/encryption_service.dart';
import '../../services/audit_logger.dart';
import '../../services/network_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
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
      final cachedData = await storage.read(key: 'cached_documents_list');
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
      await storage.write(key: 'cached_documents_list', value: jsonEncode(_items));
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

      final response = await NetworkService.get('${AppConstants.baseUrl}/vault?type=document');

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
        final errMsg = e.toString().contains('TimeoutException')
            ? 'Request timed out. Check your connection.'
            : 'Failed to load documents. Check your connection.';
        _showError(errMsg);
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
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
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, 
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
        allowMultiple: true,
      );

      if (result != null) {
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
        for (final platformFile in result.files) {
        if (platformFile.path == null) continue;
        
        try {
          await VaultEncryptionHelper.encryptAndUpload(
            platformFile.path!, 
            'document',
            customFileName: platformFile.name,
          );
          successCount++;
        } catch (e) {
          debugPrint('Upload failed for ${platformFile.name}: $e');
          failCount++;
          if (mounted) {
            final errorMsg = e.toString().replaceAll('Exception: ', '');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed for ${platformFile.name}: $errorMsg'), backgroundColor: Colors.redAccent),
            );
          }
        }
      }

        if (mounted) Navigator.pop(context); // Close loading
        _fetchItems();

        if (mounted && successCount > 0) {
           SoundEffects.uploadSuccess();
           AuditLogger.logFileUpload('$successCount document(s)', 'document');
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount Documents encrypted & saved to vault ✓'), backgroundColor: const Color(0xFF10B981)));
           // Automatically delete originals
           _promptDeleteOriginals(result.files);
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

  Future<void> _promptDeleteOriginals(List<PlatformFile> files) async {
    if (files.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isLight = Theme.of(ctx).brightness == Brightness.light;
        return AlertDialog(
          backgroundColor: isLight ? Colors.white : AppColors.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Delete Originals?', 
            style: AppTextStyles.heading.copyWith(color: isLight ? AppColors.textPrimary : Colors.white)
          ),
          content: Text(
            'The ${files.length} document${files.length > 1 ? 's are' : ' is'} now safely encrypted in your vault. Do you want to delete the original${files.length > 1 ? 's' : ''} from your device?',
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
      for (final file in files) {
        if (file.path != null) {
          try {
            final f = File(file.path!);
            if (await f.exists()) await f.delete();
          } catch (e) {
            debugPrint('Delete original error for ${file.name}: $e');
          }
        }
      }
      SoundEffects.deleteAction();
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete ${_selectedIds.length} Documents?', style: AppTextStyles.heading),
        content: Text('Items will be moved to Recycle Bin.', style: AppTextStyles.body),
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
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _saveSelectedToDevice() async {
    if (_selectedIds.isEmpty) return;

    if (await Permission.storage.request().isGranted || 
        await Permission.manageExternalStorage.request().isGranted
    ) {
        // Proceed
    }

    // Show loading
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator())
    );

    int successCount = 0;
    final downloadDir = Directory('/storage/emulated/0/Download/SafeShell/Documents');
    if (!await downloadDir.exists()) {
      try {
        await downloadDir.create(recursive: true);
      } catch (e) {
        debugPrint('Failed to create dir: $e');
      }
    }

    const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
    final token = await storage.read(key: AppConstants.keyToken);

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

             final fileName = item['name'] ?? 'doc_$id';
             final targetFile = File('${downloadDir.path}/$fileName');
             await targetFile.writeAsBytes(await decryptedFile.readAsBytes());

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
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount Documents saved to Downloads/SafeShell ✓'), backgroundColor: const Color(0xFF10B981)));
       setState(() {
         _isSelectionMode = false;
         _selectedIds.clear();
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? AppColors.textPrimary : Colors.white;
    final subColor = isLight ? AppColors.textSecondary : Colors.white54;
    final dimColor = isLight ? AppColors.textTertiary : Colors.white24;
    final bgColor = isLight ? AppColors.background : AppColors.darkBackground;
    final cardColor = isLight ? AppColors.surfaceVariant.withOpacity(0.5) : Colors.white.withOpacity(0.04);
    final borderColor = isLight ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.08);

    return Scaffold(
      backgroundColor: bgColor,
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
            ? Text('${_selectedIds.length} Selected', style: AppTextStyles.heading.copyWith(color: textColor))
            : Text('Documents', style: AppTextStyles.heading.copyWith(color: textColor)),
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
              tooltip: 'Save to Device',
              onPressed: _saveSelectedToDevice,
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
              ? Center(child: Text('No documents yet', style: AppTextStyles.body.copyWith(color: subColor)))
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
                                item['name'] ?? 'document',
                                vaultId: item['_id'].toString(),
                              );
                            }
                          }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4DA3FF).withOpacity(0.15) : cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF4DA3FF).withOpacity(0.5) : borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_isSelectionMode)
                              Container(
                                margin: const EdgeInsets.only(right: 14),
                                child: Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isSelected ? AppColors.primary : dimColor,
                                  size: 22,
                                ),
                              ),
                             Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.withOpacity(0.2), Colors.blue.withOpacity(0.05)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.blue.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.description_rounded, color: Colors.blue),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? 'Document', 
                                    style: AppTextStyles.subheading.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: textColor), 
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['size'] ?? '0 KB', 
                                    style: AppTextStyles.caption.copyWith(color: dimColor)
                                  ),
                                ],
                              ),
                            ),
                            if (!_isSelectionMode)
                              Icon(Icons.chevron_right_rounded, color: dimColor),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: !_isSelectionMode ? FloatingActionButton(
        onPressed: _uploadFile,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.upload_file_rounded),
      ) : null,
    );
  }
}

