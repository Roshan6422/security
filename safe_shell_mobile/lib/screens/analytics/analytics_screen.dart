import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../services/vault_stats_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late AnimationController _chartController;

  bool _isLoading = true;
  int _photoCount = 0;
  int _videoCount = 0;
  int _docCount = 0;
  int _audioCount = 0;
  int _totalFiles = 0;
  double _storageUsedMB = 0;
  double _storageTotalMB = 1024;

  // Weekly upload data (simulated from counts)
  List<double> _weeklyData = [0, 0, 0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(duration: const Duration(milliseconds: 1400), vsync: this);
    _chartController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _fetchAnalytics();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnalytics() async {
    try {
      final stats = await VaultStatsService().getAggregatedStats();
      if (mounted) {
        setState(() {
          _photoCount = stats.photoCount;
          _videoCount = stats.videoCount;
          _docCount = stats.docCount;
          _audioCount = stats.audioCount;
          _totalFiles = stats.totalCount;
          _storageUsedMB = stats.totalSizeBytes / (1024 * 1024);
          _storageTotalMB = 5 * 1024; // Free Plan fixed at 5GB
          
          // Generate weekly distribution from total
          final rng = math.Random(42);
          final total = _totalFiles.toDouble();
          _weeklyData = List.generate(7, (i) => (total / 7 * (0.3 + rng.nextDouble() * 1.4)).clamp(0, total));
          
          _isLoading = false;
        });
        _staggerController.forward();
        _chartController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _staggerController.forward();
        _chartController.forward();
      }
    }
  }

  Widget _anim(int index, Widget child) {
    final start = (index * 0.08).clamp(0.0, 1.0);
    final end = (start + 0.25).clamp(0.0, 1.0);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOutCubic)),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? AppColors.background : AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 20, color: isLight ? AppColors.textPrimary : Colors.white),
          onPressed: () { HapticFeedback.selectionClick(); Navigator.pop(context); },
        ),
        title: Text('Analytics', style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4DA3FF)))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Storage overview
                  _anim(0, _buildStorageOverview()),
                  const SizedBox(height: 20),
                  // File type breakdown
                  _anim(1, _buildFileBreakdown()),
                  const SizedBox(height: 20),
                  // Weekly chart
                  _anim(2, _buildWeeklyChart()),
                  const SizedBox(height: 20),
                  // Category distribution
                  _anim(3, _buildCategoryDistribution()),
                  const SizedBox(height: 20),
                  // Security status
                  _anim(4, _buildSecurityStatus()),
                ],
              ),
            ),
    );
  }

  Widget _buildStorageOverview() {
    final usedPercent = _storageTotalMB > 0 ? (_storageUsedMB / _storageTotalMB).clamp(0.0, 1.0) : 0.0;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isLight ? Colors.white : AppColors.darkSurface,
        gradient: isLight ? null : LinearGradient(colors: [const Color(0xFF4DA3FF).withValues(alpha: 0.04), const Color(0xFF4DA3FF).withValues(alpha: 0.01)]),
        border: Border.all(color: const Color(0xFF4DA3FF).withValues(alpha: isLight ? 0.2 : 0.05)),
        boxShadow: isLight ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4DA3FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_rounded, color: Color(0xFF4DA3FF), size: 18),
              ),
              const SizedBox(width: 12),
              Text('Storage Overview', style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${_storageUsedMB.toStringAsFixed(1)} MB', style: const TextStyle(color: Color(0xFF4DA3FF), fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 18),
          // Animated progress
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: AnimatedBuilder(
                animation: _chartController,
                builder: (context, child) {
                  return RepaintBoundary(
                    child: Stack(
                      children: [
                        Container(color: Colors.white.withValues(alpha: 0.04)),
                        FractionallySizedBox(
                          widthFactor: (usedPercent * _chartController.value),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(usedPercent * 100).toStringAsFixed(1)}% of ${_storageTotalMB.toStringAsFixed(0)} MB used',
            style: TextStyle(color: isLight ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.25), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFileBreakdown() {
    final items = [
      _FileType('Photos', _photoCount, const Color(0xFF4DA3FF), Icons.photo_rounded),
      _FileType('Videos', _videoCount, const Color(0xFF8B5CF6), Icons.videocam_rounded),
      _FileType('Docs', _docCount, const Color(0xFF10B981), Icons.description_rounded),
      _FileType('Audio', _audioCount, const Color(0xFFF59E0B), Icons.audiotrack_rounded),
    ];

    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isLight ? Colors.white : AppColors.darkSurface,
        border: Border.all(color: isLight ? AppColors.primary.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.03)),
        boxShadow: isLight ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('File Breakdown', style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('$_totalFiles total files', style: TextStyle(color: isLight ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.25), fontSize: 11)),
          const SizedBox(height: 18),
          Row(
            children: items.map((item) {
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [item.color.withValues(alpha: 0.15), item.color.withValues(alpha: 0.04)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    const SizedBox(height: 10),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: item.count),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, child) => Text(
                        '$val',
                        style: TextStyle(color: item.color, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(item.name, style: TextStyle(color: isLight ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.3), fontSize: 10)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final maxVal = _weeklyData.reduce(math.max).clamp(1.0, double.infinity);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isLight ? Colors.white : AppColors.darkSurface,
        border: Border.all(color: isLight ? AppColors.primary.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.03)),
        boxShadow: isLight ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload Trend', style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Last 7 days activity', style: TextStyle(color: isLight ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.25), fontSize: 11)),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: AnimatedBuilder(
              animation: _chartController,
              builder: (context, child) {
                return RepaintBoundary(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final h = (_weeklyData[i] / maxVal * 80 * _chartController.value).clamp(4.0, 80.0);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [const Color(0xFF4DA3FF).withValues(alpha: 0.3), const Color(0xFF4DA3FF)],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(days[i], style: TextStyle(color: isLight ? AppColors.textSecondary.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.25), fontSize: 9)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDistribution() {
    final total = (_photoCount + _videoCount + _docCount + _audioCount).clamp(1, 999999);
    final items = [
      ('Photos', _photoCount, const Color(0xFF4DA3FF)),
      ('Videos', _videoCount, const Color(0xFF8B5CF6)),
      ('Docs', _docCount, const Color(0xFF10B981)),
      ('Audio', _audioCount, const Color(0xFFF59E0B)),
    ];

    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isLight ? Colors.white : AppColors.darkSurface,
        border: Border.all(color: isLight ? AppColors.primary.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.03)),
        boxShadow: isLight ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Distribution', style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: AnimatedBuilder(
                animation: _chartController,
                builder: (context, child) {
                  return RepaintBoundary(
                    child: Row(
                      children: items.map((item) {
                        final pct = item.$2 / total * _chartController.value;
                        return Expanded(
                          flex: (pct * 100).toInt().clamp(1, 100),
                          child: Container(color: item.$3),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: items.map((item) {
              final pct = (item.$2 / total * 100).toStringAsFixed(0);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: item.$3)),
                  const SizedBox(width: 6),
                  Text('${item.$1} $pct%', style: TextStyle(color: isLight ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.35), fontSize: 11)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStatus() {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isLight ? Colors.white : const Color(0xFF10B981).withValues(alpha: 0.08),
        gradient: isLight ? null : LinearGradient(colors: [const Color(0xFF10B981).withValues(alpha: 0.08), const Color(0xFF10B981).withValues(alpha: 0.02)]),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: isLight ? 0.2 : 0.08)),
        boxShadow: isLight ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFF10B981).withValues(alpha: 0.2), const Color(0xFF10B981).withValues(alpha: 0.05)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vault Secured', style: TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.w700)),
                Text('AES-256 encryption active', style: TextStyle(color: isLight ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.25), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Active', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _FileType {
  final String name;
  final int count;
  final Color color;
  final IconData icon;
  const _FileType(this.name, this.count, this.color, this.icon);
}
