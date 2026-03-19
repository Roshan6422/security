import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;

import '../../core/theme.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/vault_stats_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart' as model;
import 'security_logs_screen.dart';
import '../vault/vault_screen.dart';
import '../settings/support_screen.dart';
import '../calculator/calculator_screen.dart';
import '../browser/private_browser_screen.dart';
import '../analytics/analytics_screen.dart';
import '../../main.dart';

import '../../widgets/premium_snackbar.dart';
import '../../widgets/section_card.dart';
import '../../utils/vault_encryption_helper.dart';


/// Smooth page transition for premium navigation
class _InstantPageRoute<T> extends MaterialPageRoute<T> {
  _InstantPageRoute({required super.builder});
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Quota single source of truth
  static const int _freePlanQuotaBytes = 5 * 1024 * 1024 * 1024;

  bool _isLoading = true;
  final bool _isOffline = false;
  int _fileCount = 0;
  int _photoCount = 0;
  int _videoCount = 0;
  int _docCount = 0;
  int _noteCount = 0;
  String _storageUsed = '0.0 GB';
  double _storagePercent = 0.0;
  List<dynamic> _recentItems = [];

  // Animations removed manually by request

  // Security tips
  static const List<Map<String, dynamic>> _securityTips = [
    {'icon': Icons.face_rounded, 'tip': 'Enable Face Lock for instant secure access', 'color': AppColors.primary},
    {'icon': Icons.vpn_lock_rounded, 'tip': 'Use Private Browser to leave zero digital footprint', 'color': Color(0xFF8B5CF6)},
    {'icon': Icons.cloud_upload_rounded, 'tip': 'Back up your vault regularly to prevent data loss', 'color': Color(0xFF10B981)},
    {'icon': Icons.grid_view_rounded, 'tip': 'Use Calculator disguise to hide your vault entrance', 'color': Color(0xFFF59E0B)},
    {'icon': Icons.lock_outline_rounded, 'tip': 'Set a strong PIN  avoid birthdays and simple patterns', 'color': Color(0xFFEF4444)},
    {'icon': Icons.bolt_rounded, 'tip': 'Run Optimize weekly to clear cached data and save space', 'color': Color(0xFF10B981)},
  ];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;

    // Use cache-first pattern for instant UI paint
    await VaultStatsService().getAggregatedStats(
      onRefresh: (freshStats) {
        if (!mounted) return;
        _updateUIFromStats(freshStats, isCache: false);
      },
    ).then((cachedStats) {
      if (!mounted) return;
      _updateUIFromStats(cachedStats, isCache: true);
    });
  }

  void _updateUIFromStats(VaultStats stats, {required bool isCache}) {
    setState(() {
      _fileCount = stats.totalCount;
      _photoCount = stats.photoCount;
      _videoCount = stats.videoCount;
      _docCount = stats.docCount;
      _noteCount = stats.noteCount;
      _storageUsed = stats.sizeFormatted;
      _storagePercent = (stats.totalSizeBytes / _freePlanQuotaBytes).clamp(0.0, 1.0);
      _recentItems = stats.recentItems;
      if (!isCache || _fileCount > 0) {
        _isLoading = false;
      }
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getUserFirstName() {
    // context.select — only rebuilds when user.name changes, not on any AuthProvider change
    final user = context.select<AuthProvider, model.User?>((a) => a.user);
    if (user != null && user.name.isNotEmpty) return user.name.split(' ').first;
    return '';
  }

  int _getSecurityScore() {
    // context.select — subscribes only to (user, fileCount)
    final user = context.select<AuthProvider, model.User?>((a) => a.user);
    int score = 60;
    if (user != null) score += 10;
    if (_fileCount > 0) score += 10;
    if (user?.subscriptionStatus == 'premium') score += 10;
    score += 10;
    return score.clamp(0, 100);
  }

  /// Navigate with smooth transition
  void _navigate(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _anim(int index, Widget child) {
    return child; // Removed animation
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? AppColors.textPrimary : Colors.white;
    final subColor = isLight ? AppColors.textSecondary : Colors.white.withOpacity(0.4);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: GestureDetector(
          onLongPress: () async {
            try {
              final auth = LocalAuthentication();
              final bios = await auth.getAvailableBiometrics();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: Colors.blueAccent,
                  behavior: SnackBarBehavior.floating,
                  content: Text('Detected Hardware: $bios', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  duration: const Duration(seconds: 15),
                ));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bio Error: $e')));
            }
          },
          child: FloatingActionButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _showUploadOptions(context);
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
      body: Stack(
        children: [
          RepaintBoundary(child: _buildAnimatedBackground()),
          const RepaintBoundary(child: _DotGridLayer()),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchDashboardData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _anim(0, _buildHeader(textColor)),            // 0: header + bell
                    const SizedBox(height: 10),
                    if (_isOffline)
                      _anim(0, Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You are currently offline. Vault features require an internet connection.',
                                style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      )),
                    if (!_isOffline) const SizedBox(height: 10),
                    _anim(1, _buildStorageCard(textColor, subColor)),        // 1: shimmer storage
                    const SizedBox(height: 16),
                    _anim(2, _buildStatRow(textColor, subColor)),            // 2: count-up stats
                    const SizedBox(height: 16),
                    _anim(3, _buildQuickActions(textColor)),       // 3: quick actions
                    const SizedBox(height: 16),
                    _anim(4, _buildSecurityRow(textColor, subColor)),        // 4: security score + sparkline
                    const SizedBox(height: 16),
                    _anim(5, _buildSecurityTip(color: AppColors.primary)),        // 5: daily tip
                    const SizedBox(height: 24),
                    _anim(6, _buildRecentHeader(textColor)),       // 6: recent header
                    const SizedBox(height: 10),
                    _anim(7, _buildRecentContent(textColor, subColor)),      // 7: recent content
                    const SizedBox(height: 24),
                    _anim(8, _buildToolsSection(textColor, subColor)),       // 8: tools
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------
  //  BACKGROUND (const widget — never rebuilds)
  // -----------------------------------------------
  Widget _buildAnimatedBackground() {
    return const _DashboardBackground();
  }

  // -----------------------------------------------
  //  HEADER WITH NOTIFICATION BELL
  // -----------------------------------------------
  Widget _buildHeader(Color textColor) {
    final firstName = _getUserFirstName();
    final greeting = firstName.isNotEmpty ? '${_getGreeting()}, $firstName 👋' : _getGreeting();
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: AppTextStyles.display.copyWith(
                  fontSize: firstName.isNotEmpty ? 22 : 26, 
                  fontWeight: FontWeight.w800, 
                  letterSpacing: -0.7,
                  color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            ],
          ),
        ),
        Row(
          children: [
            _ScaleTapWidget(
              onTap: () => _navigate(const SecurityLogsScreen()),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLight ? AppColors.primary.withOpacity(0.05) : Colors.white.withOpacity(0.04),
                  border: Border.all(color: isLight ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.08)),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications_none_rounded, color: textColor.withOpacity(0.8), size: 22),
                    Positioned(
                      top: -1, right: -1,
                      child: Container(
                        width: 9, height: 9,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)]),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: isLight ? Colors.white : const Color(0xFF070B10),
                child: Icon(Icons.person_rounded, color: isLight ? AppColors.primary : Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStorageCard(Color textColor, Color subColor) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: isLight ? Colors.white : Colors.white.withOpacity(0.03),
        border: Border.all(color: isLight ? AppColors.primary.withOpacity(0.08) : Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: isLight ? Colors.black.withOpacity(0.05) : Colors.black.withOpacity(0.2),
            blurRadius: 40,
            spreadRadius: isLight ? -5 : -10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 15,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'PREMIUM ELITE'.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 10, 
                          fontWeight: FontWeight.w900, 
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Storage Usage',
                  style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_storageUsed of 5 GB used',
                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 68, height: 68,
                child: CircularProgressIndicator(
                  value: _storagePercent, 
                  backgroundColor: Colors.white.withOpacity(0.05), 
                  color: const Color(0xFF00E5FF), 
                  strokeWidth: 6, 
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Glow effect
              Container(
                width: 74, height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.15), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.1),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              Text(
                '${(_storagePercent * 100).toInt()}%', 
                style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------
  //  STAT CARDS WITH COUNT-UP
  // -----------------------------------------------
  Widget _buildStatRow(Color textColor, Color subColor) {
    return Row(
      children: [
        _buildStatCard(Icons.image_rounded, _photoCount, 'Photos', AppColors.photos, textColor, subColor),
        const SizedBox(width: 8),
        _buildStatCard(Icons.videocam_rounded, _videoCount, 'Videos', AppColors.videos, textColor, subColor),
        const SizedBox(width: 8),
        _buildStatCard(Icons.description_rounded, _docCount, 'Docs', AppColors.documents, textColor, subColor),
        const SizedBox(width: 8),
        _buildStatCard(Icons.note_alt_rounded, _noteCount, 'Notes', const Color(0xFF8B5CF6), textColor, subColor),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, int count, String label, Color color, Color textColor, Color subColor) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: isLight ? Colors.white : Colors.white.withOpacity(0.03),
          border: Border.all(color: isLight ? AppColors.primary.withOpacity(0.05) : Colors.white.withOpacity(0.06)),
          boxShadow: isLight ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text('$count', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------
  //  QUICK ACTIONS
  // -----------------------------------------------
  Widget _buildQuickActions(Color textColor) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: isLight ? Colors.white : Colors.white.withOpacity(0.02),
        border: Border.all(color: isLight ? AppColors.primary.withOpacity(0.05) : Colors.white.withOpacity(0.06)),
        boxShadow: isLight ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Row(
        children: [
          _buildQuickAction(Icons.camera_alt_rounded, 'Camera', const Color(0xFFF59E0B), _takePhoto, textColor),
          _buildQuickDivider(),
          _buildQuickAction(Icons.photo_library_rounded, 'Upload', const Color(0xFF4DA3FF), _pickAndUploadImage, textColor),
          _buildQuickDivider(),
          _buildQuickAction(Icons.description_rounded, 'Docs', const Color(0xFF0EA5E9), () => _navigate(const VaultScreen()), textColor),
          _buildQuickDivider(),
          _buildQuickAction(Icons.shield_rounded, 'Secure', const Color(0xFF10B981), () {
            PremiumSnackbar.show(
              context,
              message: 'Advanced encryption active!',
              emoji: '???',
              color: const Color(0xFF10B981),
            );
          }, textColor),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap, Color textColor) {
    return Expanded(
      child: _ScaleTapWidget(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(0.12)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDivider() {
    return Container(width: 1, height: 40, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white.withOpacity(0.04));
  }

  // -----------------------------------------------
  //  SECURITY SCORE + ACTIVITY SPARKLINE ROW
  // -----------------------------------------------
  Widget _buildSecurityRow(Color textColor, Color subColor) {
    return Row(
      children: [
        // Security Score Gauge
        Expanded(child: _buildSecurityScoreCard(textColor, subColor)),
        const SizedBox(width: 10),
        // Activity Sparkline
        Expanded(child: _buildSparklineCard(textColor, subColor)),
      ],
    );
  }

  Widget _buildSecurityScoreCard(Color textColor, Color subColor) {
    final score = _getSecurityScore();
    final scoreColor = score >= 80 ? const Color(0xFF10B981) : score >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isLight ? Colors.white : Colors.white.withOpacity(0.02),
        border: Border.all(color: scoreColor.withOpacity(0.2)),
        boxShadow: isLight ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_rounded, color: scoreColor, size: 14),
              const SizedBox(width: 6),
              Text('Security Score', style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 76, height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 76, height: 76,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    backgroundColor: isLight ? AppColors.primary.withOpacity(0.05) : Colors.white.withOpacity(0.05),
                    color: scoreColor,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
                    Text('%', style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            score >= 80 ? 'EXCELLENT' : score >= 50 ? 'GOOD' : 'POOR',
            style: TextStyle(color: scoreColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildSparklineCard(Color textColor, Color subColor) {
    // Generate sample activity data based on actual file count
    final random = math.Random(42); // fixed seed for consistency
    final base = (_fileCount / 7).clamp(0, 20).toDouble();
    final data = List.generate(7, (i) => base + random.nextDouble() * 3);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isLight ? Colors.white : Colors.white.withOpacity(0.02),
        border: Border.all(color: const Color(0xFF4DA3FF).withOpacity(0.2)),
        boxShadow: isLight ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_graph_rounded, color: const Color(0xFF4DA3FF).withOpacity(0.8), size: 14),
              const SizedBox(width: 6),
              Text('Vault Heatmap', style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 76,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _SparklinePainter(data: data, progress: 1.0, isLight: isLight),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) =>
                Text(d, style: TextStyle(color: subColor.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.w800)),
            ).toList(),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------
  //  SECURITY TIP OF THE DAY
  // -----------------------------------------------
  Widget _buildSecurityTip({required Color color}) {
    final tipIndex = DateTime.now().day % _securityTips.length;
    final tip = _securityTips[tipIndex];
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: isLight ? color.withOpacity(0.06) : color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: isLight ? [BoxShadow(color: color.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4))] : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(tip['icon'] as IconData, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VAULT INTELLIGENCE', 
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Text(tip['tip'] as String, style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------
  //  RECENT ACTIVITY
  // -----------------------------------------------
  Widget _buildRecentHeader(Color textColor) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Activity', 
          style: AppTextStyles.subheading.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)
        ),
        _ScaleTapWidget(
          onTap: () => _navigate(const VaultScreen()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4DA3FF).withOpacity(0.1), 
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4DA3FF).withOpacity(0.15)),
            ),
            child: const Text('EXPLORE', style: TextStyle(color: Color(0xFF4DA3FF), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentContent(Color textColor, Color subColor) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    if (_isLoading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: isLight ? Colors.white : Colors.white.withOpacity(0.02), 
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isLight ? AppColors.primary.withOpacity(0.05) : Colors.white.withOpacity(0.05)),
          boxShadow: isLight ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF4DA3FF), strokeWidth: 2)),
      );
    }

    if (_recentItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: isLight ? Colors.white : Colors.white.withOpacity(0.02),
          border: Border.all(color: isLight ? AppColors.primary.withOpacity(0.05) : Colors.white.withOpacity(0.06)),
          boxShadow: isLight ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF4DA3FF).withOpacity(0.1), width: 1.5))),
                Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4DA3FF).withOpacity(0.05))),
                Icon(Icons.auto_awesome_rounded, color: const Color(0xFF4DA3FF).withOpacity(0.4), size: 28),
              ],
            ),
            const SizedBox(height: 20),
            Text('Secure your digital assets', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Files added here are encrypted instantly', style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            _ScaleTapWidget(
              onTap: () => _showUploadOptions(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF4DA3FF), Color(0xFF2B7FD4)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: const Color(0xFF4DA3FF).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 4))],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_moderator_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text('SECURE NOW', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(children: _recentItems.take(3).map((item) => _buildRecentTile(item, textColor, subColor)).toList());
  }

  bool _isImage(String name) {
    final ext = p.extension(name).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'].contains(ext);
  }

  bool _isVideo(String name) {
    final ext = p.extension(name).toLowerCase();
    return ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext);
    }

  Widget _buildRecentTile(dynamic item, Color textColor, Color subColor) {
    final name = item['originalName'] ?? 'Unnamed file';
    final size = item['sizeFormatted'] ?? '';
    final isImage = _isImage(name);
    final isVideo = _isVideo(name);
    final color = isImage ? const Color(0xFF4DA3FF) : isVideo ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
    final icon = isImage ? Icons.image_rounded : isVideo ? Icons.play_circle_rounded : Icons.insert_drive_file_rounded;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22), 
        color: isLight ? Colors.white : Colors.white.withOpacity(0.02), 
        border: Border.all(color: isLight ? AppColors.primary.withOpacity(0.05) : Colors.white.withOpacity(0.05)),
        boxShadow: isLight ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))] : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                if (size.isNotEmpty) ...[const SizedBox(height: 4), Text(size, style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w500))],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textColor.withOpacity(0.3), size: 22),
        ],
      ),
    );
  }

  // -----------------------------------------------
  //  TOOLS & SUPPORT
  // -----------------------------------------------
  Widget _buildToolsSection(Color textColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security Modules', 
          style: AppTextStyles.subheading.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)
        ),
        const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SectionCard(
                  icon: Icons.grid_view_rounded,
                  title: 'Calculator',
                  subtitle: 'Vault Entrance',
                  onTap: () => _navigate(const CalculatorScreen()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SectionCard(
                  icon: Icons.public_rounded,
                  title: 'Web Cloak',
                  subtitle: 'Private Browser',
                  onTap: () => _navigate(const PrivateBrowserScreen()),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SectionCard(
                icon: Icons.analytics_rounded,
                title: 'Analytics',
                subtitle: 'Activity Logs',
                onTap: () => _navigate(const AnalyticsScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SectionCard(
                icon: Icons.bolt_rounded,
                title: 'Optimizer',
                subtitle: 'Deep Cache Clean',
                onTap: () async {
                  try {
                    await DefaultCacheManager().emptyCache();
                    if (context.mounted) {
                      PremiumSnackbar.show(
                        context,
                        message: 'Memory Optimized Successfully!',
                        emoji: '??',
                        color: const Color(0xFF10B981),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SectionCard(
                icon: Icons.headset_mic_rounded,
                title: 'Help Center',
                subtitle: '24/7 Support',
                onTap: () => _navigate(const SupportScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SectionCard(
                icon: Icons.emergency_rounded,
                title: 'Panic Node',
                subtitle: 'Total Erase/Lock',
                onTap: () async {
                  HapticFeedback.heavyImpact();
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthWrapper()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------
  //  UPLOAD OPTIONS
  // -----------------------------------------------
  void _showUploadOptions(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isLight ? AppColors.surface : AppColors.darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: isLight ? Colors.black12 : Colors.white12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Add to Vault', style: AppTextStyles.subheading.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: isLight ? AppColors.textPrimary : Colors.white)),
            const SizedBox(height: 20),
            _uploadOption(ctx, Icons.image_rounded, 'Photos', AppColors.photos, _pickAndUploadImage, isLight),
            const SizedBox(height: 8),
            _uploadOption(ctx, Icons.videocam_rounded, 'Videos', AppColors.videos, _pickAndUploadVideo, isLight),
            const SizedBox(height: 8),
            _uploadOption(ctx, Icons.attach_file_rounded, 'Files', AppColors.documents, _pickAndUploadFile, isLight),
            const SizedBox(height: 8),
            _uploadOption(ctx, Icons.camera_alt_rounded, 'Camera', AppColors.warning, _takePhoto, isLight),
          ],
        ),
      ),
    );
  }

  Widget _uploadOption(BuildContext ctx, IconData icon, String title, Color color, VoidCallback onTap, bool isLight) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(ctx);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06), 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: color.withOpacity(0.12))
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(title, style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.35), size: 20),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------
  //  UPLOAD LOGIC
  // -----------------------------------------------
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image != null) await _uploadFile(image.path);
  }

  Future<void> _pickAndUploadVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) await _uploadFile(video.path);
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) await _uploadFile(result.files.single.path!);
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (photo != null) await _uploadFile(photo.path);
  }

  Future<void> _uploadFile(String path) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('?? Encrypting and uploading...'), duration: Duration(seconds: 30)));
    
    try {
      final fileName = p.basename(path);
      final extension = p.extension(path).toLowerCase();
      String type = 'document';
      if ({'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif'}.contains(extension)) {
        type = 'photo';
      } else if ({'.mp4', '.mov', '.avi', '.mkv', '.webm', '.3gp', '.flv', '.wmv'}.contains(extension)) {
        type = 'video';
      } else if ({'.mp3', '.wav', '.m4a', '.aac', '.flac', '.ogg', '.wma'}.contains(extension)) {
        type = 'audio';
      }

      final downloadUrl = await VaultEncryptionHelper.encryptAndUpload(
        path, 
        type, 
        customFileName: fileName,
      );
      
      // Note: Backend /vault/upload already handles Firestore registration in 'vaultItems' collection
      // and audit logging, so we don't need to do it here again.
      
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('✅ Vault updated successfully'), backgroundColor: Colors.green));
      _fetchDashboardData();
      
      // ✅ Prompt to delete original from device
      await _promptDeleteFromDevice(path);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}'), 
        backgroundColor: Colors.redAccent
      ));
    }
  }

  Future<void> _promptDeleteFromDevice(String filePath) async {
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isLight = Theme.of(ctx).brightness == Brightness.light;
        return AlertDialog(
          backgroundColor: isLight ? Colors.white : AppColors.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Delete Original?', 
            style: AppTextStyles.heading.copyWith(color: isLight ? AppColors.textPrimary : Colors.white)
          ),
          content: Text(
            'This file is now safely encrypted in your vault. Do you want to delete the original from your device storage?',
            style: AppTextStyles.body.copyWith(color: isLight ? AppColors.textSecondary : Colors.white70)
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep', style: TextStyle(color: isLight ? AppColors.textTertiary : Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Original file deleted'), backgroundColor: Colors.orangeAccent)
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to delete original: $e');
      }
    }
  }
}

// -----------------------------------------------
//  DOT GRID BACKGROUND LAYER + PAINTER
//  (see _DotGridLayer class below)
// -----------------------------------------------

// -----------------------------------------------
//  CONST BACKGROUND WIDGET (never rebuilt)
// -----------------------------------------------
class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? [const Color(0xFFF0F7FF), const Color(0xFFFDFDFF), const Color(0xFFF5F9FF)]
              : [const Color(0xFF000000), const Color(0xFF050505), const Color(0xFF000000)],
        ),
      ),
    );
  }
}

// -----------------------------------------------
//  DOT GRID BACKGROUND LAYER + PAINTER
// -----------------------------------------------
class _DotGridLayer extends StatelessWidget {
  const _DotGridLayer();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    // No Opacity widget — opacity baked into painter color to eliminate compositing layer
    return RepaintBoundary(
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _DotGridPainter(isLight: isLight),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final bool isLight;
  const _DotGridPainter({required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 28.0;
    // Opacity baked directly into color — no Opacity widget overhead
    final paint = Paint()
      ..color = isLight
          ? const Color(0x0D000000) // black at 5% opacity
          : const Color(0x06FFFFFF) // white at ~2.5% opacity
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;

    final points = <Offset>[];
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------
//  ACTIVITY SPARKLINE PAINTER
// -----------------------------------------------
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final double progress;
  final bool isLight;

  _SparklinePainter({required this.data, required this.progress, required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.reduce(math.max).clamp(1.0, double.infinity);
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - (data[i] / maxVal) * size.height * 0.8 * progress;
      points.add(Offset(x, y));
    }

    // Gradient fill under the line
    final fillPath = Path()..moveTo(0, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.2)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path();
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        linePath.moveTo(points[i].dx, points[i].dy);
      } else {
        // Smooth curve using quadratic bezier
        final prev = points[i - 1];
        final curr = points[i];
        final midX = (prev.dx + curr.dx) / 2;
        linePath.quadraticBezierTo(prev.dx + (midX - prev.dx) * 0.5, prev.dy, midX, (prev.dy + curr.dy) / 2);
        linePath.quadraticBezierTo(midX + (curr.dx - midX) * 0.5, curr.dy, curr.dx, curr.dy);
      }
    }
    canvas.drawPath(linePath, linePaint);

    // Dots
    final dotPaint = Paint()..color = AppColors.primary;
    final dotBgPaint = Paint()..color = isLight ? Colors.white : const Color(0xFF0D1520);
    for (final p in points) {
      canvas.drawCircle(p, 3.5, dotBgPaint);
      canvas.drawCircle(p, 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.data != data;
  }
}

// -----------------------------------------------
//  SCALE TAP WITH HAPTIC FEEDBACK
// -----------------------------------------------
class _ScaleTapWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ScaleTapWidget({required this.child, required this.onTap});

  @override
  State<_ScaleTapWidget> createState() => _ScaleTapWidgetState();
}

class _ScaleTapWidgetState extends State<_ScaleTapWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 120), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact(); // Confirm haptic on click
        widget.onTap();
      },
      child: widget.child,
    );
  }
}
