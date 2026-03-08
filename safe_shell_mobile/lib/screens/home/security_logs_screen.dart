import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/secure_network_viewer.dart';
import 'dart:io';

class SecurityLogsScreen extends StatefulWidget {
  const SecurityLogsScreen({super.key});

  @override
  State<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends State<SecurityLogsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  bool _chainVerified = false;
  int _totalEvents = 0;
  String _activeFilter = 'all';
  String _searchQuery = '';

  final List<String> _filters = ['All', 'Security', 'Files', 'Keys', 'Backup', 'Settings'];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _verifyChain();
  }

  Future<void> _fetchLogs() async {
    try {
      final endpoint = _activeFilter == 'all' ? '/audit' : '/audit?type=${_activeFilter.toLowerCase()}';
      final response = await _api.get(endpoint);
      if (mounted && response != null && response is List) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch logs error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyChain() async {
    try {
      final response = await _api.get('/audit/verify');
      if (mounted && response != null) {
        setState(() {
          _chainVerified = response['verified'] == true;
          _totalEvents = response['totalEvents'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Chain verify error: $e');
    }
  }

  void _setFilter(String filter) {
    setState(() {
      _activeFilter = filter.toLowerCase();
      _isLoading = true;
    });
    _fetchLogs();
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_searchQuery.isEmpty) return _logs;
    return _logs.where((log) {
      final action = (log['action'] ?? '').toString().toLowerCase();
      final detail = (log['detail'] ?? '').toString().toLowerCase();
      return action.contains(_searchQuery.toLowerCase()) ||
          detail.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Color _getEventColor(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('delete')) return Colors.redAccent;
    if (lower.contains('upload') || lower.contains('add') || lower.contains('create')) return const Color(0xFF34D399);
    if (lower.contains('restore')) return Colors.amber;
    if (lower.contains('open') || lower.contains('view')) return AppColors.primary;
    if (lower.contains('login') || lower.contains('auth')) return Colors.amber;
    if (lower.contains('backup')) return Colors.purpleAccent;
    if (lower.contains('setting')) return Colors.tealAccent;
    return AppColors.primary;
  }

  IconData _getEventIcon(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('delete')) return Icons.delete_outline;
    if (lower.contains('upload') || lower.contains('add') || lower.contains('create')) return Icons.cloud_upload_outlined;
    if (lower.contains('restore')) return Icons.restore;
    if (lower.contains('open') || lower.contains('view')) return Icons.visibility_outlined;
    if (lower.contains('login') || lower.contains('auth')) return Icons.lock_open;
    if (lower.contains('backup')) return Icons.backup;
    if (lower.contains('setting')) return Icons.settings;
    return Icons.event_note;
  }

  String _getFileTypeIcon(String? fileType) {
    switch (fileType?.toLowerCase()) {
      case 'photo': return '📷';
      case 'video': return '🎥';
      case 'audio': return '🎵';
      case 'document': return '📄';
      case 'note': return '📝';
      default: return '📁';
    }
  }

  String _formatTimestamp(String? ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {
      return ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Background gradient
          Positioned(
            top: -80, left: -60,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.purpleAccent.withOpacity(0.08), Colors.transparent],
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
                      Text(
                        'Security Logs',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Log export coming soon')),
                          );
                        },
                        icon: const Icon(Icons.download, color: Colors.white54),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _fetchLogs();
                          _verifyChain();
                        },
                        icon: const Icon(Icons.refresh, color: Colors.white54),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            // Search Bar
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: TextField(
                                onChanged: (v) => setState(() => _searchQuery = v),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  icon: Icon(Icons.search, color: Colors.white.withOpacity(0.3)),
                                  hintText: 'Search logs...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Filter Tabs
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _filters.map((f) {
                                  final isActive = _activeFilter == f.toLowerCase();
                                  return GestureDetector(
                                    onTap: () => _setFilter(f),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? AppColors.primary.withOpacity(0.15)
                                            : Colors.white.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isActive
                                              ? AppColors.primary.withOpacity(0.4)
                                              : Colors.white.withOpacity(0.08),
                                        ),
                                      ),
                                      child: Text(
                                        f,
                                        style: TextStyle(
                                          color: isActive ? AppColors.primary : Colors.white54,
                                          fontSize: 13,
                                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Chain Verification Banner
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (_chainVerified ? Colors.green : Colors.red).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _chainVerified ? Icons.verified : Icons.error,
                                      color: _chainVerified ? Colors.green : Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _chainVerified ? 'Chain Verified ✓' : 'Chain Compromised ✗',
                                        style: TextStyle(
                                          color: _chainVerified ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        'All $_totalEvents events verified',
                                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Events count
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Showing ${filtered.length} of $_totalEvents events',
                                  style: const TextStyle(color: Colors.white30, fontSize: 12),
                                ),
                                Text(
                                  filtered.isNotEmpty
                                      ? 'Latest: ${_formatTimestamp(filtered.first['timestamp'])}'
                                      : '',
                                  style: const TextStyle(color: Colors.white30, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Log Entries
                            if (filtered.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 48),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.event_note, size: 48, color: Colors.white.withOpacity(0.1)),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No events found',
                                        style: TextStyle(color: Colors.white30, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...filtered.map((log) => _buildLogEntry(log)),

                            const SizedBox(height: 80),
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

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final action = log['action'] ?? '';
    final detail = log['detail'] ?? '';
    final timestamp = log['timestamp'] ?? '';
    final fileUrl = log['fileUrl'] as String?;
    final fileType = log['fileType'] as String?;
    final color = _getEventColor(action);
    final icon = _getEventIcon(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(timestamp),
                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (fileType != null) ...[
                          Text(
                            _getFileTypeIcon(fileType),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            detail,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // File thumbnail preview
            if (fileUrl != null && fileUrl.isNotEmpty && fileType != null)
              _buildThumbnail(fileUrl, fileType),
          ],
        ),
    );
  }

  Widget _buildThumbnail(String fileUrl, String fileType) {
    final type = fileType.toLowerCase();

    // Only show image thumbnails for photos
    if (type == 'photo') {
      return Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withOpacity(0.05),
        ),
        clipBehavior: Clip.antiAlias,
        child: SecureNetworkViewer(
          relativeUrl: fileUrl,
          builder: (context, localPath) => Image.file(
            File(localPath),
            fit: BoxFit.cover,
            width: 48,
            height: 48,
          ),
          loadingWidget: const Center(
            child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
            ),
          ),
          errorBuilder: (context, error) => const Icon(
            Icons.image_outlined,
            color: Colors.white24,
            size: 20,
          ),
        ),
      );
    }

    // For video/audio/document, show an icon thumbnail
    IconData thumbIcon;
    Color thumbColor;

    switch (type) {
      case 'video':
        thumbIcon = Icons.videocam_rounded;
        thumbColor = AppColors.videos;
        break;
      case 'audio':
        thumbIcon = Icons.audiotrack_rounded;
        thumbColor = const Color(0xFFFB7185);
        break;
      case 'document':
        thumbIcon = Icons.description_outlined;
        thumbColor = AppColors.documents;
        break;
      default:
        thumbIcon = Icons.insert_drive_file;
        thumbColor = AppColors.primary;
    }

    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: thumbColor.withOpacity(0.1),
        border: Border.all(color: thumbColor.withOpacity(0.2)),
      ),
      child: Icon(thumbIcon, color: thumbColor, size: 22),
    );
  }
}
