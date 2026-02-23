import 'dart:io';
import 'dart:math' as math;
import '../../widgets/confetti_overlay.dart';
import '../../widgets/premium_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/api_service.dart';
import 'photos_list_screen.dart';
import 'videos_list_screen.dart';
import 'audio_list_screen.dart';
import 'notes_list_screen.dart';
import 'documents_list_screen.dart';
import 'recycle_bin_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'local_cloak_screen.dart';
import 'package:provider/provider.dart';
import '../../utils/sound_effects.dart';
import '../../providers/settings_provider.dart';
import '../../main.dart';
import 'cloak_list_screen.dart';
import 'app_hider_screen.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with RouteAware, TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  
  // Staggered entrance animation
  late AnimationController _staggerController;

  final List<_VaultCategory> _categories = [
    _VaultCategory(Icons.image_rounded, 'Photos', 'photo', AppColors.photos),
    _VaultCategory(Icons.videocam_rounded, 'Videos', 'video', AppColors.videos),
    _VaultCategory(Icons.visibility_off_rounded, 'Invisible Files', 'local_cloak', const Color(0xFFF59E0B)),
    _VaultCategory(Icons.audiotrack_rounded, 'Audio', 'audio', const Color(0xFF6366F1)),
    _VaultCategory(Icons.sticky_note_2_rounded, 'Notes', 'note', AppColors.notes),
    _VaultCategory(Icons.description_rounded, 'Documents', 'document', AppColors.documents),
    _VaultCategory(Icons.lock_person_rounded, 'App Lock', 'app_hider', const Color(0xFF818CF8)),
  ];


  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light ? AppColors.background : AppColors.darkBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
              const SizedBox(height: 16),
              Text('Unlocking vault...', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? AppColors.textSecondary : AppColors.darkTextSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? AppColors.textPrimary : Colors.white;
    final subColor = isLight ? AppColors.textSecondary : AppColors.darkTextSecondary;

    return Scaffold(
      backgroundColor: isLight ? AppColors.background : AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('SAFE VAULT', style: AppTextStyles.heading.copyWith(letterSpacing: 2, fontSize: 16, color: isLight ? AppColors.textPrimary : AppColors.primary)),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Vault', style: AppTextStyles.heading.copyWith(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: textColor)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34D399))),
                          const SizedBox(width: 6),
                          Text('?? Encrypted & Cloaked', style: AppTextStyles.caption.copyWith(color: subColor, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  _ScaleTapVault(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RecycleBinScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLight ? AppColors.primary.withOpacity(0.08) : Colors.white.withOpacity(0.05),
                        border: Border.all(color: isLight ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.06)),
                      ),
                      child: Icon(Icons.delete_outline_rounded, color: isLight ? AppColors.primary.withOpacity(0.7) : Colors.white.withOpacity(0.4), size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Staggered Category Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) {
                    final delay = (i * 0.08).clamp(0.0, 1.0);
                    final end = (delay + 0.25).clamp(0.0, 1.0);
                    final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(parent: _staggerController, curve: Interval(delay, end, curve: Curves.easeOutCubic)),
                    );
                    final slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
                      CurvedAnimation(parent: _staggerController, curve: Interval(delay, end, curve: Curves.easeOutCubic)),
                    );
                    return FadeTransition(
                      opacity: fadeAnim,
                      child: SlideTransition(
                        position: slideAnim,
                        child: _buildCategoryCard(_categories[i]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFF7C3AED)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: const Color(0xFFA855F7).withOpacity(isLight ? 0.3 : 0.4), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: FloatingActionButton(
          onPressed: () { HapticFeedback.mediumImpact(); _showUploadOptions(context); },
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

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
            Text('Import to Vault', style: AppTextStyles.subheading.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: isLight ? AppColors.textPrimary : Colors.white)),
            const SizedBox(height: 6),
            Text('Files are uploaded & originals auto-deleted', style: TextStyle(color: isLight ? AppColors.textSecondary : Colors.white.withOpacity(0.3), fontSize: 12)),
            const SizedBox(height: 20),
            _uploadOption(ctx, Icons.image_rounded, 'Import Photo', 'From gallery', const Color(0xFFA855F7), () { Navigator.pop(ctx); _pickAndUploadImage(); }, isLight),
            const SizedBox(height: 8),
            _uploadOption(ctx, Icons.videocam_rounded, 'Import Video', 'From gallery', const Color(0xFF8B5CF6), () { Navigator.pop(ctx); _pickAndUploadVideo(); }, isLight),
            const SizedBox(height: 8),
            _uploadOption(ctx, Icons.attach_file_rounded, 'Import File', 'Documents, ZIP, etc.', const Color(0xFF34D399), () { Navigator.pop(ctx); _pickAndUploadFile(); }, isLight),
            const SizedBox(height: 8),
            _uploadOption(ctx, Icons.camera_alt_rounded, 'Camera', 'Take photo directly', const Color(0xFFF59E0B), () { Navigator.pop(ctx); _takePhoto(); }, isLight),
            const SizedBox(height: 8),
            _uploadOption(ctx, Icons.videocam_outlined, 'Record Video', 'Record directly', const Color(0xFFE11D48), () { Navigator.pop(ctx); _takeVideo(); }, isLight),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 12),
          ],
        ),
      ),
    );
  }

  Widget _uploadOption(BuildContext ctx, IconData icon, String title, String subtitle, Color color, VoidCallback onTap, bool isLight) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(isLight ? 0.15 : 0.08)),
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
                  Text(title, style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle, style: TextStyle(color: isLight ? AppColors.textSecondary : Colors.white.withOpacity(0.3), fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (image != null) await _uploadAndDelete(image.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickAndUploadVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) await _uploadAndDelete(video.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) await _uploadAndDelete(result.files.single.path!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (photo != null) await _uploadAndDelete(photo.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _takeVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.camera);
      if (video != null) await _uploadAndDelete(video.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _uploadAndDelete(String filePath) async {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('?? Uploading to vault...'), duration: Duration(seconds: 60)),
    );

    try {
      await ApiService().uploadMultipart('/vault/upload', filePath);
      try {
        final originalFile = File(filePath);
        if (await originalFile.exists()) await originalFile.delete();
      } catch (_) {}

      if (mounted) {
        HapticFeedback.mediumImpact();
        await SoundEffects.uploadSuccess();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ConfettiOverlay.show(context);
        PremiumSnackbar.show(context, message: 'Uploaded & deleted from phone', emoji: '?', color: const Color(0xFF34D399));
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildCategoryCard(_VaultCategory category) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? AppColors.textPrimary : Colors.white;

    return GlassCard(
      onTap: () {
        Widget screen;
        switch (category.type) {
          case 'photo': screen = const PhotosListScreen(); break;
          case 'video': screen = const VideosListScreen(); break;
          case 'audio': screen = const AudioListScreen(); break;
          case 'note': screen = const NotesListScreen(); break;
          case 'document': screen = const DocumentsListScreen(); break;
          case 'app_hider': screen = const AppHiderScreen(); break;
          case 'local_cloak': screen = const LocalCloakScreen(); break;
          case 'cloud_cloak': screen = const CloakListScreen(); break;
          default: screen = const PhotosListScreen();
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [category.color.withOpacity(0.3), category.color.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: category.color.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: category.color.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(category.icon, color: category.color, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            category.label,
            style: AppTextStyles.subheading.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: textColor, letterSpacing: -0.2),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VaultCategory {
  final IconData icon;
  final String label;
  final String type;
  final Color color;

  _VaultCategory(this.icon, this.label, this.type, this.color);
}

class _ScaleTapVault extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ScaleTapVault({required this.child, required this.onTap});

  @override
  State<_ScaleTapVault> createState() => _ScaleTapVaultState();
}

class _ScaleTapVaultState extends State<_ScaleTapVault> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 120), vsync: this);
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _ctrl.forward(); HapticFeedback.selectionClick(); },
      onTapUp: (_) { _ctrl.reverse(); HapticFeedback.lightImpact(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
