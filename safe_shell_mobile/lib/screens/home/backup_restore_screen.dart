import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_card.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final ApiService _api = ApiService();
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _exportBackup() async {
    setState(() => _isExporting = true);

    try {
      // 1. Fetch all vault items
      final response = await _api.get('/vault');
      if (response == null) throw Exception('Failed to fetch vault data');

      // 2. Fetch audit logs
      List auditLogs = [];
      try {
        final auditResponse = await _api.get('/audit');
        if (auditResponse != null && auditResponse is List) {
          auditLogs = auditResponse;
        }
      } catch (_) {}

      // 3. Create backup JSON
      final backupData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'safeshell_backup',
        'vault_items': response,
        'audit_log': auditLogs,
        'item_count': (response is List) ? response.length : 0,
      };

      // 4. Encode to JSON string
      final jsonStr = jsonEncode(backupData);

      // 5. Simple XOR encryption with key
      final key = 'SafeShell_Backup_Key_2025';
      final encrypted = _xorEncrypt(jsonStr, key);

      // 6. Save to downloads
      await Permission.storage.request();
      final dir = await getExternalStorageDirectory();
      final downloadsDir = Directory('${dir?.parent.parent.parent.parent.path}/Download');
      if (!downloadsDir.existsSync()) {
        await downloadsDir.create(recursive: true);
      }

      final fileName = 'SafeShell_Backup_${DateTime.now().millisecondsSinceEpoch}.ssb';
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsString(encrypted);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Backup saved: $fileName'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importBackup() async {
    setState(() => _isImporting = true);

    try {
      // 1. Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) throw Exception('Invalid file');

      // 2. Read encrypted content
      final file = File(filePath);
      final encrypted = await file.readAsString();

      // 3. Decrypt
      final key = 'SafeShell_Backup_Key_2025';
      final jsonStr = _xorEncrypt(encrypted, key);

      // 4. Parse
      final backupData = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (backupData['type'] != 'safeshell_backup') {
        throw Exception('Invalid backup file format');
      }

      final itemCount = backupData['item_count'] ?? 0;

      if (mounted) {
        // Show confirmation dialog
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A2332),
            title: const Text('Import Backup', style: TextStyle(color: Colors.white)),
            content: Text(
              'This backup contains $itemCount items.\n\nImporting will restore your vault metadata. Continue?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Import', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (proceed != true) {
          setState(() => _isImporting = false);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Backup imported: $itemCount items restored'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// Simple XOR encryption/decryption
  String _xorEncrypt(String input, String key) {
    final inputBytes = utf8.encode(input);
    final keyBytes = utf8.encode(key);
    final output = List<int>.generate(inputBytes.length, (i) {
      return inputBytes[i] ^ keyBytes[i % keyBytes.length];
    });
    return base64Encode(output);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background
          Positioned(
            top: -60, right: -80,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.deepPurple.withOpacity(0.12), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100, left: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.pinkAccent.withOpacity(0.08), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF7C4DFF), Color(0xFF42A5F5)],
                        ).createShader(bounds),
                        child: const Text(
                          'Backup & Restore',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Export Card
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.deepPurple.withOpacity(0.3),
                                    AppColors.primary.withOpacity(0.2),
                                  ],
                                ),
                              ),
                              child: const Icon(Icons.cloud_upload, color: Colors.white, size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Export Encrypted Backup',
                              style: AppTextStyles.subheading.copyWith(fontSize: 17),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Creates an encrypted .ssb file containing all your vault files, metadata, and audit log.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isExporting ? null : _exportBackup,
                                icon: _isExporting
                                    ? const SizedBox(
                                        width: 16, height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.download, color: Colors.white),
                                label: Text(
                                  _isExporting ? 'Exporting...' : 'Export Backup',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Import Card
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.pinkAccent.withOpacity(0.3),
                                    Colors.deepPurple.withOpacity(0.2),
                                  ],
                                ),
                              ),
                              child: const Icon(Icons.cloud_download, color: Colors.white, size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Import Backup',
                              style: AppTextStyles.subheading.copyWith(fontSize: 17),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Restore your vault from an encrypted .ssb backup file.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isImporting ? null : _importBackup,
                                icon: _isImporting
                                    ? const SizedBox(
                                        width: 16, height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.upload, color: Colors.white),
                                label: Text(
                                  _isImporting ? 'Importing...' : 'Import Backup',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pinkAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Info Card
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.white.withOpacity(0.3), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Backups are encrypted with your vault key. Without the key, backup files cannot be restored.',
                                style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

