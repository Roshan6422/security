import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import 'package:http/http.dart' as http;
import '../../services/network_service.dart';
import '../../services/audit_logger.dart';

class NoteEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? note; 

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  String? _currentNoteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.note != null) {
      _currentNoteId = widget.note!['_id'];
      _titleController.text = widget.note!['name'] ?? '';
      _contentController.text = widget.note!['content'] ?? '';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_hasUnsavedChanges && _titleController.text.isNotEmpty) {
       _autoSaveNote(); // Final background best-effort save
    }
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_hasUnsavedChanges && _titleController.text.isNotEmpty) {
        _autoSaveNote();
      }
    }
  }

  Future<void> _autoSaveNote({bool silent = true}) async {
    if (!_hasUnsavedChanges || _titleController.text.isEmpty) return;
    try {
      const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
      final token = await storage.read(key: AppConstants.keyToken);
      if (token == null) return;

      final body = {
        'name': _titleController.text,
        'content': _contentController.text,
        'type': 'note',
        'size': '${_contentController.text.length} B',
      };

      http.Response response;
      if (_currentNoteId != null) {
        response = await NetworkService.client.put(
          Uri.parse('${AppConstants.baseUrl}/vault/$_currentNoteId'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      } else {
        response = await NetworkService.client.post(
          Uri.parse('${AppConstants.baseUrl}/vault'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) setState(() => _hasUnsavedChanges = false);
        final noteName = _titleController.text;
        
        if (_currentNoteId == null) {
          AuditLogger.logNoteCreate(noteName);
          try {
            final data = jsonDecode(response.body);
            if (data['document'] != null && data['document']['_id'] != null) {
              _currentNoteId = data['document']['_id'];
            }
          } catch (_) {}
        } else {
          AuditLogger.logNoteUpdate(noteName);
        }
      } else if (!silent) {
        throw Exception('Failed to save note: ${response.statusCode}');
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _saveNote() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }

    setState(() => _isLoading = true);
    await _autoSaveNote(silent: false);
    if (mounted) {
       setState(() => _isLoading = false);
       if (!_hasUnsavedChanges) {
         Navigator.pop(context, true);
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final hintColor = isLight ? Colors.black38 : Colors.white54;
    final contentHintColor = isLight ? Colors.black26 : Colors.white30;
    final iconColor = isLight ? AppColors.textPrimary : Colors.white;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isLight ? Colors.white : AppColors.darkSurface,
            title: Text('Discard Changes?', style: TextStyle(color: iconColor)),
            content: Text('You have unsaved changes. Are you sure you want to discard them?', style: TextStyle(color: iconColor.withOpacity(0.7))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (shouldPop == true && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: isLight ? AppColors.background : AppColors.darkBackground,
        appBar: AppBar(
          title: Text(widget.note != null ? 'Edit Note' : 'New Note', style: AppTextStyles.heading.copyWith(color: iconColor)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: _isLoading ? CircularProgressIndicator(color: iconColor) : Icon(Icons.save, color: iconColor),
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
                onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                style: AppTextStyles.subheading.copyWith(fontSize: 20, color: iconColor),
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: TextStyle(color: hintColor),
                  border: InputBorder.none,
                ),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                  style: AppTextStyles.body.copyWith(color: iconColor),
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    hintText: 'Type your note here...',
                    hintStyle: TextStyle(color: contentHintColor),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
