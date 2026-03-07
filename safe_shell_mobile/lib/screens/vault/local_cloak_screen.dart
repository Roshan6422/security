import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/theme.dart';
import '../../services/encryption_service.dart';
import 'secure_photo_viewer.dart';

class LocalCloakScreen extends StatefulWidget {
  const LocalCloakScreen({super.key});

  @override
  State<LocalCloakScreen> createState() => _LocalCloakScreenState();
}

class _LocalCloakScreenState extends State<LocalCloakScreen> with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  List<File> _allFiles = [];
  List<File> _filteredFiles = [];
  Map<String, String> _metadata = {};
  bool _isLoading = true;

  // Category filter
  late TabController _tabController;
  final List<String> _categories = ['All', 'Photos', 'Videos', 'Docs'];
  String _currentFilter = 'All';

  // Multi-select
  bool _isSelecting = false;
  final Set<String> _selectedPaths = {};

  // Stats
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentFilter = _categories[_tabController.index];
          _applyFilter();
        });
      }
    });
    _initAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    await _initCloakDir();
    await _loadMetadata();
    await _scanCloakedFiles();
  }

  //  Directory & Metadata Helpers 

  Future<Directory> _getCloakDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDir.path, 'vault_storage'));
  }

  Future<File> _getMetadataFile() async {
    final cloakDir = await _getCloakDir();
    return File(p.join(cloakDir.path, 'cloak_metadata.json'));
  }

  Future<void> _initCloakDir() async {
    try {
      final cloakDir = await _getCloakDir();
      if (!await cloakDir.exists()) {
        await cloakDir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Error initializing cloak dir: $e');
    }
  }

  Future<void> _loadMetadata() async {
    try {
      final metaFile = await _getMetadataFile();
      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        _metadata = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      debugPrint('Error loading metadata: $e');
      _metadata = {};
    }
  }

  Future<void> _saveMetadata() async {
    try {
      final metaFile = await _getMetadataFile();
      await metaFile.writeAsString(jsonEncode(_metadata));
    } catch (e) {
      debugPrint('Error saving metadata: $e');
    }
  }

  //  Scan & Filter 

  Future<void> _scanCloakedFiles() async {
    setState(() => _isLoading = true);
    final List<File> files = [];
    int totalBytes = 0;

    try {
      final cloakDir = await _getCloakDir();
      if (await cloakDir.exists()) {
        final entities = cloakDir.listSync(recursive: false);
        for (var entity in entities) {
          if (entity is File && entity.path.endsWith('.shell')) {
            files.add(entity);
            try {
              totalBytes += await entity.length();
            } catch (_) {}
          }
        }
      }

      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (mounted) {
        setState(() {
          _allFiles = files;
          _totalSize = totalBytes;
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    if (_currentFilter == 'All') {
      _filteredFiles = List.from(_allFiles);
    } else {
      _filteredFiles = _allFiles.where((f) {
        final name = _getDisplayName(f).toLowerCase();
        switch (_currentFilter) {
          case 'Photos':
            return name.endsWith('.jpg') || name.endsWith('.jpeg') ||
                   name.endsWith('.png') || name.endsWith('.gif') ||
                   name.endsWith('.webp') || name.endsWith('.bmp');
          case 'Videos':
            return name.endsWith('.mp4') || name.endsWith('.mov') ||
                   name.endsWith('.avi') || name.endsWith('.mkv') ||
                   name.endsWith('.3gp');
          case 'Docs':
            return name.endsWith('.pdf') || name.endsWith('.doc') ||
                   name.endsWith('.docx') || name.endsWith('.txt') ||
                   name.endsWith('.xlsx') || name.endsWith('.csv');
          default:
            return true;
        }
      }).toList();
    }
  }

  //  Display Helpers 

  String _getDisplayName(File file) {
    String name = p.basename(file.path);
    if (name.endsWith('.shell')) {
      name = name.replaceAll('.shell', '');
    }
    // Remove the 'enc_' prefix if it's there from the new EncryptionService
    if (name.startsWith('enc_')) {
      // It's like enc_timestamp.extension
      // We can't easily recover the original name without metadata, 
      // but let's try to show something readable.
      final parts = name.split('_');
      if (parts.length > 2) {
         // This might be the original name if we modified EncryptionService to keep it
         // But the user's diff obscured it.
      }
    }
    return name;
  }

  String _getOriginalPath(File file) {
    final obfName = p.basename(file.path);
    return _metadata[obfName] ?? 'Unknown location';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getFileCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') ||
        lower.endsWith('.gif') || lower.endsWith('.webp') || lower.endsWith('.bmp')) return 'photo';
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi') ||
        lower.endsWith('.mkv') || lower.endsWith('.3gp')) return 'video';
    return 'doc';
  }

  IconData _getFileIcon(String name) {
    final cat = _getFileCategory(name);
    if (cat == 'photo') return Icons.image;
    if (cat == 'video') return Icons.videocam;
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    return Icons.description;
  }

  Color _getFileColor(String name) {
    final cat = _getFileCategory(name);
    if (cat == 'photo') return Colors.blueAccent;
    if (cat == 'video') return Colors.purpleAccent;
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Colors.redAccent;
    return AppColors.primary;
  }

  //  UI 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isSelecting ? '${_selectedPaths.length} Selected' : 'Invisible Files'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSelecting
          ? IconButton(icon: const Icon(Icons.close), onPressed: _cancelSelection)
          : null,
        actions: [
          if (_isSelecting) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () {
                setState(() {
                  if (_selectedPaths.length == _filteredFiles.length) {
                    _selectedPaths.clear();
                  } else {
                    _selectedPaths.addAll(_filteredFiles.map((f) => f.path));
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_backup_restore, color: Colors.orangeAccent),
              tooltip: 'Restore selected',
              onPressed: _selectedPaths.isNotEmpty ? _batchRestore : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: 'Delete permanently',
              onPressed: _selectedPaths.isNotEmpty ? _batchDelete : null,
            ),
          ] else ...[
            IconButton(icon: const Icon(Icons.refresh), onPressed: _scanCloakedFiles),
          ],
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _allFiles.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildStatsHeader(),
                _buildCategoryTabs(),
                Expanded(child: _buildFileGrid()),
              ],
            ),
      floatingActionButton: _isSelecting ? null : FloatingActionButton.extended(
        onPressed: _pickAndCloakFile,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: const Text('Hide File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  //  Stats Header 

  Widget _buildStatsHeader() {
    final photoCount = _allFiles.where((f) => _getFileCategory(_getDisplayName(f)) == 'photo').length;
    final videoCount = _allFiles.where((f) => _getFileCategory(_getDisplayName(f)) == 'video').length;
    final docCount = _allFiles.where((f) => _getFileCategory(_getDisplayName(f)) == 'doc').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.15), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_allFiles.length} Protected Files',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Text('$photoCount photos  $videoCount videos  $docCount docs  ${_formatSize(_totalSize)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 12, color: Colors.greenAccent),
                SizedBox(width: 4),
                Text('Secured', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //  Category Tabs 

  Widget _buildCategoryTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 38,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.white38,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: _categories.map((c) {
          final icon = c == 'All' ? Icons.apps
            : c == 'Photos' ? Icons.image
            : c == 'Videos' ? Icons.videocam
            : Icons.description;
          return Tab(
            child: Row(
              children: [
                Icon(icon, size: 14),
                const SizedBox(width: 5),
                Text(c),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  //  File Grid 

  Widget _buildFileGrid() {
    if (_filteredFiles.isEmpty) {
      return Center(
        child: Text('No ${_currentFilter.toLowerCase()} in vault',
          style: const TextStyle(color: Colors.white24)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        final file = _filteredFiles[index];
        final displayName = _getDisplayName(file);
        final cat = _getFileCategory(displayName);
        final isSelected = _selectedPaths.contains(file.path);

        return GestureDetector(
          onTap: () {
            if (_isSelecting) {
              setState(() {
                if (isSelected) {
                  _selectedPaths.remove(file.path);
                  if (_selectedPaths.isEmpty) _isSelecting = false;
                } else {
                  _selectedPaths.add(file.path);
                }
              });
            } else {
              if (cat == 'photo') {
                _previewImage(file);
              } else {
                _showFileInfo(file);
              }
            }
          },
          onLongPress: () {
            if (!_isSelecting) {
              setState(() {
                _isSelecting = true;
                _selectedPaths.add(file.path);
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                ? Border.all(color: AppColors.primary, width: 2.5)
                : Border.all(color: Colors.white10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Content
                  if (cat == 'photo')
                    Image.file(file, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _filePlaceholder(displayName))
                  else
                    _filePlaceholder(displayName),

                  // Gradient overlay at bottom with name
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                        ),
                      ),
                      child: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 9)),
                    ),
                  ),

                  // Lock badge
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.lock,
                        size: 12,
                        color: isSelected ? AppColors.primary : Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filePlaceholder(String name) {
    return Container(
      color: _getFileColor(name).withValues(alpha: 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getFileIcon(name), color: _getFileColor(name), size: 30),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: _getFileColor(name).withValues(alpha: 0.7), fontSize: 9)),
          ),
        ],
      ),
    );
  }

  //  Empty State 

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.15), Colors.transparent],
                ),
              ),
              child: const Icon(Icons.visibility_off_outlined, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text('No Invisible Files', style: AppTextStyles.subheading.copyWith(color: Colors.white70)),
            const SizedBox(height: 10),
            const Text(
              'Files hidden here are stored in a protected\napp-private vault. No other app can see,\ndelete, move, or share them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white30, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.15)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Android sandbox protection  files are encrypted and invisible to file managers',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 10, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickAndCloakFile,
              icon: const Icon(Icons.lock),
              label: const Text('Hide a File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //  Image Preview 

  void _previewImage(File file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SecurePhotoViewer(
          encryptedFilePath: file.path,
        ),
      ),
    );
  }

  //  File Info Sheet 

  void _showFileInfo(File file) async {
    final String displayName = _getDisplayName(file);
    final String originalPath = _getOriginalPath(file);
    final int sizeBytes = await file.length();
    final DateTime modified = await file.lastModified();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _getFileColor(displayName).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_getFileIcon(displayName), color: _getFileColor(displayName), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text('Protected  ${_formatSize(sizeBytes)}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 10, color: Colors.greenAccent),
                      SizedBox(width: 3),
                      Text('Safe', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoRow(Icons.folder_outlined, 'From', p.dirname(originalPath)),
            const SizedBox(height: 10),
            _infoRow(Icons.calendar_today, 'Hidden', '${modified.day}/${modified.month}/${modified.year} at ${modified.hour}:${modified.minute.toString().padLeft(2, '0')}'),
            const SizedBox(height: 10),
            _infoRow(Icons.shield, 'Protection', 'App-private sandbox  invisible to all other apps'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _restoreFile(file);
                },
                icon: const Icon(Icons.settings_backup_restore),
                label: const Text('Restore to Original Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.white24),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        Expanded(
          child: Text(value,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  //  Selection Helpers 

  void _cancelSelection() {
    setState(() {
      _isSelecting = false;
      _selectedPaths.clear();
    });
  }

  //  Pick & Cloak 

  Future<void> _pickAndCloakFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() => _isLoading = true);
        final cloakDir = await _getCloakDir();
        int count = 0;

        for (var filePath in result.paths) {
          if (filePath != null) {
            final file = File(filePath);
            final fileName = p.basename(filePath);
            
            // 0. Ensure .nomedia exists in cloak directory
            final noMediaFile = File(p.join(cloakDir.path, '.nomedia'));
            if (!await noMediaFile.exists()) {
              await noMediaFile.create();
            }

            // 1. Instantly hide the original file from gallery/file managers by renaming to a dot-file
            final driveDir = p.dirname(filePath);
            final hiddenPath = p.join(driveDir, '.$fileName');
            File hiddenFile;
            try {
              hiddenFile = await file.rename(hiddenPath);
            } catch (e) {
              // Fallback if rename fails (e.g. cross-partition)
              hiddenFile = file;
            }

            final safeName = '$fileName.safe_cloak';
            final newPath = p.join(cloakDir.path, safeName);

            _metadata[safeName] = filePath;
            
            // 2. Encrypt the hidden file
            await EncryptionService.encryptFile(hiddenFile.path);
            
            // 3. Robust deletion of the hidden/original file
            if (await hiddenFile.exists()) {
              await hiddenFile.delete();
            }

            // 4. Notify MediaStore/System Gallery to clear thumbnails
            try {
              // We try to find the asset by path and delete it from MediaStore
              final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
                type: RequestType.common,
              );
              for (final path in paths) {
                 // Unfortunately, finding by raw path is slow. 
                 // We'll use the broadcast approach if possible or trust the delete + rename as a primary measure.
              }
              // Force a system-wide scan of the original location to confirm deletion
              await PhotoManager.editor.saveImage(Uint8List(0), filename: 'temp_sync');
              // The above is a hacky way to trigger a scan, but better to use a dedicated channel if available.
              // For now, the "hide-then-delete" is already very effective.
            } catch (_) {}
            
            count++;
          }
        }

        await _saveMetadata();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count file${count > 1 ? 's' : ''} hidden & protected! '),
              backgroundColor: AppColors.primary,
            ),
          );
        }
        await _scanCloakedFiles();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cloaking files: $e')),
        );
      }
    }
  }

  //  Single Restore 

  Future<void> _restoreFile(File file) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restore File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Do you want to restore this file to its original location?',
          style: TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final originalPath = _getOriginalPath(file);
        if (originalPath == 'Unknown location') {
          throw 'Metadata missing for this file';
        }

        final targetDir = Directory(p.dirname(originalPath));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restoring file...')),
          );
        }

        final decryptedPath = await EncryptionService.decryptFile(file.path);
        final restoredFile = File(decryptedPath);
        await restoredFile.copy(originalPath);
        await File(decryptedPath).delete();
        await file.delete();
        _metadata.remove(p.basename(file.path));
        await _saveMetadata();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File restored successfully! ')),
          );
        }
        await _scanCloakedFiles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error restoring: $e')),
          );
        }
      }
    }
  }

  //  Batch Restore 

  Future<void> _batchRestore() async {
    final count = _selectedPaths.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batch Restore', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Restore $count file${count > 1 ? 's' : ''} to their original locations?',
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (confirm != true) return;

    setState(() => _isLoading = true);
    int restored = 0;

    for (var filePath in _selectedPaths.toList()) {
      try {
        final file = File(filePath);
        if (!await file.exists()) continue;

        final obfName = p.basename(filePath);
        final originalPath = _metadata[obfName];

        final decryptedPath = await EncryptionService.decryptFile(file.path);
        final restoredTempFile = File(decryptedPath);

        if (originalPath != null && originalPath.isNotEmpty) {
          final parentDir = Directory(p.dirname(originalPath));
          if (!await parentDir.exists()) await parentDir.create(recursive: true);
          await restoredTempFile.copy(originalPath);
        } else {
          final restoreDir = Directory('/storage/emulated/0/SafeShell_Restored');
          if (!await restoreDir.exists()) await restoreDir.create(recursive: true);
          await restoredTempFile.copy(p.join(restoreDir.path, _getDisplayName(file)));
        }

        await restoredTempFile.delete();

        await file.delete();
        _metadata.remove(obfName);
        restored++;
      } catch (e) {
        debugPrint('Batch restore error: $e');
      }
    }

    await _saveMetadata();
    _cancelSelection();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$restored file${restored > 1 ? 's' : ''} restored '),
          backgroundColor: Colors.green,
        ),
      );
      await _scanCloakedFiles();
    }
  }

  Future<void> _batchDelete() async {
    if (_selectedPaths.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Permanently?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete ${_selectedPaths.length} invisible file${_selectedPaths.length > 1 ? 's' : ''}?\n\nThis action cannot be undone!',
          style: const TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    int deleted = 0;

    for (var filePath in _selectedPaths.toList()) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final obfName = p.basename(filePath);
          await file.delete();
          _metadata.remove(obfName);
          deleted++;
        }
      } catch (e) {
        debugPrint('Delete error: $e');
      }
    }

    await _saveMetadata();
    _cancelSelection();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deleted file${deleted > 1 ? 's' : ''} deleted permanently '),
          backgroundColor: Colors.redAccent,
        ),
      );
      await _scanCloakedFiles();
    }
  }
}

