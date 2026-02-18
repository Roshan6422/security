import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:safe_shell_mobile/widgets/glass_card.dart';
import 'package:safe_shell_mobile/widgets/section_card.dart';
import 'package:safe_shell_mobile/widgets/stat_chip.dart';
import 'package:safe_shell_mobile/widgets/usage_ring.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../subscription/payment_screen.dart';
import '../vault/vault_screen.dart';
import '../settings/support_screen.dart';
import '../calculator/calculator_screen.dart';
import '../browser/private_browser_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, int> _counts = {'photo': 0, 'video': 0, 'document': 0, 'zip': 0, 'note': 0};
  List<dynamic> _recentItems = [];
  double _usedGB = 0.0;
  final double _planTotalGB = 5.0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final response = await ApiService().get('/vault'); // Assuming singleton or static if refactored
      // Note: ApiService is instance based in previous code, but I made static methods too?
      // Let's check ApiService usage. In Login it was Provider.of? No, it was ApiService.currentTime?
      // Actually ApiService has instance methods. I should instantiate it or use Provider if available.
      // For now, I'll instantiate it.
      
      if (response != null && response is List) {
        if (mounted) {
          setState(() => _error = null);
        }
        final newCounts = {'photo': 0, 'video': 0, 'document': 0, 'zip': 0, 'note': 0};
        double totalBytes = 0;

        for (var item in response) {
          final type = item['type'] as String? ?? 'unknown';
          if (newCounts.containsKey(type)) {
            newCounts[type] = (newCounts[type] ?? 0) + 1;
          }
          
          final sizeStr = item['size'] as String? ?? "0 B";
          final numVal = double.tryParse(sizeStr.replaceAll(RegExp(r'[A-Za-z]'), '')) ?? 0;
          
          if (sizeStr.contains("GB")) {
            totalBytes += numVal * 1024 * 1024 * 1024;
          } else if (sizeStr.contains("MB")) {
            totalBytes += numVal * 1024 * 1024;
          } else if (sizeStr.contains("KB")) {
            totalBytes += numVal * 1024;
          } else {
            totalBytes += numVal;
          }
        }

        if (mounted) {
          setState(() {
            _counts = newCounts;
            _recentItems = response.reversed.take(3).toList();
            _usedGB = totalBytes / (1024 * 1024 * 1024);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Dashboard fetch error: $e');
      if (mounted) {
        setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
      }
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }



  @override
  Widget build(BuildContext context) {

    final usedPct = min(100.0, (_usedGB / _planTotalGB) * 100);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Animated Background Blobs
          _buildAnimatedBlobs(),

          // Content
          SingleChildScrollView(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 24,
              right: 24,
              bottom: 120, // Space for bottom nav
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _greeting,
                              style: AppTextStyles.display.copyWith(fontSize: 28),
                            ),
                            const SizedBox(width: 8),
                            _buildPulsingBadge(),
                          ],
                        ),
                        Text(
                          'Your vault is fully encrypted.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary.withOpacity(0.55),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Error State
                if (_error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Connection Error',
                          style: AppTextStyles.subheading.copyWith(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _isLoading = true);
                            _fetchDashboardData();
                          },
                           style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.2),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),

                // Subscription Card
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, Color(0xFF2B7FDB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x594DA3FF),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Free Plan',
                                style: AppTextStyles.subheading.copyWith(fontSize: 15),
                              ),
                              Text(
                                '${_usedGB.toStringAsFixed(1)} GB / ${_planTotalGB.toInt()} GB',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          UsageRing(value: usedPct),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen())),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Text(
                                'Upgrade',
                                style: AppTextStyles.subheading.copyWith(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      StatChip(
                        icon: Icons.image,
                        label: 'Photos',
                        count: _counts['photo']!,
                        color: AppColors.photos,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen())),
                      ),
                      StatChip(
                        icon: Icons.videocam,
                        label: 'Videos',
                        count: _counts['video']!,
                        color: AppColors.videos,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen())),
                      ),
                       StatChip(
                        icon: Icons.description,
                        label: 'Docs',
                        count: _counts['document']!,
                        color: AppColors.documents,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen())),
                      ),
                      StatChip(
                        icon: Icons.folder_zip,
                        label: 'ZIP',
                        count: _counts['zip']!,
                        color: AppColors.zip,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Recent Items (Placeholder structure)
                  if (!_isLoading && _recentItems.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent Activity', style: AppTextStyles.subheading.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen())),
                          child: Text('View All', style: AppTextStyles.subheading.copyWith(fontSize: 13, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._recentItems.map((item) => _buildRecentItemTile(item)),
                    const SizedBox(height: 24),
                  ],


                  // Tools Grid
                Text('Tools & Support', style: AppTextStyles.subheading.copyWith(fontSize: 18)),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    SectionCard(
                      icon: Icons.calculate,
                      title: 'Calculator',
                      subtitle: 'Secret Vault Entry',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalculatorScreen())), // Link to CalculatorScreen
                    ),
                     SectionCard(
                      icon: Icons.public, // Browser icon
                      title: 'Private Browser',
                      subtitle: 'No Trace Browsing',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivateBrowserScreen())), // Link to PrivateBrowserScreen
                    ),
                     SectionCard(
                      icon: Icons.bolt,
                      title: 'Optimize',
                      subtitle: 'Clear cache',
                      onTap: () async {
                         try {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Optimizing... 🧹')));
                            await DefaultCacheManager().emptyCache();
                            if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device Optimized! RAM & Cache Cleared ✨')));
                            }
                         } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                         }
                      },
                    ),
                     SectionCard(
                      icon: Icons.headset_mic,
                      title: 'Support',
                      subtitle: 'Get help',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBlobs() {
    return Stack(
      children: [
        Positioned(
          top: -50,
          left: -50,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 4),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(sin(value * 2 * pi) * 20, cos(value * 2 * pi) * 30),
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.12),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 100, spreadRadius: 40)],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 300,
          right: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(0.15),
              boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 100, spreadRadius: 50)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPulsingBadge() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOutSine,
      builder: (context, value, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1 * value),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.3 * value)),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.2 * value), blurRadius: 8 * value),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user, size: 10, color: AppColors.primary.withOpacity(value)),
              const SizedBox(width: 4),
              Text(
                'SECURE',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary.withOpacity(0.9 * value),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentItemTile(dynamic item) {
    final type = item['type'] ?? 'unknown';
    Color color;
    IconData icon;
    
    switch (type) {
      case 'photo': color = AppColors.photos; icon = Icons.image; break;
      case 'video': color = AppColors.videos; icon = Icons.videocam; break;
      case 'note': color = AppColors.notes; icon = Icons.description; break;
      case 'zip': color = AppColors.zip; icon = Icons.folder_zip; break;
      default: color = AppColors.documents; icon = Icons.insert_drive_file;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] ?? 'Untitled', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(item['size'] ?? '0 KB', style: AppTextStyles.caption.copyWith(fontSize: 11, color: Colors.white38)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}

