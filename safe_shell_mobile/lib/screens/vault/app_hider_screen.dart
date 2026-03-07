import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/app_hider_service.dart';
import '../../widgets/premium_snackbar.dart';

class AppHiderScreen extends StatefulWidget {
  const AppHiderScreen({super.key});

  @override
  State<AppHiderScreen> createState() => _AppHiderScreenState();
}

class _AppHiderScreenState extends State<AppHiderScreen> {
  final _service = AppHiderService();
  List<SystemApp> _hiddenApps = [];
  bool _isLoading = true;
  bool _hasUsagePermission = false;
  bool _hasOverlayPermission = false;
  bool _isMiui = false;
  bool _isServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _loadInitData();
  }

  Future<void> _loadInitData() async {
    await _loadHiddenApps();
    final hasUsage = await _service.checkUsagePermission();
    final hasOverlay = await _service.checkOverlayPermission();
    final isMiui = await _service.isMiui();
    final isServiceRunning = await _service.checkServiceStatus();
    setState(() {
      _hasUsagePermission = hasUsage;
      _hasOverlayPermission = hasOverlay;
      _isMiui = isMiui;
      _isServiceRunning = isServiceRunning;
    });
    
    // Sync initial locked list to native if usage permission is granted
    // We don't wait for overlay here because MIUI reports it inconsistently,
    // and the service can still monitor even if it can't show the overlay yet.
    if (hasUsage) {
      _syncLockedApps();
    }
  }

  void _syncLockedApps() {
    final lockedPackages = _hiddenApps
        .where((app) => app.isLocked)
        .map((app) => app.packageName)
        .toList();
    _service.setLockedApps(lockedPackages);
  }

  Future<void> _loadHiddenApps() async {
    setState(() => _isLoading = true);
    final apps = await _service.getHiddenApps();
    setState(() {
      _hiddenApps = apps;
      _isLoading = false;
    });
  }

  Future<void> _addApp() async {
    setState(() => _isLoading = true);
    final allApps = await _service.getInstalledApps();
    setState(() => _isLoading = false);

    if (!mounted) return;

    final isLight = Theme.of(context).brightness == Brightness.light;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isLight ? AppColors.background : AppColors.darkBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: isLight ? Colors.black12 : Colors.white12, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Protect App', style: AppTextStyles.subheading.copyWith(fontSize: 20, fontWeight: FontWeight.w800, color: isLight ? AppColors.textPrimary : Colors.white)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: allApps.length,
                itemBuilder: (context, index) {
                  final app = allApps[index];
                  final isAlreadyAdded = _hiddenApps.any((e) => e.packageName == app.packageName);

                  return ListTile(
                    leading: app.iconBase64.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(base64Decode(app.iconBase64), width: 40, height: 40),
                          )
                        : const Icon(Icons.android, color: Colors.grey),
                    title: Text(app.name, style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text(app.packageName, style: TextStyle(color: isLight ? AppColors.textSecondary : Colors.white38, fontSize: 11)),
                    trailing: isAlreadyAdded
                        ? const Icon(Icons.check_circle, color: Color(0xFF34D399))
                        : Icon(Icons.add_circle_outline, color: AppColors.primary.withOpacity(0.5)),
                    onTap: isAlreadyAdded
                        ? null
                          : () async {
                            final newApp = SystemApp(
                              name: app.name,
                              packageName: app.packageName,
                              iconBase64: app.iconBase64,
                              isLocked: false,
                              isHidden: false,
                            );
                            setState(() {
                              _hiddenApps.add(newApp);
                            });
                            _service.saveHiddenApps(_hiddenApps);
                            
                            if (mounted) {
                              Navigator.pop(ctx);
                              PremiumSnackbar.show(context, message: '${app.name} protected successfully', emoji: '', color: const Color(0xFF34D399));
                            }
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchApp(SystemApp app) async {
    HapticFeedback.lightImpact();
    final success = await _service.launchApp(app.packageName);
    if (!success && mounted) {
      PremiumSnackbar.show(context, message: 'Could not launch ${app.name}', emoji: '', color: Colors.redAccent);
    }
  }

  Future<void> _removeApp(SystemApp app) async {
    // Unhide the app first if it was hidden from launcher
    if (app.isHidden) {
      await _service.unhideApp(app.packageName);
    }
    setState(() {
      _hiddenApps.removeWhere((e) => e.packageName == app.packageName);
    });
    _service.saveHiddenApps(_hiddenApps);
    _syncLockedApps();
    
    if (mounted) {
      PremiumSnackbar.show(context, message: '${app.name} removed & restored', emoji: '', color: Colors.orangeAccent);
    }
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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isLight ? AppColors.textPrimary : Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('App Lock', style: AppTextStyles.heading.copyWith(fontSize: 20, color: isLight ? AppColors.textPrimary : Colors.white)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _hiddenApps.isEmpty
              ? _buildEmptyState(isLight)
              : Column(
                  children: [
                    _buildUsagePermissionStatus(),
                    Expanded(child: _buildAppGrid(isLight)),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addApp,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, color: Colors.black, size: 30),
      ),
    );
  }

  Widget _buildUsagePermissionStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Column(
        children: [
          // Usage Stats Permission
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _hasUsagePermission ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _hasUsagePermission ? Colors.blue.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hasUsagePermission ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: _hasUsagePermission ? Colors.blueAccent : Colors.orangeAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _hasUsagePermission ? 'UNIVERSAL LOCK: ACTIVE' : 'UNIVERSAL LOCK: PERMISSION NEEDED',
                  style: TextStyle(
                    color: _hasUsagePermission ? Colors.blueAccent : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (!_hasUsagePermission) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      await _service.requestUsagePermission();
                      Future.delayed(const Duration(seconds: 2), () async {
                        final hasUsage = await _service.checkUsagePermission();
                        if (mounted) setState(() => _hasUsagePermission = hasUsage);
                      });
                    },
                    child: const Text('GRANT', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, decoration: TextDecoration.underline)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Service Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isServiceRunning ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isServiceRunning ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isServiceRunning ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: _isServiceRunning ? Colors.greenAccent : Colors.redAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _isServiceRunning ? 'PROTECTION SERVICE: RUNNING' : 'PROTECTION SERVICE: NOT RUNNING',
                  style: TextStyle(
                    color: _isServiceRunning ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (!_isServiceRunning && _hasUsagePermission) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      // Attempt to restart by syncing apps
                      final locked = _hiddenApps.where((a) => a.isLocked).map((a) => a.packageName).toList();
                      await _service.setLockedApps(locked);
                      Future.delayed(const Duration(seconds: 1), () async {
                        final status = await _service.checkServiceStatus();
                        if (mounted) setState(() => _isServiceRunning = status);
                      });
                    },
                    child: const Text('RESTART', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900, decoration: TextDecoration.underline)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Overlay Permission
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _hasOverlayPermission ? Colors.purple.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _hasOverlayPermission ? Colors.purple.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hasOverlayPermission ? Icons.layers_rounded : Icons.layers_outlined,
                  color: _hasOverlayPermission ? Colors.purpleAccent : Colors.orangeAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _hasOverlayPermission ? 'OVERLAY: ACTIVE' : 'OVERLAY: PERMISSION NEEDED',
                  style: TextStyle(
                    color: _hasOverlayPermission ? Colors.purpleAccent : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (!_hasOverlayPermission) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      await _service.requestOverlayPermission();
                      Future.delayed(const Duration(seconds: 2), () async {
                        final hasOverlay = await _service.checkOverlayPermission();
                        if (mounted) setState(() => _hasOverlayPermission = hasOverlay);
                      });
                    },
                    child: const Text('GRANT', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, decoration: TextDecoration.underline)),
                  ),
                ],
              ],
            ),
          ),
          
          // MIUI Tip Header  Only show if it's a MI device or overlay is missing
          if (_isMiui || !_hasOverlayPermission) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Text('MIUI / REDMI DEVICE TIP', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Xiaomi devices block App Lock by default. You MUST enable this:',
                    style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  _buildMIUITip('Settings > Apps > Manage Apps > SafeShell'),
                  _buildMIUITip('Other permissions > Display pop-up windows while running in background > ALWAYS ALLOW'),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => openAppSettings(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('OPEN APP SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMIUITip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(' ', style: TextStyle(color: AppColors.primary, fontSize: 9)),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 9))),
        ],
      ),
    );
  }


  Widget _buildEmptyState(bool isLight) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: Icon(Icons.lock_person_rounded, size: 64, color: AppColors.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            'No Apps Protected',
            style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Add apps to lock them with a PIN or hide them completely from the device launcher.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isLight ? AppColors.textSecondary : Colors.white38, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleHideApp(SystemApp app) async {
    HapticFeedback.lightImpact();
    if (app.isHidden) {
      // Unhide
      final success = await _service.unhideApp(app.packageName);
      if (success) {
        setState(() => app.isHidden = false);
        _service.saveHiddenApps(_hiddenApps);
        if (mounted) {
          PremiumSnackbar.show(context, message: '${app.name} is now visible in launcher', emoji: '', color: Colors.blueAccent);
        }
      } else {
        if (mounted) {
          PremiumSnackbar.show(context, message: 'Failed to unhide ${app.name}', emoji: '', color: Colors.redAccent);
        }
      }
    } else {
      // Hide
      final success = await _service.hideApp(app.packageName);
      if (success) {
        setState(() => app.isHidden = true);
        _service.saveHiddenApps(_hiddenApps);
        if (mounted) {
          PremiumSnackbar.show(context, message: '${app.name} hidden from launcher', emoji: '', color: const Color(0xFF34D399));
        }
      } else {
        if (mounted) {
          PremiumSnackbar.show(context, message: 'Failed to hide ${app.name}', emoji: '', color: Colors.redAccent);
        }
      }
    }
  }

  String _getStatusLabel(SystemApp app) {
    if (app.isHidden && app.isLocked) return 'HIDDEN + LOCKED';
    if (app.isHidden) return 'HIDDEN';
    if (app.isLocked) return 'LOCKED';
    return 'PROTECTED';
  }

  Color _getStatusColor(SystemApp app, bool isLight) {
    if (app.isHidden) return const Color(0xFFF59E0B);
    if (app.isLocked) return AppColors.primary;
    return isLight ? Colors.grey : Colors.white.withOpacity(0.5);
  }

  Widget _buildAppGrid(bool isLight) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.75,
      ),
      itemCount: _hiddenApps.length,
      itemBuilder: (context, index) {
        final app = _hiddenApps[index];
        final statusColor = _getStatusColor(app, isLight);
        return GestureDetector(
          onTap: () => _launchApp(app),
          onLongPress: () {
            HapticFeedback.heavyImpact();
            _showDeleteConfirm(app);
          },
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isLight ? Colors.white : const Color(0xFF1A1F26),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isLight ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))] : [],
                    border: Border.all(
                      color: app.isHidden
                          ? const Color(0xFFF59E0B).withOpacity(0.3)
                          : isLight ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            app.iconBase64.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Opacity(
                                      opacity: app.isHidden ? 0.5 : 1.0,
                                      child: Image.memory(base64Decode(app.iconBase64), width: 44, height: 44),
                                    ),
                                  )
                                : const Icon(Icons.android, color: Colors.grey, size: 32),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withOpacity(0.2)),
                              ),
                              child: Text(
                                _getStatusLabel(app),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Lock toggle  top right
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              app.isLocked = !app.isLocked;
                            });
                            _service.saveHiddenApps(_hiddenApps);
                            _syncLockedApps();
                          },
                          child: Icon(
                            app.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                            color: app.isLocked ? AppColors.primary : (isLight ? Colors.grey.withOpacity(0.3) : Colors.white.withOpacity(0.2)),
                            size: 15,
                          ),
                        ),
                      ),
                      // Hide toggle  top left
                      Positioned(
                        top: 6,
                        left: 6,
                        child: GestureDetector(
                          onTap: () => _toggleHideApp(app),
                          child: Icon(
                            app.isHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: app.isHidden ? const Color(0xFFF59E0B) : (isLight ? Colors.grey.withOpacity(0.3) : Colors.white.withOpacity(0.2)),
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: isLight ? AppColors.textPrimary : Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(SystemApp app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1A1F26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove ${app.name} from list?', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? AppColors.textPrimary : Colors.white, fontWeight: FontWeight.w700)),
        content: Text('This will stop protecting ${app.name}. It will not uninstall the app from your device.', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? AppColors.textSecondary : Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _removeApp(app);
              Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}


