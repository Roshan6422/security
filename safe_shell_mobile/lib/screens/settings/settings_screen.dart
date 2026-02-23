import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/panic_button.dart';
import '../calculator/calculator_screen.dart';
import '../analytics/analytics_screen.dart';
import '../support/support_screen.dart';
import '../../widgets/text_field_m3.dart';
import '../../widgets/primary_button.dart';
import '../profile/profile_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'privacy_policy_screen.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/sound_effects.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _batterySaver = false;
  bool _biometrics = false;

  bool _localCloak = false;
  bool _discreetMode = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  bool _canUseBiometrics = false;
  bool _allowScreenshots = false;

  // Auto-lock options in seconds (0 = off)
  static const _lockOptions = [0, 30, 60, 120, 300, 600];
  static const _lockLabels = ['Off', '30s', '1m', '2m', '5m', '10m'];
  int _autoLockSeconds = 0;

  static const _stealthChannel = MethodChannel('com.safeshell.safe_shell_mobile/stealth');

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _loadLocalCloakStatus();
    _loadDiscreetMode();
    _loadAutoLock();
  }

  Future<void> _loadAutoLock() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final val = settings.autoLockSeconds;
    if (mounted) setState(() => _autoLockSeconds = val);
  }

  String _labelForSeconds(int seconds) {
    final idx = _lockOptions.indexOf(seconds);
    if (idx == -1) return '${seconds}s';
    return _lockLabels[idx];
  }

  Future<void> _setAutoLock(int seconds) async {
    await Provider.of<SettingsProvider>(context, listen: false).setAutoLockSeconds(seconds);
    setState(() => _autoLockSeconds = seconds);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(seconds == 0
              ? 'Auto-Lock disabled'
              : 'Auto-Lock set to ${_labelForSeconds(seconds)}'),
          backgroundColor: seconds == 0 ? null : const Color(0xFFA855F7),
        ),
      );
    }
  }

  Future<void> _loadDiscreetMode() async {
    final mode = await _storage.read(key: 'discreet_mode');
    if (mounted) setState(() => _discreetMode = mode == 'true');
  }

  Future<void> _toggleDiscreetMode(bool value) async {
    if (value) {
      // Check if PIN is set first
      final pin = await _storage.read(key: 'calculator_pin');
      if (pin == null || pin.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please set a Calculator PIN first')),
          );
        }
        return;
      }
    }

    await _storage.write(key: 'discreet_mode', value: value.toString());
    
    // Trigger native icon swap
    try {
      await _stealthChannel.invokeMethod('toggleStealthMode', {'enable': value});
    } catch (e) {
      debugPrint('Error toggling stealth mode: $e');
    }

    setState(() => _discreetMode = value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Stealth Mode Active' : 'Stealth Mode Disabled'),
          backgroundColor: value ? Colors.blue : null,
        ),
      );
    }
  }

  Future<void> _setCalculatorPin() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final pinController = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Set Calculator PIN',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFieldM3(
                controller: pinController,
                label: '4-digit PIN',
                icon: Icons.pin_rounded,
                obscure: true,
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter 4 digits to use in the calculator disguise.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            SizedBox(
              width: 100,
              child: PrimaryButton(
                text: 'Save',
                onPressed: () => Navigator.pop(ctx, pinController.text),
              ),
            ),
          ],
        );
      },
    );

    if (result != null && result.length == 4) {
      await _storage.write(key: 'calculator_pin', value: result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN Saved! Type this on calculator to unlock.')),
        );
      }
    }
  }

  Future<void> _changePinFlow() async {
    await _setCalculatorPin();
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

  Future<void> _requestBatteryOptimization(bool value) async {
    if (!value) {
      setState(() => _batterySaver = false);
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Enable Ultra Protection?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'To ensure your files remain protected at all times, please allow SafeShell to run without battery restrictions.\n\nThis prevents the system from stopping the protection service.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enable Protection',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (proceed == true) {
      var status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        status = await Permission.ignoreBatteryOptimizations.request();
      }

      if (mounted) {
        setState(() => _batterySaver = status.isGranted);
        if (status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ultra Protection Enabled! ???')));
        } else {
          setState(() => _batterySaver = false);
        }
      }
    } else {
      setState(() => _batterySaver = false);
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      try {
        final bool isSupported = await _localAuth.isDeviceSupported();
        final bool canCheck = await _localAuth.canCheckBiometrics;

        if (!isSupported || !canCheck) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Biometric hardware not available or not setup on this device.')),
            );
          }
          return;
        }

        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Confirm identity to enable Biometric Lock',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
            sensitiveTransaction: false,
            useErrorDialogs: true,
          ),
        );
        if (!authenticated) return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Verification failed: $e')));
        }
        return;
      }
    }

    await _storage.write(key: 'biometric_enabled', value: value.toString());
    if (mounted) {
      setState(() => _biometrics = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(value
                ? 'Biometric lock enabled ?'
                : 'Biometric lock disabled')),
      );
    }
  }

  Future<void> _toggleScreenshot(bool value) async {
    try {
      await _stealthChannel.invokeMethod('toggleScreenshot', {'allow': value});
      setState(() => _allowScreenshots = value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(value ? 'Screenshots Allowed' : 'Screenshots Blocked'),
            backgroundColor: value ? Colors.green : null,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling screenshots: $e');
    }
  }

  Future<void> _toggleLocalCloak(bool value) async {
    if (value) {
      if (await Permission.storage.request().isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Storage permission required for Local Cloak')));
        }
        return;
      }

      if (await Permission.manageExternalStorage.isDenied) {
        final status = await Permission.manageExternalStorage.request();
        if (status.isDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'All Files Access is required to hide system Gallery folders. Please enable it in Settings.')));
          }
          return;
        }
      }
    }

    if (mounted) {
      await Provider.of<SettingsProvider>(context, listen: false)
          .toggleLocalCloak(value);
    }

    setState(() => _localCloak = value);

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

      for (var dirPath in targetDirs) {
        try {
          final dir = Directory(dirPath);
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
          debugPrint('Error for $dirPath: $e');
        }
      }

      int restoredCount = 0;
      if (!value) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final cloakDir =
              Directory(p.join(appDir.path, '.SafeShellCloak'));

          if (await cloakDir.exists()) {
            Map<String, String> metadata = {};
            final metaFile =
                File(p.join(cloakDir.path, 'cloak_metadata.json'));
            if (await metaFile.exists()) {
              try {
                final content = await metaFile.readAsString();
                final decoded =
                    jsonDecode(content) as Map<String, dynamic>;
                metadata =
                    decoded.map((k, v) => MapEntry(k, v.toString()));
              } catch (_) {}
            }

            final entities = cloakDir.listSync();
            for (var entity in entities) {
              if (entity is File &&
                  entity.path.endsWith('.safe_cloak')) {
                try {
                  final obfName = p.basename(entity.path);
                  final originalPath = metadata[obfName];

                  if (originalPath != null && originalPath.isNotEmpty) {
                    final parentDir =
                        Directory(p.dirname(originalPath));
                    if (!await parentDir.exists()) {
                      await parentDir.create(recursive: true);
                    }
                    await entity.copy(originalPath);
                  } else {
                    final encoded =
                        obfName.replaceAll('.safe_cloak', '');
                    String originalName;
                    try {
                      originalName =
                          utf8.decode(base64Url.decode(encoded));
                    } catch (_) {
                      originalName = obfName;
                    }
                    final restoreDir = Directory(
                        '/storage/emulated/0/SafeShell_Restored');
                    if (!await restoreDir.exists()) {
                      await restoreDir.create(recursive: true);
                    }
                    await entity.copy(
                        p.join(restoreDir.path, originalName));
                  }

                  await entity.delete();
                  restoredCount++;
                } catch (e) {
                  debugPrint('Error restoring file: $e');
                }
              }
            }

            if (await metaFile.exists()) {
              await metaFile.delete();
            }
          }
        } catch (e) {
          debugPrint('Error restoring cloaked files: $e');
        }
      }

      if (mounted) {
        if (failCount > 0 && successCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text(
                  'Operation failed. Please ensure All Files Access is granted.'),
              backgroundColor: Colors.redAccent));
        } else {
          final msg = value
              ? 'Local Cloak Active: Media hidden from Gallery'
              : 'Local Cloak Disabled: Media restored to Gallery${restoredCount > 0 ? ' ($restoredCount files recovered)' : ''}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: value ? AppColors.primary : Colors.grey,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Critical Error: $e')));
      }
    }
  }

  Future<void> _confirmClearAppData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Reset Application?',
            style: TextStyle(
                color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will delete all local settings, clear cache, and log you out.\n\nYour SafeShell vault data in the cloud will be PRESERVED.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset & Logout',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await DefaultCacheManager().emptyCache();
        await const FlutterSecureStorage().deleteAll();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to reset: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: Stack(
        children: [
          // Background gradients
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.primary.withOpacity(0.06),
                  Colors.transparent
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.04),
                  Colors.transparent
                ]),
              ),
            ),
          ),

          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              bottom: 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text('Settings',
                    style: AppTextStyles.display.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('Customize your vault experience',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.25), fontSize: 13)),
                const SizedBox(height: 20),

                // App Version Info
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(colors: [
                      AppColors.primary.withOpacity(0.08),
                      AppColors.primary.withOpacity(0.02)
                    ]),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.primary.withOpacity(0.2),
                            AppColors.primary.withOpacity(0.06)
                          ]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.shield_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SafeShell Base',
                              style: AppTextStyles.subheading.copyWith(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          Text('Version 1.0.0',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.2),
                                  fontSize: 11)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Latest',
                            style: TextStyle(
                                color:
                                    const Color(0xFF34D399).withOpacity(0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Security Section
                _sectionTitle(
                    Icons.lock_rounded, 'Security', const Color(0xFFA855F7)),
                const SizedBox(height: 12),
                _actionTile(
                    Icons.person_rounded,
                    'My Profile',
                    'Manage account & data',
                    const Color(0xFFA855F7), () {
                  SoundEffects.tap();
                  HapticFeedback.selectionClick();
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()));
                }),
                const SizedBox(height: 8),
                _toggleTile(
                    Icons.fingerprint_rounded,
                    'Biometric Lock',
                    _canUseBiometrics
                        ? 'Use fingerprint to unlock'
                        : 'Not supported',
                    _biometrics,
                    const Color(0xFF8B5CF6),
                    _canUseBiometrics
                        ? (v) {
                            SoundEffects.tap();
                            _toggleBiometric(v);
                          }
                        : null),
                const SizedBox(height: 8),
                _toggleTile(
                    Icons.screenshot_rounded,
                    'Allow Screenshots',
                    'Temporarily enable screenshots',
                    _allowScreenshots,
                    const Color(0xFFF59E0B), (v) {
                  SoundEffects.tap();
                  _toggleScreenshot(v);
                }),
                const SizedBox(height: 8),
                _toggleTile(
                    Icons.calculate_rounded,
                    'Discreet Mode',
                    'Disguise SafeShell as a Calculator',
                    _discreetMode,
                    const Color(0xFF34D399), (v) {
                  SoundEffects.tap();
                  _toggleDiscreetMode(v);
                }),
                const SizedBox(height: 8),
                _actionTile(Icons.pin_rounded, 'Set Calculator PIN',
                    'Change the maths hidden Pin', const Color(0xFFA855F7),
                    () {
                  SoundEffects.tap();
                  HapticFeedback.selectionClick();
                  _changePinFlow();
                }),
                const SizedBox(height: 24),

                // Tools Section
                _sectionTitle(Icons.build_circle_rounded, 'Tools',
                    const Color(0xFF34D399)),
                const SizedBox(height: 12),
                _actionTile(
                    Icons.cleaning_services_rounded,
                    'Clear Cache',
                    'Free up space & memory',
                    const Color(0xFF34D399), () async {
                  HapticFeedback.mediumImpact();
                  try {
                    await DefaultCacheManager().emptyCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('Cache cleared & Memory Optimized! ???'),
                          backgroundColor: Color(0xFF34D399)));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to clear cache: $e')));
                    }
                  }
                }),
                const SizedBox(height: 8),

                _actionTile(Icons.bar_chart_rounded, 'Analytics',
                    'View storage charts & trends', const Color(0xFF34D399),
                    () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AnalyticsScreen()));
                }),
                const SizedBox(height: 8),
                _actionTile(Icons.headset_mic_rounded, 'Customer Support',
                    'Get help', const Color(0xFFF59E0B), () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SupportScreen()));
                }),
                const SizedBox(height: 8),
                _actionTile(Icons.privacy_tip_rounded, 'Privacy Policy',
                    'Read our policy', const Color(0xFF8B5CF6), () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen()));
                }),
                const SizedBox(height: 24),

                // Auto-Lock Timer Section
                _sectionTitle(
                    Icons.timer_rounded, 'Auto-Lock', const Color(0xFF8B5CF6)),
                const SizedBox(height: 12),
                _autoLockTile(),
                const SizedBox(height: 24),

                // Danger Zone
                _sectionTitle(Icons.warning_amber_rounded, 'Danger Zone',
                    const Color(0xFFEF4444)),
                const SizedBox(height: 12),
                const PanicButton(),
                const SizedBox(height: 8),
                _actionTile(
                    Icons.delete_forever_rounded,
                    'Clear App Data',
                    'Reset everything (Log out)',
                    const Color(0xFFEF4444), () {
                  SoundEffects.deleteAction();
                  HapticFeedback.heavyImpact();
                  _confirmClearAppData();
                }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _autoLockTile() {
    const color = Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF161B22),
        border: Border.all(color: color.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.05)
                  ]),
                ),
                child:
                    const Icon(Icons.timer_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Auto-Lock Timer',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Text(
                      _autoLockSeconds == 0
                          ? 'App stays unlocked'
                          : 'Lock after ${_labelForSeconds(_autoLockSeconds)} of inactivity',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Pill options
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_lockOptions.length, (i) {
                final selected = _lockOptions[i] == _autoLockSeconds;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _setAutoLock(_lockOptions[i]);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: selected ? color : color.withOpacity(0.06),
                      border: Border.all(
                          color:
                              selected ? color : color.withOpacity(0.15)),
                    ),
                    child: Text(
                      _lockLabels[i],
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : color.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.04)
            ]),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _toggleTile(IconData icon, String title, String subtitle, bool value,
      Color color, ValueChanged<bool>? onChanged) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF161B22),
        border: Border.all(color: color.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(colors: [
                color.withOpacity(0.2),
                color.withOpacity(0.05)
              ]),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.25),
                        fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              if (onChanged != null) onChanged(v);
            },
            activeThumbColor: color,
            activeTrackColor: color.withOpacity(0.3),
            inactiveThumbColor: Colors.white.withOpacity(0.4),
            inactiveTrackColor: Colors.white.withOpacity(0.06),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, Color color,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF161B22),
          border: Border.all(color: color.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.05)
                ]),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.2), size: 20),
          ],
        ),
      ),
    );
  }
}