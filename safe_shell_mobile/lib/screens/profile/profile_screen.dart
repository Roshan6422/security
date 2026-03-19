import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User, AuthProvider;
import '../../services/vault_stats_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;


  // Staggered entrance


  int _totalFiles = 0;
  int _totalPhotos = 0;
  int _totalVideos = 0;
  int _totalDocs = 0;
  String _storageUsed = '0 B';
  int _daysActive = 30; // Hardcoded for now

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFromProvider();
      _fetchAnalytics(init: true);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }


  bool _isInitialized = false;

  void _initFromProvider() {
    if (_isInitialized) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _isInitialized = true;
    }
  }

  Future<void> _refreshData() async {
    // Only fetch analytics, AuthProvider handles profile data sync on its own
    await _fetchAnalytics();
  }


  Future<void> _fetchAnalytics({bool init = false}) async {
    try {
      // Use the onRefresh callback for instant paint + background update
      final stats = await VaultStatsService().getAggregatedStats(
        onRefresh: (freshStats) {
          if (mounted) {
            setState(() {
              _updateStatsFromModel(freshStats);
            });
          }
        },
      );
      
      if (mounted) {
        setState(() {
          _updateStatsFromModel(stats);
        });
      }
    } catch (_) {}
  }

  void _updateStatsFromModel(VaultStats stats) {
    _totalFiles = stats.totalCount;
    _totalPhotos = stats.photoCount;
    _totalVideos = stats.videoCount;
    _totalDocs = stats.docCount;
    _storageUsed = stats.sizeFormatted;
    _daysActive = 30; // Still hardcoded as per original
  }

  Future<void> _updateProfile() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'name': _nameController.text,
          'email': _emailController.text,
        });

        // Update local provider state too
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).updateProfileData(
            name: _nameController.text,
            email: _emailController.text,
          );
        }
      }
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Profile updated'), backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      
      if (image == null) return;

      setState(() => _isLoading = true);
      
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('profile_photos').child('$uid.jpg');
      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'photoUrl': downloadUrl,
      });

      // Update AuthProvider
      if (mounted) {
        await Provider.of<AuthProvider>(context, listen: false).updateProfileData(photoUrl: downloadUrl);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Photo updated!'), backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    HapticFeedback.heavyImpact();
    // AuthProvider.logout() handles: clear token, Firebase signOut, Google signOut
    if (mounted) {
      await Provider.of<AuthProvider>(context, listen: false).logout();
      // Navigation is handled reactively by AuthWrapper — no manual push needed
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
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Permanently destroy account data from auth and database
          await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
          // We would also need to securely delete the vault bucket files here in future
          await user.delete();
        }
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
      SnackBar(content: Text('✅ $label copied!'), duration: const Duration(seconds: 1), backgroundColor: const Color(0xFF4DA3FF)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _initFromProvider(); // Catch data arriving after initState
    final isLight = Theme.of(context).brightness == Brightness.light;
    final user = context.watch<AuthProvider>().user;
    
    return Scaffold(
      backgroundColor: isLight ? AppColors.background : AppColors.darkBackground,
      body: SafeArea(
        child: user == null
            ? _buildSkeletonLoading()
            : RefreshIndicator(
                onRefresh: _refreshData,
                color: AppColors.primary,
                child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  children: [
                    _buildProfileHeader(user),
                    const SizedBox(height: 20),
                    _buildPremiumUpgradeCard(user),
                    const SizedBox(height: 16),
                    _buildAnalyticsGrid(),
                    const SizedBox(height: 16),
                    _buildStorageChart(),
                    const SizedBox(height: 16),
                    _buildRecoveryKey(user),
                    const SizedBox(height: 16),
                    _buildEditForm(),
                    const SizedBox(height: 24),
                    _buildActions(),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  // -----------------------------------------------
  //  SKELETON LOADING
  // -----------------------------------------------
  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
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
      ),
    );
  }

  Widget _shimmerBox(double height, double width, {bool isCircle = false}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: isCircle ? null : BorderRadius.circular(16),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }

  // -----------------------------------------------
  //  PROFILE HEADER
  // -----------------------------------------------
  Widget _buildProfileHeader(User user) {
    final name = user.name;
    final email = user.email;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final isLight = Theme.of(context).brightness == Brightness.light;
    final secondaryColor = isLight ? AppColors.textSecondary : Colors.white.withOpacity(0.3);

    return Column(
      children: [
        // Gradient avatar ring with edit capability
        GestureDetector(
          onTap: _pickAndUploadPhoto,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6), Color(0xFF10B981)],
                  ),
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: isLight ? Colors.white : AppColors.darkSurface,
                  backgroundImage: user.photoUrl != null 
                    ? NetworkImage(user.photoUrl!) 
                    : null,
                  child: user.photoUrl == null 
                    ? Text(initial, style: TextStyle(color: isLight ? AppColors.primary : Colors.white, fontSize: 36, fontWeight: FontWeight.w800))
                    : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: isLight ? Colors.white : AppColors.darkBackground, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                ),
              ),
            ],
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
            _buildBadge('?? AES-256', const Color(0xFF4DA3FF)),
            const SizedBox(width: 8),
            _buildBadge('$_daysActive days', const Color(0xFF10B981)),
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
  //  PREMIUM UPGRADE CARD
  // -----------------------------------------------
  Widget _buildPremiumUpgradeCard(User user) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isPremium = user.subscriptionStatus == 'pro';
    
    if (isPremium) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4DA3FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative background patterns
            Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.star_rounded, size: 120, color: Colors.white.withOpacity(0.1)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'GO PRO',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SafeShell Premium',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Unlock Cloud Backup, Unlimited Video Storage & Advanced Stealth.',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _showSubscriptionDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SubscriptionSheet(),
    );
  }

  // -----------------------------------------------
  //  ANALYTICS GRID
  // -----------------------------------------------
  Widget _buildAnalyticsGrid() {
    return Row(
      children: [
        _buildAnalyticCard('??', _totalPhotos, 'Photos', const Color(0xFF4DA3FF)),
        const SizedBox(width: 10),
        _buildAnalyticCard('??', _totalVideos, 'Videos', const Color(0xFF8B5CF6)),
        const SizedBox(width: 10),
        _buildAnalyticCard('??', _totalDocs, 'Docs', const Color(0xFF10B981)),
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
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: isLight ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text('$count', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
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
              Text(_storageUsed, style: TextStyle(color: const Color(0xFF4DA3FF).withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(flex: (photoPercent * 100).toInt().clamp(1, 100), child: Container(color: const Color(0xFF4DA3FF))),
                Expanded(flex: (videoPercent * 100).toInt().clamp(1, 100), child: Container(color: const Color(0xFF8B5CF6))),
                Expanded(flex: (docPercent * 100).toInt().clamp(1, 100), child: Container(color: const Color(0xFF10B981))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legendDot('Photos', const Color(0xFF4DA3FF)),
              const SizedBox(width: 16),
              _legendDot('Videos', const Color(0xFF8B5CF6)),
              const SizedBox(width: 16),
              _legendDot('Docs', const Color(0xFF10B981)),
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
  Widget _buildRecoveryKey(User user) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [const Color(0xFF4DA3FF).withOpacity(0.08), const Color(0xFF4DA3FF).withOpacity(0.02)]),
        border: Border.all(color: const Color(0xFF4DA3FF).withOpacity(0.1)),
      ),
      child: GestureDetector(
        onTap: () => _copyToClipboard('Recovery Key', user.recoveryKey ?? 'N/A'),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF4DA3FF).withOpacity(0.2), const Color(0xFF4DA3FF).withOpacity(0.06)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.vpn_key_rounded, color: Color(0xFF4DA3FF), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recovery Key', style: TextStyle(color: isLight ? AppColors.primary.withOpacity(0.7) : Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600)),
                   const SizedBox(height: 2),
                  Text(user.recoveryKey ?? 'N/A', style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, color: const Color(0xFF4DA3FF).withOpacity(0.4), size: 18),
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

class _SubscriptionSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: isLight ? Colors.black12 : Colors.white12, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text('Choose Your Protection', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('Join 50,000+ users protecting their privacy.', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
          const SizedBox(height: 32),
          _SubscriptionPlan(
            title: 'Monthly Pass',
            price: '\$4.99 / mo',
            description: 'Full access to all features.',
            icon: Icons.flash_on_rounded,
            color: const Color(0xFF4DA3FF),
          ),
          const SizedBox(height: 12),
          _SubscriptionPlan(
            title: 'Yearly Shield',
            price: '\$39.99 / yr',
            description: 'Save 33% • Best Value Plan',
            icon: Icons.shield_rounded,
            color: const Color(0xFF8B5CF6),
            isPopular: true,
          ),
          const SizedBox(height: 12),
          _SubscriptionPlan(
            title: 'Lifetime Guard',
            price: '\$99.99',
            description: 'One-time payment • Pay once, own forever.',
            icon: Icons.all_inclusive_rounded,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            text: 'Continue with Google Pay',
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('?? Contacting payment gateway...'), backgroundColor: Color(0xFF4DA3FF)),
              );
            },
          ),
          const SizedBox(height: 12),
          Text('No commitment. Cancel anytime.', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }
}

class _SubscriptionPlan extends StatelessWidget {
  final String title;
  final String price;
  final String description;
  final IconData icon;
  final Color color;
  final bool isPopular;

  const _SubscriptionPlan({
    required this.title,
    required this.price,
    required this.description,
    required this.icon,
    required this.color,
    this.isPopular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: isPopular ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    if (isPopular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                        child: const Text('BEST VALUE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                Text(description, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
              ],
            ),
          ),
          Text(price, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
