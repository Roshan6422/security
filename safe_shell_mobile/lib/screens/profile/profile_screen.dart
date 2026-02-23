import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../services/vault_stats_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_text_field.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  Map<String, dynamic>? _userData;

  // Staggered entrance
  late AnimationController _staggerController;

  // Analytics data
  int _totalFiles = 0;
  int _totalPhotos = 0;
  int _totalVideos = 0;
  int _totalDocs = 0;
  String _storageUsed = '0 B';
  int _daysActive = 0;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(duration: const Duration(milliseconds: 1400), vsync: this)..forward();
    _fetchProfile();
    _fetchAnalytics();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _anim(int index, Widget child) {
    final start = (index * 0.08).clamp(0.0, 1.0);
    final end = (start + 0.25).clamp(0.0, 1.0);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOutCubic)),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    );
  }

  Future<void> _fetchProfile() async {
    try {
      final user = await ApiService().get('/auth/me');
      if (mounted) {
        setState(() {
          _userData = user;
          _nameController.text = user['name'] ?? '';
          _emailController.text = user['email'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _fetchAnalytics() async {
    try {
      final stats = await VaultStatsService().getAggregatedStats();
      if (mounted) {
        setState(() {
          _totalFiles = stats.totalCount;
          _totalPhotos = stats.photoCount;
          _totalVideos = stats.videoCount;
          _totalDocs = stats.docCount;
          _storageUsed = stats.sizeFormatted;
          // Estimate days active from registration (default 30 days)
          _daysActive = 30;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateProfile() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      await ApiService().put('/auth/profile', {
        'name': _nameController.text,
        'email': _emailController.text,
      });
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('? Profile updated'), backgroundColor: Color(0xFF34D399)));
        _fetchProfile();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    HapticFeedback.heavyImpact();
    await _storage.deleteAll();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _deleteAccount() async {
    HapticFeedback.heavyImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1A1F26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('?? Delete Account?', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? AppColors.textPrimary : Colors.white, fontWeight: FontWeight.w700)),
        content: Text('This action is irreversible. All vault data will be permanently destroyed.', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? AppColors.textSecondary : Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? AppColors.textSecondary : Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Forever', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().delete('/auth/delete-account');
        await _logout();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _copyToClipboard(String label, String value) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('?? $label copied!'), duration: const Duration(seconds: 1), backgroundColor: const Color(0xFFA855F7)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: isLight ? AppColors.background : AppColors.darkBackground,
      body: SafeArea(
        child: _userData == null
            ? _buildSkeletonLoading()
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  children: [
                    _anim(0, _buildProfileHeader()),
                    const SizedBox(height: 20),
                    _anim(1, _buildAnalyticsGrid()),
                    const SizedBox(height: 16),
                    _anim(2, _buildStorageChart()),
                    const SizedBox(height: 16),
                    _anim(3, _buildRecoveryKey()),
                    const SizedBox(height: 16),
                    _anim(4, _buildEditForm()),
                    const SizedBox(height: 24),
                    _anim(5, _buildActions()),
                  ],
                ),
              ),
      ),
    );
  }

  // -----------------------------------------------
  //  SKELETON LOADING
  // -----------------------------------------------
  Widget _buildSkeletonLoading() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Avatar skeleton
          _shimmerBox(80, 80, isCircle: true),
          const SizedBox(height: 16),
          _shimmerBox(24, 160),
          const SizedBox(height: 8),
          _shimmerBox(14, 120),
          const SizedBox(height: 30),
          // Analytics skeleton
          Row(children: [
            Expanded(child: _shimmerBox(80, double.infinity)),
            const SizedBox(width: 10),
            Expanded(child: _shimmerBox(80, double.infinity)),
            const SizedBox(width: 10),
            Expanded(child: _shimmerBox(80, double.infinity)),
          ]),
          const SizedBox(height: 16),
          _shimmerBox(120, double.infinity),
          const SizedBox(height: 16),
          _shimmerBox(80, double.infinity),
          const SizedBox(height: 16),
          _shimmerBox(200, double.infinity),
        ],
      ),
    );
  }

  Widget _shimmerBox(double height, double width, {bool isCircle = false}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.6),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(value * 0.04),
            borderRadius: isCircle ? null : BorderRadius.circular(16),
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          ),
        );
      },
    );
  }

  // -----------------------------------------------
  //  PROFILE HEADER
  // -----------------------------------------------
  Widget _buildProfileHeader() {
    final name = _userData?['name'] ?? 'User';
    final email = _userData?['email'] ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final isLight = Theme.of(context).brightness == Brightness.light;
    final secondaryColor = isLight ? AppColors.textSecondary : Colors.white.withOpacity(0.3);

    return Column(
      children: [
        // Gradient avatar ring
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFA855F7), Color(0xFF8B5CF6), Color(0xFF34D399)],
            ),
          ),
          child: CircleAvatar(
            radius: 45,
            backgroundColor: isLight ? Colors.white : AppColors.darkSurface,
            child: Text(initial, style: TextStyle(color: isLight ? AppColors.primary : Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 14),
        Text(name, style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(email, style: TextStyle(color: secondaryColor, fontSize: 13)),
        const SizedBox(height: 10),
        // Status badges
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadge('?? AES-256', const Color(0xFFA855F7)),
            const SizedBox(width: 8),
            _buildBadge('$_daysActive days', const Color(0xFF34D399)),
            const SizedBox(width: 8),
            _buildBadge('$_totalFiles files', const Color(0xFF8B5CF6)),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Text(text, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  // -----------------------------------------------
  //  ANALYTICS GRID
  // -----------------------------------------------
  Widget _buildAnalyticsGrid() {
    return Row(
      children: [
        _buildAnalyticCard('??', _totalPhotos, 'Photos', const Color(0xFFA855F7)),
        const SizedBox(width: 10),
        _buildAnalyticCard('??', _totalVideos, 'Videos', const Color(0xFF8B5CF6)),
        const SizedBox(width: 10),
        _buildAnalyticCard('??', _totalDocs, 'Docs', const Color(0xFF34D399)),
      ],
    );
  }

  Widget _buildAnalyticCard(String emoji, int count, String label, Color color) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isLight ? Colors.white : AppColors.darkSurface,
          border: Border.all(color: color.withOpacity(isLight ? 0.2 : 0.08)),
          boxShadow: isLight ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: count),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Text('$value', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900));
              },
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: isLight ? AppColors.textSecondary : Colors.white.withOpacity(0.3), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------
  //  STORAGE CHART
  // -----------------------------------------------
  Widget _buildStorageChart() {
    final total = _totalPhotos + _totalVideos + _totalDocs;
    final photoPercent = total > 0 ? _totalPhotos / total : 0.0;
    final videoPercent = total > 0 ? _totalVideos / total : 0.0;
    final docPercent = total > 0 ? _totalDocs / total : 0.0;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isLight ? Colors.white : AppColors.darkSurface,
        border: Border.all(color: isLight ? AppColors.primary.withOpacity(0.05) : Colors.white.withOpacity(0.04)),
        boxShadow: isLight ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Storage Breakdown', style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text(_storageUsed, style: TextStyle(color: const Color(0xFFA855F7).withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                builder: (context, animValue, child) {
                  return Row(
                    children: [
                      Expanded(flex: (photoPercent * 100 * animValue).toInt().clamp(1, 100), child: Container(color: const Color(0xFFA855F7))),
                      Expanded(flex: (videoPercent * 100 * animValue).toInt().clamp(1, 100), child: Container(color: const Color(0xFF8B5CF6))),
                      Expanded(flex: (docPercent * 100 * animValue).toInt().clamp(1, 100), child: Container(color: const Color(0xFF34D399))),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legendDot('Photos', const Color(0xFFA855F7)),
              const SizedBox(width: 16),
              _legendDot('Videos', const Color(0xFF8B5CF6)),
              const SizedBox(width: 16),
              _legendDot('Docs', const Color(0xFF34D399)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: isLight ? AppColors.textSecondary : Colors.white.withOpacity(0.3), fontSize: 11)),
      ],
    );
  }

  // -----------------------------------------------
  //  RECOVERY KEY
  // -----------------------------------------------
  Widget _buildRecoveryKey() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [const Color(0xFFA855F7).withOpacity(0.08), const Color(0xFFA855F7).withOpacity(0.02)]),
        border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.1)),
      ),
      child: GestureDetector(
        onTap: () => _copyToClipboard('Recovery Key', _userData?['recoveryKey'] ?? 'N/A'),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFFA855F7).withOpacity(0.2), const Color(0xFFA855F7).withOpacity(0.06)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.vpn_key_rounded, color: Color(0xFFA855F7), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recovery Key', style: TextStyle(color: isLight ? AppColors.primary.withOpacity(0.7) : Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(_userData?['recoveryKey'] ?? 'N/A', style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, color: const Color(0xFFA855F7).withOpacity(0.4), size: 18),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------
  //  EDIT FORM
  // -----------------------------------------------
  Widget _buildEditForm() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isLight ? Colors.white : AppColors.darkSurface,
        border: Border.all(color: isLight ? AppColors.primary.withOpacity(0.05) : Colors.white.withOpacity(0.04)),
        boxShadow: isLight ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Personal Info', style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          CustomTextField(label: 'Full Name', prefixIcon: Icons.person, controller: _nameController),
          const SizedBox(height: 14),
          CustomTextField(label: 'Email Address', prefixIcon: Icons.email, controller: _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 20),
          PrimaryButton(text: 'Save Changes', onPressed: _updateProfile, isLoading: _isLoading),
        ],
      ),
    );
  }

  // -----------------------------------------------
  //  ACTIONS
  // -----------------------------------------------
  Widget _buildActions() {
    return Column(
      children: [
        _actionTile(Icons.logout_rounded, 'Logout', 'Sign out of your account', const Color(0xFFF59E0B), _logout),
        const SizedBox(height: 10),
        _actionTile(Icons.delete_forever_rounded, 'Delete Account', 'Permanently destroy all data', const Color(0xFFEF4444), _deleteAccount),
      ],
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withOpacity(0.06),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.06)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? AppColors.textSecondary : Colors.white.withOpacity(0.2), fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}
