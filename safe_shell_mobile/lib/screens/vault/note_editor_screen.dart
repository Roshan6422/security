import 'package:flutter/material.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import '../../services/api_service.dart';

class NoteEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? note; 

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!['name'] ?? '';
      _contentController.text = widget.note!['content'] ?? '';
    }
  }

  Future<void> _saveNote() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'name': _titleController.text,
        'content': _contentController.text,
        'type': 'note',
      };

      if (widget.note != null) {
        await ApiService().put('/vault/${widget.note!['_id']}', data);
      } else {
        await ApiService().post('/vault', data);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate refresh needed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.note != null ? 'Edit Note' : 'New Note', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveNote,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: AppTextStyles.subheading.copyWith(fontSize: 20),
              decoration: const InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: TextField(
                controller: _contentController,
                style: AppTextStyles.body,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Type your note here...',
                  hintStyle: TextStyle(color: Colors.white30),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
