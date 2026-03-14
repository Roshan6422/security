import 'package:flutter/material.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import '../../widgets/glass_card.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../services/network_service.dart';
import '../../services/audit_logger.dart';
import 'note_editor_screen.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.keyToken);
      if (token == null) return;

      final response = await NetworkService.client.get(
        Uri.parse('${AppConstants.baseUrl}/vault?type=note'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (!mounted) return;

        setState(() {
          _items = data.cast<Map<String, dynamic>>();
          _isLoading = false;
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      } else {
        throw Exception('Failed to fetch from backend');
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
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

  Future<void> _createNote() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
    );
    if (result == true) _fetchItems();
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete ${_selectedIds.length} Notes?', style: AppTextStyles.heading.copyWith(color: AppColors.textPrimary)),
        content: Text('Items will be moved to Recycle Bin.', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
       try {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: AppConstants.keyToken);
        if (token == null) return;

        for (final id in _selectedIds) {
          final response = await NetworkService.client.delete(
            Uri.parse('${AppConstants.baseUrl}/vault/$id'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (response.statusCode == 200) {
            final item = _items.firstWhere((i) => i['_id'].toString() == id, orElse: () => null);
            AuditLogger.logNoteDelete(item?['name'] ?? 'note');
          }
        }
        await _fetchItems();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? AppColors.textPrimary : Colors.white;
    final subColor = isLight ? AppColors.textSecondary : Colors.white70;
    final captionColor = isLight ? Colors.black45 : Colors.white30;

    return Scaffold(
      backgroundColor: isLight ? AppColors.background : AppColors.darkBackground,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                }),
              )
            : BackButton(color: textColor),
        title: _isSelectionMode
            ? Text('${_selectedIds.length} Selected', style: AppTextStyles.heading.copyWith(color: textColor))
            : Text('Notes', style: AppTextStyles.heading.copyWith(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(_selectedIds.length == _items.length ? Icons.deselect : Icons.select_all, color: textColor),
              onPressed: _selectAll,
            ),
             IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteSelected,
            ),
          ] else ...[
             IconButton(
              icon: Icon(Icons.checklist, color: textColor),
              tooltip: 'Select Items',
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
            IconButton(icon: Icon(Icons.refresh, color: textColor), onPressed: _fetchItems),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _items.isEmpty
              ? Center(child: Text('No notes yet', style: AppTextStyles.body.copyWith(color: captionColor)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isSelected = _selectedIds.contains(item['_id']);

                    return GestureDetector(
                        onLongPress: () => _enterSelectionMode(item['_id']),
                        onTap: () async {
                           if (_isSelectionMode) {
                             _toggleSelect(item['_id']);
                           } else {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => NoteEditorScreen(note: item)),
                              );
                              if (result == true) _fetchItems();
                           }
                        },
                        child: Stack(
                          children: [
                            GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'] ?? 'Untitled', style: AppTextStyles.subheading.copyWith(color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Text(
                                      item['content'] ?? '',
                                      style: AppTextStyles.caption.copyWith(color: subColor),
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item['updatedAt'] != null ? 'Edited just now' : 'Just now', 
                                    style: AppTextStyles.caption.copyWith(fontSize: 10, color: captionColor),
                                  ),
                                ],
                              ),
                            ),
                             if (_isSelectionMode)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: isLight ? Colors.white70 : Colors.black54),
                                  child: Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSelected ? AppColors.primary : (isLight ? Colors.black54 : Colors.white70),
                                    size: 24,
                                  ),
                                ),
                              ),
                             if (isSelected)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(26), // Match GlassCard radius
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
        onPressed: _createNote,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit),
      ) : null,
    );
  }
}

