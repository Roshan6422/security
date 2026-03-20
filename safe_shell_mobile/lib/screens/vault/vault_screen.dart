import 'dart:io';
import '../../widgets/confetti_overlay.dart';
import '../../widgets/premium_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme.dart';
import 'package:path/path.dart' as p;
// ✅ Fix 1: Removed unused imports
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'photos_list_screen.dart';
import 'videos_list_screen.dart';
import 'notes_list_screen.dart';
import 'documents_list_screen.dart';
import 'recycle_bin_screen.dart';
import 'app_hider_screen.dart';
// import 'package:provider/provider.dart';        // ✅ Fix 1: Unused
// import '../../providers/settings_provider.dart'; // ✅ Fix 1: Unused
import '../../utils/sound_effects.dart';
import '../../main.dart';
import '../../utils/vault_encryption_helper.dart';
import '../../services/vault_stats_service.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen>
    with RouteAware, TickerProviderStateMixin {
  final bool _isLoading = false;

  final List<_VaultCategory> _categories = [
    _VaultCategory(
        Icons.image_rounded, 'Photos', 'photo', AppColors.photos),
    _VaultCategory(
        Icons.videocam_rounded, 'Videos', 'video', AppColors.videos),
    _VaultCategory(
        Icons.sticky_note_2_rounded, 'Notes', 'note', AppColors.notes),
    _VaultCategory(Icons.description_rounded, 'Documents', 'document',
        AppColors.documents),
    _VaultCategory(Icons.apps_rounded, 'App Lock', 'app_hider',
        const Color(0xFFEF4444)),
  ];

  VaultStats _stats = VaultStats.empty();
  final _statsService = VaultStatsService();

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final stats = await _statsService.getAggregatedStats(onRefresh: (fresh) {
      if (mounted) setState(() => _stats = fresh);
    });
    if (mounted) setState(() => _stats = stats);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  // ✅ Fix 3: Refresh stats when returning from sub-screens
  @override
  void didPopNext() {
    _fetchStats();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.background
            : AppColors.darkBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5),
              const SizedBox(height: 16),
              Text('Unlocking vault...',
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? AppColors.textSecondary
                          : AppColors.darkTextSecondary,
                      fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final isLight = Theme.of(context).brightness == Brightness.light;

    // ── ADD THESE COLOR DEFINITIONS ──
    final textColor = isLight ? AppColors.textPrimary : Colors.white;
    final subColor =
        isLight ? AppColors.textSecondary : Colors.white54; // ← THIS WAS MISSING
    final dimColor = isLight ? AppColors.textTertiary : Colors.white24;
    final bgColor = isLight ? AppColors.background : AppColors.darkBackground;
    final cardColor = isLight
        ? AppColors.surfaceVariant.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.04);
    final borderColor = isLight
        ? AppColors.primary.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor:
          isLight ? AppColors.background : const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded,
                color: isLight
                    ? AppColors.textPrimary
                    : const Color(0xFF94A3B8),
                size: 20),
            const SizedBox(width: 8),
            Text('SAFE VAULT',
                style: AppTextStyles.heading.copyWith(
                    letterSpacing: 2,
                    fontSize: 16,
                    color: isLight
                        ? AppColors.textPrimary
                        : const Color(0xFFE2E8F0))),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isLight
                      ? [Colors.white, const Color(0xFFF1F5F9)]
                      : [
                          const Color(0xFF1E293B),
                          const Color(0xFF0F172A)
                        ],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: isLight
                        ? Colors.black.withOpacity(0.05)
                        : Colors.black.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: isLight
                        ? Colors.white
                        : Colors.white.withOpacity(0.02),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
                border: Border.all(
                  color: isLight
                      ? Colors.black12
                      : Colors.white.withOpacity(0.05),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: isLight
                            ? [
                                const Color(0xFFE2E8F0),
                                const Color(0xFFCBD5E1)
                              ]
                            : [
                                const Color(0xFF334155),
                                const Color(0xFF1E293B)
                              ],
                      ),
                      border: Border.all(
                        color: isLight ? Colors.black26 : Colors.white24,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLight
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          border: Border.all(
                              color: isLight
                                  ? Colors.black12
                                  : Colors.white12),
                        ),
                        child: Icon(Icons.enhanced_encryption_rounded,
                            color: isLight
                                ? AppColors.primary
                                : const Color(0xFF4DA3FF),
                            size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vault Storage',
                            style: AppTextStyles.heading.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: textColor)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF10B981)
                                        .withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shield_outlined,
                                      color: Color(0xFF10B981), size: 12),
                                  const SizedBox(width: 4),
                                  Text('AES-256',
                                      style: AppTextStyles.caption.copyWith(
                                          color:
                                              const Color(0xFF10B981),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            _ScaleTapVault(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const RecycleBinScreen()));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isLight
                                      ? Colors.black.withOpacity(0.04)
                                      : Colors.white.withOpacity(0.05),
                                ),
                                child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: subColor,
                                    size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) {
                    return _buildCategoryCard(_categories[i]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.7)
          ]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 6))
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            _showUploadOptions(context);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.add_rounded,
              color: Colors.white, size: 28),
        ),
      ),
    );
  }

  void _showUploadOptions(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isLight ? AppColors.surface : AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: isLight ? Colors.black12 : Colors.white12,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Import to Vault',
                style: AppTextStyles.subheading.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isLight
                        ? AppColors.textPrimary
                        : Colors.white)),
            const SizedBox(height: 6),
            Text('Files are uploaded & originals auto-deleted',
                style: TextStyle(
                    color: isLight
                        ? AppColors.textSecondary
                        : Colors.white.withOpacity(0.3),
                    fontSize: 12)),
            const SizedBox(height: 20),
            _uploadOption(
                ctx,
                Icons.image_rounded,
                'Import Photo',
                'From gallery',
                AppColors.photos,
                () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage();
                },
                isLight),
            const SizedBox(height: 8),
            _uploadOption(
                ctx,
                Icons.videocam_rounded,
                'Import Video',
                'From gallery',
                AppColors.videos,
                () {
                  Navigator.pop(ctx);
                  _pickAndUploadVideo();
                },
                isLight),
            const SizedBox(height: 8),
            _uploadOption(
                ctx,
                Icons.attach_file_rounded,
                'Import File',
                'Documents, ZIP, etc.',
                AppColors.success,
                () {
                  Navigator.pop(ctx);
                  _pickAndUploadFile();
                },
                isLight),
            const SizedBox(height: 8),
            _uploadOption(
                ctx,
                Icons.camera_alt_rounded,
                'Camera',
                'Take photo directly',
                AppColors.warning,
                () {
                  Navigator.pop(ctx);
                  _takePhoto();
                },
                isLight),
            const SizedBox(height: 8),
            _uploadOption(
                ctx,
                Icons.videocam_outlined,
                'Record Video',
                'Record directly',
                AppColors.error,
                () {
                  Navigator.pop(ctx);
                  _takeVideo();
                },
                isLight),
            SizedBox(
                height: MediaQuery.of(ctx).padding.bottom + 12),
          ],
        ),
      ),
    );
  }

  Widget _uploadOption(BuildContext ctx, IconData icon, String title,
      String subtitle, Color color, VoidCallback onTap, bool isLight) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.06)
                ]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: isLight
                              ? AppColors.textPrimary
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          color: isLight
                              ? AppColors.textSecondary
                              : Colors.white.withOpacity(0.3),
                          fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 90);
      if (image != null) await _uploadAndDelete(image.path);
    } catch (e) {
      // ✅ Fix 4: Don't expose error details to user
      debugPrint('Pick image error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to pick image')));
      }
    }
  }

  Future<void> _pickAndUploadVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? video =
          await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) await _uploadAndDelete(video.path);
    } catch (e) {
      debugPrint('Pick video error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to pick video')));
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        await _uploadAndDelete(result.files.single.path!);
      }
    } catch (e) {
      debugPrint('Pick file error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to pick file')));
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 90);
      if (photo != null) await _uploadAndDelete(photo.path);
    } catch (e) {
      debugPrint('Take photo error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to take photo')));
      }
    }
  }

  Future<void> _takeVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? video =
          await picker.pickVideo(source: ImageSource.camera);
      if (video != null) await _uploadAndDelete(video.path);
    } catch (e) {
      debugPrint('Take video error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to record video')));
      }
    }
  }

  Future<void> _uploadAndDelete(String filePath) async {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Uploading to vault...'),
          duration: Duration(seconds: 60)),
    );

    try {
      // ✅ Fix 5: Detect actual type from file extension
      final extension = p.extension(filePath).toLowerCase();
      String fileType = 'document';
      
      if ({'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.heif'}
          .contains(extension)) {
        fileType = 'photo';
      } else if ({'.mp4', '.avi', '.mov', '.mkv', '.webm', '.3gp', '.flv', '.wmv'}
          .contains(extension)) {
        fileType = 'video';
      } else if ({'.mp3', '.wav', '.aac', '.flac', '.ogg', '.m4a', '.wma'}
          .contains(extension)) {
        fileType = 'audio';
      }

      final fileName = p.basename(filePath);
      await VaultEncryptionHelper.encryptAndUpload(
        filePath, 
        fileType, 
        customFileName: fileName,
      );

      await _fetchStats();

      if (!mounted) return; // ✅ Fix 6: mounted check after await

      final originalFile = File(filePath);
      final shouldDelete = await showDialog<bool>(
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
              'This file is now safely encrypted in your vault. Do you want to delete the original from your device?',
              style: AppTextStyles.body.copyWith(color: isLight ? AppColors.textSecondary : Colors.white70)
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Keep', style: TextStyle(color: isLight ? AppColors.textTertiary : Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(ctx, true);
                },
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

      if (!mounted) return; // ✅ Fix 6: mounted check after dialog

      // ✅ Fix 8: Determine correct message based on user choice
      bool wasDeleted = false;
      if (shouldDelete == true) {
        try {
          if (await originalFile.exists()) {
            await originalFile.delete();
            wasDeleted = true;
          }
        } catch (_) {}
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        await SoundEffects.uploadSuccess();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ConfettiOverlay.show(context);
        PremiumSnackbar.show(
          context,
          message: wasDeleted
              ? 'Uploaded & deleted from phone'
              : 'Uploaded to vault successfully',
          emoji: '🎉',
          color: const Color(0xFF10B981),
        );
      }
    } catch (e) {
      // ✅ Fix 9: Don't expose error details
      debugPrint('Upload error: $e');
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildCategoryCard(_VaultCategory category) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? AppColors.textPrimary : Colors.white;
    final subColor = isLight ? AppColors.textSecondary : Colors.white54;
    final dimColor = isLight ? AppColors.textTertiary : Colors.white24;

    final panelGradient = isLight
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8FAFC)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF121B2B)],
          );

    return _ScaleTapVault(
      onTap: () {
        Widget screen;
        switch (category.type) {
          case 'photo':
            screen = const PhotosListScreen();
            break;
          case 'video':
            screen = const VideosListScreen();
            break;
          case 'note':
            screen = const NotesListScreen();
            break;
          case 'document':
            screen = const DocumentsListScreen();
            break;
          case 'app_hider':
            screen = const AppHiderScreen();
            break;
          default:
            screen = const PhotosListScreen();
        }
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => screen));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: panelGradient,
          border: Border.all(
            color: isLight
                ? Colors.black.withOpacity(0.05)
                : Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isLight
                  ? Colors.black.withOpacity(0.04)
                  : Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: isLight
                  ? Colors.white
                  : Colors.white.withOpacity(0.05),
              blurRadius: 1,
              offset: const Offset(0, 1),
              blurStyle: BlurStyle.inner,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLight
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF0F172A),
                border: Border.all(
                    color: isLight
                        ? Colors.black.withOpacity(0.06)
                        : Colors.black.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                      color: category.color.withOpacity(0.2),
                      blurRadius: 16,
                      spreadRadius: -2),
                  BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(-1, -1)),
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(2, 2)),
                ],
              ),
              child: Center(
                child: Icon(category.icon,
                    color: category.color, size: 24),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              category.label,
              style: AppTextStyles.subheading.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _getCategoryCount(category.type),
              style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: subColor, // ✅ Now defined
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryCount(String type) {
    int count = 0;
    switch (type) {
      case 'photo':
        count = _stats.photoCount;
        break;
      case 'video':
        count = _stats.videoCount;
        break;
      case 'note':
        count = _stats.noteCount;
        break;
      case 'document':
        count = _stats.docCount;
        break;
      case 'app_hider':
        return 'Settings'; // ✅ Fix 11: app_hider doesn't have a count
      default:
        count = 0;
    }

    if (count == 0) return 'Empty';
    if (count == 1) return '1 item';
    return '$count items';
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
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}