import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_card.dart';

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

  final List<String> _filters = ['Security', 'Files', 'Keys', 'Backup', 'Settings'];

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
    if (lower.contains('add') || lower.contains('create')) return Colors.greenAccent;
    if (lower.contains('open') || lower.contains('view')) return AppColors.primary;
    if (lower.contains('login') || lower.contains('auth')) return Colors.amber;
    if (lower.contains('backup')) return Colors.purpleAccent;
    if (lower.contains('setting')) return Colors.tealAccent;
    return AppColors.primary;
  }

  IconData _getEventIcon(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('delete')) return Icons.delete_outline;
    if (lower.contains('add') || lower.contains('create')) return Icons.add_circle_outline;
    if (lower.contains('open') || lower.contains('view')) return Icons.open_in_new;
    if (lower.contains('login') || lower.contains('auth')) return Icons.lock_open;
    if (lower.contains('backup')) return Icons.backup;
    if (lower.contains('setting')) return Icons.settings;
    return Icons.event_note;
  }

  String _formatTimestamp(String? ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts);
      return DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {
      return ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  colors: [Colors.purpleAccent.withOpacity(0.1), Colors.transparent],
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
                          colors: [Color(0xFF9C27B0), Color(0xFF42A5F5)],
                        ).createShader(bounds),
                        child: const Text(
                          'Security Logs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
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
                            GlassCard(
                              padding: const EdgeInsets.all(16),
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
                                        style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 12),
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
                                  style: AppTextStyles.caption.copyWith(color: Colors.white30, fontSize: 12),
                                ),
                                Text(
                                  filtered.isNotEmpty
                                      ? 'Latest: ${_formatTimestamp(filtered.first['timestamp'])}'
                                      : '',
                                  style: AppTextStyles.caption.copyWith(color: Colors.white30, fontSize: 12),
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
                                      Text(
                                        'No events found',
                                        style: AppTextStyles.body.copyWith(color: Colors.white30),
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
    final color = _getEventColor(action);
    final icon = _getEventIcon(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(timestamp),
                    style: AppTextStyles.caption.copyWith(color: Colors.white30, fontSize: 11),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
