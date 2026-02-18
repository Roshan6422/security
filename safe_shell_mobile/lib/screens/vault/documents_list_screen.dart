import 'package:flutter/material.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_card.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../utils/file_viewer.dart';
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
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final response = await ApiService().get('/vault?type=document');
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
        for (final platformFile in result.files) {
          if (platformFile.path != null) {
            try {
              await ApiService().uploadMultipart('/vault/upload', platformFile.path!);
              successCount++;
            } catch (e) {
               debugPrint('Upload failed for ${platformFile.name}: $e');
            }
          }
        }

        if (mounted) Navigator.pop(context); // Close loading
        _fetchItems();

        if (mounted && successCount > 0) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount Documents Encrypted & Saved to Vault 🔐')));
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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

    for (final id in _selectedIds) {
      final item = _items.firstWhere((i) => i['_id'] == id, orElse: () => null);
      if (item != null && item['url'] != null) {
        try {
           final url = '${ApiService.currentBaseUrl.replaceAll('/api', '')}${item['url']}';
           final response = await http.get(Uri.parse(url));
           if (response.statusCode == 200) {
             final fileName = item['name'] ?? 'doc_$id';
             final file = File('${downloadDir.path}/$fileName');
             await file.writeAsBytes(response.bodyBytes);
             successCount++;
           }
        } catch (e) {
          debugPrint('Save error: $e');
        }
      }
    }

    if (mounted) Navigator.pop(context); // Close loading

    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successCount Documents Saved to Downloads/SafeShell/Documents 📂')));
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
            : Text('Documents', style: AppTextStyles.heading),
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
              ? Center(child: Text('No documents yet', style: AppTextStyles.body.copyWith(color: Colors.white54)))
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
                                item['name'] ?? 'document'
                              );
                            }
                          }
                      },
                      child: GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
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
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.description, color: Colors.blueAccent),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'] ?? 'Document', style: AppTextStyles.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(item['size'] ?? '', style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            if (!_isSelectionMode)
                              const Icon(Icons.chevron_right, color: Colors.white24),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: !_isSelectionMode ? FloatingActionButton(
        onPressed: _uploadFile,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.upload_file),
      ) : null,
    );
  }
}

