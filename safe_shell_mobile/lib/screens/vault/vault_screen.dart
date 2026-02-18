import 'dart:io';
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
import 'zip_list_screen.dart';
import 'recycle_bin_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'local_cloak_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../main.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with RouteAware {
  final _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isUnlocked = false;
  bool _isLoading = true;
  bool _isAuthenticating = false;
  bool _biometricEnabled = false;
  
  final List<_VaultCategory> _categories = [
    _VaultCategory(Icons.image, 'Photos', 'photo', const Color(0xFF4DA3FF)),
    _VaultCategory(Icons.videocam, 'Videos', 'video', const Color(0xFF8B5CF6)),
    _VaultCategory(Icons.audiotrack, 'Audio', 'audio', const Color(0xFFE11D48)),
    _VaultCategory(Icons.sticky_note_2, 'Notes', 'note', const Color(0xFFFCD34D)),
    _VaultCategory(Icons.description, 'Documents', 'document', const Color(0xFF10B981)),
    _VaultCategory(Icons.folder_zip, 'ZIP Files', 'zip', const Color(0xFFF59E0B)),
  ];

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Refresh settings when returning to this screen
    _checkBiometric();
  }

  /// Check if biometric is enabled, then gate access accordingly
  Future<void> _checkBiometric() async {
    try {
      final saved = await _storage.read(key: 'biometric_enabled');
      _biometricEnabled = saved == 'true';

      if (_biometricEnabled && !_isUnlocked) {
        // Biometric is enabled and currently locked → show lock screen, require fingerprint
        if (mounted) {
          setState(() {
            _isUnlocked = false;
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
        }
      } else {
        // Biometric not enabled OR already unlocked
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      // On error, default to current state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Prompt fingerprint / Face ID / PIN authentication
  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    
    // 1. Check if device supports biometrics at all
    final bool isSupported = await _localAuth.isDeviceSupported();
    final bool canCheck = await _localAuth.canCheckBiometrics;
    
    if (!isSupported || !canCheck) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric hardware not available or not setup.')),
        );
      }
      return;
    }

    _isAuthenticating = true;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock your Vault (Face ID or Fingerprint)',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/Pattern fallback
          useErrorDialogs: true,
        ),
      );

      if (mounted) {
        setState(() {
          _isUnlocked = authenticated;
          _isAuthenticating = false;
        });
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric Error: $e');
      if (mounted) {
        setState(() => _isAuthenticating = false);
        
        String errorMsg = 'Authentication error. Try again.';
        if (e.code == 'NotEnrolled') {
          errorMsg = 'No Face/Fingerprint/PIN enrolled on this device.';
        } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
          errorMsg = 'Too many attempts. Locked out.';
        } else if (e.code == 'NotAvailable') {
          errorMsg = 'Biometric sensor (Face/Fingerprint) not available.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            action: SnackBarAction(label: 'Enter Password', onPressed: _showEmergencyUnlock),
          ),
        );
      }
    }
  }

  /// Show dialog to enter recovery key and bypass biometrics
  Future<void> _showEmergencyUnlock() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Emergency Unlock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Account Password to bypass biometric lock and access your vault.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: 'Enter Password',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), letterSpacing: 0),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final input = controller.text.trim();
              final saved = await _storage.read(key: 'saved_password');
              
              if (input == (saved ?? "").trim()) {
                if (ctx.mounted) Navigator.pop(ctx, true);
              } else {
                if (ctx.mounted) {
                   ScaffoldMessenger.of(ctx).showSnackBar(
                     const SnackBar(content: Text('Invalid Password'), backgroundColor: Colors.redAccent)
                   );
                }
              }
            },
            child: const Text('Unlock', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() => _isUnlocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlocked via Password ✅'), backgroundColor: Color(0xFF10B981)),
      );
    }
  }

  /// Re-lock vault when user switches away (called externally via key or visibility)
  void lockVault() {
    if (_biometricEnabled && mounted) {
      setState(() => _isUnlocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // -- LOCKED STATE: show fingerprint prompt --
    if (!_isUnlocked) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
                ),
                child: const Icon(Icons.lock_person, size: 72, color: AppColors.primary),
              ),
              const SizedBox(height: 28),
              Text('Vault Locked', style: AppTextStyles.display.copyWith(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                'Use Face ID or Fingerprint to unlock',
                style: AppTextStyles.body.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 36),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF2B7FDB)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20)],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isAuthenticating ? null : _authenticate,
                  icon: const Icon(Icons.security, color: Colors.white),
                  label: Text(
                    _isAuthenticating ? 'Verifying...' : 'Unlock Vault',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _showEmergencyUnlock,
                icon: const Icon(Icons.password, size: 18, color: Colors.white38),
                label: Text(
                  'Unlock with Account Password',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // -- UNLOCKED VAULT UI --
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Vault', style: AppTextStyles.heading.copyWith(fontSize: 24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecycleBinScreen())),
            tooltip: 'Recycle Bin',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🔒 Encrypted Storage', style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.4))),
              const SizedBox(height: 16),
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  if (!settings.localCloakEnabled) return const SizedBox.shrink();
                  
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalCloakScreen())),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.visibility_off, color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Local Cloak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('View hidden phone media', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) {
                    return _buildCategoryCard(_categories[i]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF2B7FDB)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: FloatingActionButton(
          onPressed: () => _showUploadOptions(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Import to Vault', style: AppTextStyles.subheading.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            Text('Files are uploaded & originals auto-deleted', 
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            const SizedBox(height: 20),
            _uploadOption(ctx, Icons.image, 'Import Photo', 'From gallery', () {
              Navigator.pop(ctx);
              _pickAndUploadImage();
            }),
            const SizedBox(height: 12),
            _uploadOption(ctx, Icons.videocam, 'Import Video', 'From gallery', () {
              Navigator.pop(ctx);
              _pickAndUploadVideo();
            }),
            const SizedBox(height: 12),
            _uploadOption(ctx, Icons.attach_file, 'Import File', 'Documents, ZIP, etc.', () {
              Navigator.pop(ctx);
              _pickAndUploadFile();
            }),
            const SizedBox(height: 12),
            _uploadOption(ctx, Icons.camera_alt, 'Camera', 'Take photo directly', () {
              Navigator.pop(ctx);
              _takePhoto();
            }),
            const SizedBox(height: 12),
            _uploadOption(ctx, Icons.videocam_outlined, 'Record Video', 'Record directly', () {
              Navigator.pop(ctx);
              _takeVideo();
            }),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 12),
          ],
        ),
      ),
    );
  }

  Widget _uploadOption(BuildContext ctx, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.3), Colors.white.withOpacity(0.05)]),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  /// Pick photo from gallery → upload → delete original
  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (image != null) {
        await _uploadAndDelete(image.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Pick video from gallery → upload → delete original
  Future<void> _pickAndUploadVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        await _uploadAndDelete(video.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Pick any file → upload → delete original
  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        await _uploadAndDelete(result.files.single.path!);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Take photo with camera → upload → delete temp
  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (photo != null) {
        await _uploadAndDelete(photo.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Record video with camera → upload → delete temp
  Future<void> _takeVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.camera);
      if (video != null) {
        await _uploadAndDelete(video.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Upload file to database → auto-delete original from phone
  Future<void> _uploadAndDelete(String filePath) async {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📤 Uploading to vault...'), duration: Duration(seconds: 60)),
    );

    try {
      // 1. Upload to database via API
      await ApiService().uploadMultipart('/vault/upload', filePath);
      
      // 2. Auto-delete original from phone
      try {
        final originalFile = File(filePath);
        if (await originalFile.exists()) {
          await originalFile.delete();
        }
      } catch (_) {
        // Can't delete original (permissions), that's OK
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Uploaded & deleted from phone'), 
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildCategoryCard(_VaultCategory category) {
    return GestureDetector(
      onTap: () {
        Widget screen;
        switch (category.type) {
          case 'photo': screen = const PhotosListScreen(); break;
          case 'video': screen = const VideosListScreen(); break;
          case 'audio': screen = const AudioListScreen(); break;
          case 'note': screen = const NotesListScreen(); break;
          case 'document': screen = const DocumentsListScreen(); break;
          case 'zip': screen = const ZipListScreen(); break;
          default: screen = const PhotosListScreen();
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(category.icon, color: category.color, size: 26),
            ),
            const SizedBox(height: 14),
            Text(category.label, style: AppTextStyles.subheading.copyWith(fontSize: 14)),
          ],
        ),
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
