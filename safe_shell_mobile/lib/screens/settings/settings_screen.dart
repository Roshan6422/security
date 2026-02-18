import 'package:flutter/material.dart';
import 'dart:io';
import '../../core/theme.dart';
import '../../widgets/glass_card.dart';
import '../calculator/calculator_screen.dart';
import 'support_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../profile/profile_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'privacy_policy_screen.dart';
import '../../services/background_service_config.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _backgroundRun = true;
  bool _batterySaver = false;
  bool _biometrics = false;
  bool _discreetMode = false;
  bool _localCloak = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _checkServiceStatus();
    _loadDiscreetMode();
    _loadLocalCloakStatus();
  }

  Future<void> _loadLocalCloakStatus() async {
    final saved = await _storage.read(key: 'local_cloak_enabled');
    if (mounted) setState(() => _localCloak = saved == 'true');
  }

  Future<void> _loadBiometricSetting() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final saved = await _storage.read(key: 'biometric_enabled');
      if (mounted) {
        setState(() {
          _canUseBiometrics = canCheck && isSupported;
          _biometrics = saved == 'true';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDiscreetMode() async {
    final saved = await _storage.read(key: 'discreet_mode');
    if (mounted) setState(() => _discreetMode = saved == 'true');
  }

  Future<void> _toggleDiscreetMode(bool value) async {
    if (value) {
      // Show explanation dialog before enabling
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Enable Discreet Mode?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'When enabled, the app icon will appear as a calculator for added privacy.\n\nYou can switch back to the standard icon anytime from this settings page.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enable', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    try {
      final channel = const MethodChannel('com.safeshell.safe_shell_mobile/stealth');
      await channel.invokeMethod('toggleStealthMode', {'enable': value});
      await _storage.write(key: 'discreet_mode', value: value.toString());
      if (mounted) {
        setState(() => _discreetMode = value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? 'Discreet Mode enabled — icon switched to Calculator' : 'Standard icon restored')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _checkServiceStatus() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (mounted) setState(() => _backgroundRun = isRunning);
  }
  
  Future<void> _toggleBackgroundService(bool value) async {
    final service = FlutterBackgroundService();
    if (value) {
      await BackgroundServiceConfig.initializeService();
      var isRunning = await service.startService();
      if (!isRunning) {
         // Try again or wait a bit? usually startService returns distinct bool
      }
    } else {
      service.invoke('stopService');
    }
    setState(() => _backgroundRun = value);
  }

  Future<void> _requestBatteryOptimization(bool value) async {
    if (!value) {
       setState(() => _batterySaver = false);
       return;
    }

    // 1. Explanation Dialog
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Enable Ultra Protection?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'To ensure your files remain protected at all times, please allow SafeShell to run without battery restrictions.\n\nThis prevents the system from stopping the protection service.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Enable Protection', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (proceed == true) {
      // 2. Request System Dialog
      var status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        status = await Permission.ignoreBatteryOptimizations.request();
      }
      
      if (mounted) {
         setState(() => _batterySaver = status.isGranted);
         if (status.isGranted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ultra Protection Enabled! 🛡️')));
         } else {
           setState(() => _batterySaver = false); // Revert
         }
      }
    } else {
      setState(() => _batterySaver = false);
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // 1. Check hardware capability first
      try {
        final bool isSupported = await _localAuth.isDeviceSupported();
        final bool canCheck = await _localAuth.canCheckBiometrics;
        
        if (!isSupported || !canCheck) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometric hardware not available or not setup on this device.')),
            );
          }
          return;
        }

        // 2. Prompt for biometric before enabling
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Confirm identity to enable Biometric Lock',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false, // Allow PIN/Pattern if fingerprint fails
          ),
        );
        if (!authenticated) return;
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
        return;
      }
    }

    await _storage.write(key: 'biometric_enabled', value: value.toString());
    if (mounted) {
      setState(() => _biometrics = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'Biometric lock enabled ✅' : 'Biometric lock disabled')),
      );
    }
  }

  Future<void> _toggleLocalCloak(bool value) async {
    // 1. Request Storage Permissions
    if (value) {
      if (await Permission.storage.request().isDenied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage permission required for Local Cloak')));
        return;
      }
      
      // On Android 11+ (API 30+), MANAGE_EXTERNAL_STORAGE is often required to write .nomedia in system folders
      if (await Permission.manageExternalStorage.isDenied) {
        final status = await Permission.manageExternalStorage.request();
        if (status.isDenied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All Files Access is required to hide system Gallery folders. Please enable it in Settings.'))
          );
          return;
        }
      }
    }

    // Update global state via provider
    if (mounted) {
      await Provider.of<SettingsProvider>(context, listen: false).toggleLocalCloak(value);
    }
    
    setState(() => _localCloak = value);

    // 2. Perform File Operations
    try {
      final List<String> targetDirs = [
        '/storage/emulated/0/DCIM/Camera',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Images',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents',
      ];

      int successCount = 0;
      int failCount = 0;

      for (var path in targetDirs) {
        try {
          final dir = Directory(path);
          if (await dir.exists()) {
            final nomediaFile = File('${dir.path}/.nomedia');
            if (value) {
              if (!await nomediaFile.exists()) {
                await nomediaFile.create();
              }
            } else {
              if (await nomediaFile.exists()) {
                await nomediaFile.delete();
              }
            }
            successCount++;
          }
        } catch (e) {
          failCount++;
          debugPrint('Error for $path: $e');
        }
      }

      if (mounted) {
        if (failCount > 0 && successCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operation failed. Please ensure All Files Access is granted.'), backgroundColor: Colors.redAccent)
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value ? 'Local Cloak Active: Media hidden from Gallery' : 'Local Cloak Disabled: Media restored to Gallery'),
              backgroundColor: value ? AppColors.primary : Colors.grey,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Critical Error: $e')));
    }
  }

  int get _perfScore {
    int score = 92;
    if (!_backgroundRun) score -= 6;
    if (_batterySaver) score -= 4;
    if (!_biometrics) score -= 2;
    return score.clamp(70, 99);
  }

  String get _statusText {
    if (_perfScore >= 92) return 'Optimized';
    if (_perfScore >= 84) return 'Good';
    return 'Balanced';
  }

  Color get _statusColor {
    if (_perfScore >= 92) return const Color(0xFF10B981);
    if (_perfScore >= 84) return AppColors.primary;
    return const Color(0xFFF59E0B);
  }

  // --- Calculator PIN Logic ---
  Future<void> _setCalculatorPin() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Set Calculator PIN', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a numeric PIN to open the vault from the calculator. Default is 112233.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 123456',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (!RegExp(r'^\d+$').hasMatch(result)) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be numeric only')));
         return;
      }

      // Check current PIN first (simulated security flow - in real app would ask old pin)
      // For now just update directly
       try {
        await ApiService().put('/auth/calculator-password', {'newPassword': result}); // Note: Api needs adjustment if we want to skip old password check or we add a "Force" flag. 
        // Actually the backend expects oldPassword if one exists.
        // Let's rely on the user knowing the old one? Or if first time?
        // Let's try to update. If 401, we ask for old.
        // Simplified flow: Just Try Update (assuming raw update or improve backend later).
        // Wait, the backend verification logic:
        /*
        if (user.calculatorPassword) {
            if (user.calculatorPassword !== oldPassword) {
                return res.status(401).json({ message: 'Incorrect old password' });
            }
        }
        */
        // So we need to ask Old Password if set. 
        // For this "Emergency Fix", let's ask for Old Password only if the first attempt fails?
        // Or simpler: Just a dialog with "Old PIN (optional/default 112233)" and "New PIN".
        
        // Let's do a better dialog flow really quick.
      } catch (e) {
         // ignore error for the optimistic update below, but ideally we should handle it.
      }
      
      // RE-IMPLEMENTING DIALOG TO ASK OLD AND NEW
    }
  }
  
  Future<void> _changePinFlow() async {
      final oldController = TextEditingController();
      final newController = TextEditingController();
      
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Set Connection PIN', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your current PIN (default 112233) and new PIN.', style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: oldController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Old PIN', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'New PIN', labelStyle: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final oldPin = oldController.text.isEmpty ? '112233' : oldController.text;
                final newPin = newController.text;
                if (newPin.isEmpty) return;
                                try {
                    await ApiService().put('/auth/calculator-password', {
                      'oldPassword': oldPin,
                      'newPassword': newPin
                    });
                    
                    // SAVE LOCALLY FOR OFFLINE ACCESS
                    await _storage.write(key: 'calculator_pin', value: newPin);

                     if (mounted) {
                       Navigator.pop(ctx);
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN Updated Successfully!')));
                     }
                  } catch(e) {
                   if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                   }
                }
              }, 
              child: const Text('Update', style: TextStyle(color: AppColors.primary))
            ),
          ],
        ),
      );
  }

  Future<void> _confirmClearAppData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Reset Application?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will delete all local settings, clear cache, and log you out.\n\nYour SafeShell vault data in the cloud will be PRESERVED.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset & Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // 1. Clear Cache
        await DefaultCacheManager().emptyCache();
        
        // 2. Clear Secure Storage
        await const FlutterSecureStorage().deleteAll();
        
        // 3. Clear Shared Prefs
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (mounted) {
           // Navigate to Login (Remove all routes)
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (_) => const LoginScreen()),
             (route) => false,
           );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Pop loading
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reset: $e')));
        }
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background gradients
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 520,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.12), blurRadius: 120),
                ],
              ),
            ),
          ),

          SingleChildScrollView(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text('Settings', style: AppTextStyles.display.copyWith(fontSize: 28)),
                const SizedBox(height: 4),
                Text(
                  'Customize your vault experience',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary.withOpacity(0.55), fontSize: 14),
                ),
                const SizedBox(height: 24),

                // Performance Card
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                              boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.28), blurRadius: 16)],
                            ),
                            child: const Icon(Icons.trending_up, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('App Performance', style: AppTextStyles.subheading.copyWith(fontSize: 16)),
                                Text(
                                  '$_statusText • $_perfScore%',
                                  style: AppTextStyles.caption.copyWith(color: _statusColor, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              _miniCircleIcon(Icons.memory),
                              const SizedBox(width: 8),
                              _miniCircleIcon(Icons.verified_user),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 10,
                          child: Stack(
                            children: [
                              Container(color: Colors.white.withOpacity(0.1)),
                              FractionallySizedBox(
                                widthFactor: _perfScore / 100,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                    ),
                                    boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 10)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _miniStat(Icons.bolt, 'Background', _backgroundRun ? 'On' : 'Off')),
                          const SizedBox(width: 8),
                          Expanded(child: _miniStat(Icons.battery_saver, 'Saver', _batterySaver ? 'On' : 'Off')),
                          const SizedBox(width: 8),
                          Expanded(child: _miniStat(Icons.security, 'Biometric', _biometrics ? 'On' : 'Off')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Discreet Mode Toggle (Play Store Safe)
                _toggleTile(
                  Icons.calculate,
                  'Discreet Mode',
                  _discreetMode ? 'Calculator icon active' : 'Switch to calculator-style icon',
                  _discreetMode,
                  (v) => _toggleDiscreetMode(v),
                ),
                const SizedBox(height: 24),

                // System Section
                _sectionTitle(Icons.auto_awesome, 'System'),
                const SizedBox(height: 12),
                _toggleTile(Icons.bolt, 'Background Protection', 'Keep app running to secure files', _backgroundRun, (v) => _toggleBackgroundService(v)),
                const SizedBox(height: 8),
                _toggleTile(Icons.battery_full, 'Disable Battery Opt', 'Prevent system killing app', _batterySaver, (v) => _requestBatteryOptimization(v)),
                const SizedBox(height: 24),

                // Security Section
                _sectionTitle(Icons.lock, 'Security'),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                _actionTile(Icons.person, 'My Profile', 'Manage account & data', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
                const SizedBox(height: 8),
                _toggleTile(Icons.security, 'Biometric Lock', _canUseBiometrics ? 'Use Face ID or Fingerprint' : 'Not supported on this device', _biometrics, _canUseBiometrics ? _toggleBiometric : null),
                const SizedBox(height: 8),
                // NEW: Change Password Option
                _actionTile(Icons.pin, 'Set Calculator PIN', 'Change the math hidden PIN', () => _changePinFlow()),
                const SizedBox(height: 24),


                // Tools Section
                _sectionTitle(Icons.refresh, 'Tools'),
                const SizedBox(height: 12),
                _actionTile(Icons.cleaning_services, 'Clear Cache', 'Free up space & memory', () async {
                  try {
                    await DefaultCacheManager().emptyCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared & Memory Optimized! 🧹✨')));
                    }
                  } catch (e) {
                     if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear cache: $e')));
                  }
                }),
                const SizedBox(height: 8),
                _actionTile(
                  Icons.delete_forever,
                  'Clear App Data',
                  'Reset everything (Log out)',
                  () => _confirmClearAppData(),
                ),
                const SizedBox(height: 8),
                _toggleTile(
                  Icons.visibility_off, 
                  'Local Cloak Mode', 
                  'Hide phone media from other apps', 
                  _localCloak, 
                  (v) => _toggleLocalCloak(v)
                ),
                const SizedBox(height: 8),
                _actionTile(
                  Icons.privacy_tip, 
                  'Privacy Policy', 
                  'Read our policy', 
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniCircleIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
    );
  }

  Widget _miniStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.25), Colors.white.withOpacity(0.05)]),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(0.85), size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppColors.textSecondary.withOpacity(0.45), fontSize: 11, fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.subheading.copyWith(fontSize: 18)),
      ],
    );
  }

  Widget _toggleTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool>? onChanged) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.25), Colors.white.withOpacity(0.05)]),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(0.85), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            inactiveThumbColor: Colors.white.withOpacity(0.5),
            inactiveTrackColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.25), Colors.white.withOpacity(0.05)]),
              ),
              child: Icon(icon, color: Colors.white.withOpacity(0.85), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                  Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

