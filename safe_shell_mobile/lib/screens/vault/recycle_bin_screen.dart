import 'package:flutter/material.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import 'package:safe_shell_mobile/widgets/glass_card.dart';
import 'package:safe_shell_mobile/widgets/primary_button.dart';
import '../../services/api_service.dart';
import '../../services/audit_logger.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchDeletedItems();
  }

  Future<void> _fetchDeletedItems() async {
    try {
      final response = await ApiService().get('/vault?isDeleted=true');
      if (mounted) {
        final allItems = response ?? [];
        // Auto-delete items older than 30 days
        await _autoDeleteExpired(allItems);
        setState(() {
          _items = allItems.where((item) => !_isExpired(item)).toList();
          _isLoading = false;
          _selectedIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  bool _isExpired(dynamic item) {
    if (item['deletedAt'] == null) return false;
    try {
      final deletedAt = DateTime.parse(item['deletedAt'].toString());
      return DateTime.now().difference(deletedAt).inDays >= 30;
    } catch (_) {
      return false;
    }
  }

  int _daysRemaining(dynamic item) {
    if (item['deletedAt'] == null) return 30;
    try {
      final deletedAt = DateTime.parse(item['deletedAt'].toString());
      final daysPassed = DateTime.now().difference(deletedAt).inDays;
      return (30 - daysPassed).clamp(0, 30);
    } catch (_) {
      return 30;
    }
  }

  Future<void> _autoDeleteExpired(List<dynamic> items) async {
    final expired = items.where((item) => _isExpired(item)).toList();
    if (expired.isEmpty) return;
    
    for (final item in expired) {
      try {
        await ApiService().delete('/vault/${item['_id']}?permanent=true');
        debugPrint('Auto-deleted expired item: ${item['name']}');
      } catch (e) {
        debugPrint('Auto-delete failed for ${item['_id']}: $e');
      }
    }
    
    if (mounted && expired.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${expired.length} expired item(s) auto-deleted'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _items.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_items.map((i) => i['_id'].toString()));
      }
    });
  }

  Future<void> _restoreSelected() async {
    if (_selectedIds.isEmpty) return;
    
    try {
      for (final id in _selectedIds) {
        final item = _items.firstWhere((i) => i['_id'].toString() == id, orElse: () => null);
        await ApiService().post('/vault/$id/restore', {});
        AuditLogger.logFileRestore(item?['name'] ?? 'item', item?['type'] ?? 'file');
      }
      await _fetchDeletedItems();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_selectedIds.length} items restored')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteSelectedPermanently() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete ${_selectedIds.length} Items?', style: AppTextStyles.heading.copyWith(color: AppColors.textPrimary)),
        content: Text('These items will be permanently removed. This cannot be undone.', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final id in _selectedIds) {
          final item = _items.firstWhere((i) => i['_id'].toString() == id, orElse: () => null);
          await ApiService().delete('/vault/$id?permanent=true');
          AuditLogger.logFilePermanentDelete(item?['name'] ?? 'item', item?['type'] ?? 'file');
        }
        await _fetchDeletedItems();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Items deleted permanently')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _emptyBin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Empty Recycle Bin?', style: AppTextStyles.heading.copyWith(color: AppColors.textPrimary)),
        content: Text('All items will be permanently deleted.', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Empty', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final count = _items.length;
        await ApiService().delete('/vault/empty-bin');
        AuditLogger.logEmptyBin(count);
        await _fetchDeletedItems();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recycle Bin Emptied')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'photo': return Icons.image;
      case 'video': return Icons.videocam;
      case 'note': return Icons.description;
      case 'zip': return Icons.folder_zip;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'photo': return const Color(0xFF4DA3FF);
      case 'video': return const Color(0xFF8B5CF6);
      case 'note': return const Color(0xFFFCD34D);
      case 'zip': return const Color(0xFFF59E0B);
      default: return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? AppColors.textPrimary : Colors.white;
    final subColor = isLight ? AppColors.textSecondary : Colors.white30;
    final iconColor = isLight ? Colors.black26 : Colors.white24;

    return Scaffold(
      backgroundColor: isLight ? AppColors.background : AppColors.darkBackground,
      body: Stack(
        children: [
          // Background Blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.08),
                boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.05), blurRadius: 100, spreadRadius: 50)],
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.05), blurRadius: 80, spreadRadius: 40)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text('Recycle Bin', style: AppTextStyles.display.copyWith(fontSize: 24, color: textColor)),
                      const Spacer(),
                      if (_items.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                          tooltip: 'Empty Bin',
                          onPressed: _emptyBin,
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : _items.isEmpty
                          ? _buildEmptyState(isLight, textColor, subColor, iconColor)
                          : _buildItemList(isLight, textColor, subColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isLight, Color textColor, Color subColor, Color iconColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isLight ? Colors.black.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.03),
              shape: BoxShape.circle,
              border: Border.all(color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(Icons.delete_outline, size: 48, color: iconColor),
          ),
          const SizedBox(height: 24),
          Text('Recycle Bin is Empty', style: AppTextStyles.display.copyWith(fontSize: 20, color: textColor)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Deleted items will appear here for 30 days before being permanently removed.',
              style: AppTextStyles.body.copyWith(color: subColor, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            text: 'Back to Vault',
            onPressed: () => Navigator.pop(context),
            width: 180,
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(bool isLight, Color textColor, Color subColor) {
    return Column(
      children: [
        // Selection Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _selectAll,
                  child: Row(
                    children: [
                      Icon(
                        _selectedIds.length == _items.length ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _selectedIds.length == _items.length ? 'Deselect All' : 'Select All',
                        style: AppTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_selectedIds.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.restore, color: Colors.greenAccent),
                    onPressed: _restoreSelected,
                    tooltip: 'Restore',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    onPressed: _deleteSelectedPermanently,
                    tooltip: 'Delete Permanently',
                  ),
                ],
              ],
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final id = item['_id'].toString();
              final isSelected = _selectedIds.contains(id);
              final color = _getColorForType(item['type'] ?? 'unknown');

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onTap: () => _toggleSelect(id),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Icon(_getIconForType(item['type'] ?? 'unknown'), color: color, size: 24),
                    ),
                    title: Text(
                      item['name'] ?? 'Unknown',
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Text(item['size'] ?? '0 KB', style: AppTextStyles.caption.copyWith(color: subColor)),
                          const SizedBox(width: 8),
                          Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: isLight ? Colors.black26 : Colors.white24)),
                          const SizedBox(width: 8),
                          Builder(builder: (_) {
                            final days = _daysRemaining(item);
                            final daysColor = days <= 5 ? Colors.redAccent : days <= 15 ? Colors.orangeAccent : Colors.greenAccent;
                            return Text(
                              '$days days left',
                              style: AppTextStyles.caption.copyWith(color: daysColor, fontWeight: FontWeight.w600),
                            );
                          }),
                        ],
                      ),
                    ),
                    trailing: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.primary)
                          : Icon(Icons.circle_outlined, color: isLight ? Colors.black26 : Colors.white.withValues(alpha: 0.2)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

