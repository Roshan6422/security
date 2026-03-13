import 'package:flutter/material.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_card.dart';
import 'package:file_picker/file_picker.dart';
import 'note_editor_screen.dart';

class VaultListScreen extends StatefulWidget {
  final String title;
  final String type; // 'photo', 'video', 'document', 'zip', 'note'

  const VaultListScreen({super.key, required this.title, required this.type});

  @override
  State<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends State<VaultListScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final response = await ApiService().get('/vault?type=${widget.type}');
      if (mounted) {
        setState(() {
          // Filter out deleted items (API handles it, but just in case)
          _items = (response as List).where((i) => i['isDeleted'] != true).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Error fetching vault items: $e');
      }
    }
  }

  Future<void> _uploadFile() async {
    try {
      if (widget.type == 'note') {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
        );
        if (result == true) _fetchItems();
        return;
      }

      FileType fileType = FileType.any;
      if (widget.type == 'photo') fileType = FileType.image;
      if (widget.type == 'video') fileType = FileType.video;
      if (widget.type == 'document') fileType = FileType.any; // FileType.custom requires extensions

      FilePickerResult? result = await FilePicker.platform.pickFiles(type: fileType);

      if (result != null) {
        final platformFile = result.files.single;
        // Handle upload via ApiService multipart helper (needs implementation) or manual
        // ApiService currently only supports JSON. Need to add upload support or use http directly.
        await _uploadToServer(platformFile);
        _fetchItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Error: $e')));
      }
    }
  }

  Future<void> _uploadToServer(PlatformFile file) async {
    if (file.path != null) {
      await ApiService().uploadMultipart('/vault/upload', file.path!);
    }
  }

  Future<void> _deleteItem(String id) async {
     try {
        await ApiService().delete('/vault/$id'); // Soft delete
        await _fetchItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moved to Recycle Bin')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title, style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchItems,
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Text('No ${widget.title} yet', style: AppTextStyles.body.copyWith(color: Colors.white54)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return GestureDetector(
                        onLongPress: () => _deleteItem(item['_id']),
                        onTap: () async {
                          if (item['type'] == 'note') {
                             final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => NoteEditorScreen(note: item)),
                            );
                            if (result == true) _fetchItems();
                            return;
                          }
                          // Open file logic
                          if (item['url'] != null) {
                             // Construct full URL
                             // For mobile, we might need to download first, but open_filex works on local files.
                             // ApiServe might need a download method.
                             // For now, let's assume we just print it, or try to launch URL if it's web.
                             // Actually, on mobile we need to download to temp dir then open.
                             // Skipping complex download logic for this step, just showing snackbar as implemented.
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Viewing ${item['name']} coming next (Needs download logic)')));
                          }
                        },
                        child: GlassCard(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Expanded(
                                        child: item['type'] == 'photo' && item['url'] != null
                                            ? Image.network(
                                                // Assuming URL is relative, prepend Base URL
                                                '${ApiService.currentBaseUrl.replaceAll('/api', '')}${item['url']}',
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white54),
                                              )
                                            : Icon(
                                                widget.type == 'video' ? Icons.videocam : Icons.insert_drive_file,
                                                size: 48, 
                                                color: Colors.white54
                                              ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(item['name'] ?? '', style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                                    Text(item['size'] ?? '', style: AppTextStyles.caption.copyWith(fontSize: 10, color: Colors.white30)),
                                ],
                            ),
                        ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadFile,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.upload),
      ),
    );
  }
}
