import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_card.dart';

class DeviceManagerScreen extends StatefulWidget {
  const DeviceManagerScreen({super.key});

  @override
  State<DeviceManagerScreen> createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends State<DeviceManagerScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _devices = [];
  int _totalDevices = 0;
  int _trustedCount = 0;
  int _untrustedCount = 0;
  bool _isLoading = true;
  String? _currentModel;

  @override
  void initState() {
    super.initState();
    _registerAndFetchDevices();
  }

  Future<void> _registerAndFetchDevices() async {
    try {
      // Get current device info
      final deviceInfo = DeviceInfoPlugin();
      String deviceName = 'Unknown';
      String model = '';
      String os = '';
      String platform = 'android';

      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        deviceName = '${android.brand} ${android.model}';
        model = android.model;
        os = 'Android ${android.version.release} (API ${android.version.sdkInt})';
        platform = 'android';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        deviceName = ios.name;
        model = ios.model;
        os = '${ios.systemName} ${ios.systemVersion}';
        platform = 'ios';
      }

      _currentModel = model;

      // Register this device
      await _api.post('/device/register', {
        'deviceName': deviceName,
        'model': model,
        'os': os,
        'platform': platform,
      });

      // Fetch all devices
      await _fetchDevices();
    } catch (e) {
      debugPrint('Device registration error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchDevices() async {
    try {
      final response = await _api.get('/device/list');
      if (mounted && response != null) {
        setState(() {
          _devices = List<Map<String, dynamic>>.from(response['devices'] ?? []);
          _totalDevices = response['total'] ?? 0;
          _trustedCount = response['trusted'] ?? 0;
          _untrustedCount = response['untrusted'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch devices error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTrust(String deviceId, bool currentTrust) async {
    try {
      await _api.put('/device/$deviceId/trust', {'trusted': !currentTrust});
      await _fetchDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(currentTrust ? 'Device marked untrusted' : 'Device marked trusted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _removeDevice(String deviceId) async {
    try {
      await _api.delete('/device/$deviceId');
      await _fetchDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showDeviceDetails(Map<String, dynamic> device) {
    final isCurrentDevice = device['model'] == _currentModel;
    final isTrusted = device['isTrusted'] as bool? ?? true;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2332),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.phone_android, color: Colors.white70, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    device['deviceName'] ?? 'Unknown',
                    style: AppTextStyles.subheading.copyWith(fontSize: 18),
                  ),
                ),
                Icon(Icons.edit, color: Colors.white.withValues(alpha: 0.3), size: 20),
              ],
            ),
            const SizedBox(height: 24),
            _detailRow('Device Name', device['deviceName'] ?? ''),
            _detailRow('Model', device['model'] ?? ''),
            _detailRow('OS', device['os'] ?? ''),
            _detailRow('Platform', device['platform'] ?? ''),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _toggleTrust(device['id'], isTrusted);
                },
                icon: Icon(
                  isTrusted ? Icons.gpp_bad : Icons.verified_user,
                  color: isTrusted ? Colors.orange : Colors.green,
                ),
                label: Text(
                  isTrusted ? 'Mark Untrusted' : 'Mark Trusted',
                  style: TextStyle(
                    color: isTrusted ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isTrusted ? Colors.orange : Colors.green).withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.body.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background gradient
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : Column(
                    children: [
                      // App Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.arrow_back, color: Colors.white),
                            ),
                            const Expanded(
                              child: Text(
                                'Device Manager',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                          ],
                        ),
                      ),

                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            // Summary Card
                            GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.devices, color: AppColors.primary, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$_totalDevices device${_totalDevices != 1 ? 's' : ''} registered',
                                        style: AppTextStyles.subheading.copyWith(fontSize: 16),
                                      ),
                                      Text(
                                        '$_trustedCount trusted  $_untrustedCount untrusted',
                                        style: AppTextStyles.caption.copyWith(color: Colors.white38),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Device Cards
                            ..._devices.map((device) {
                              final isCurrentDevice = device['model'] == _currentModel;
                              final isTrusted = device['isTrusted'] as bool? ?? true;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_android, color: Colors.white54, size: 22),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        device['deviceName'] ?? 'Unknown',
                                                        style: AppTextStyles.subheading.copyWith(fontSize: 15),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (isCurrentDevice) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.primary.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                                        ),
                                                        child: Text(
                                                          'This device',
                                                          style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${device['model'] ?? ''}',
                                                  style: AppTextStyles.caption.copyWith(color: Colors.white30, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8, height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isCurrentDevice ? Colors.green : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isCurrentDevice ? 'Online  Active now' : 'Offline',
                                            style: TextStyle(color: isCurrentDevice ? Colors.white54 : Colors.white30, fontSize: 12),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            isTrusted ? Icons.verified : Icons.gpp_bad,
                                            color: isTrusted ? Colors.green : Colors.orange,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isTrusted ? 'Trusted' : 'Untrusted',
                                            style: TextStyle(
                                              color: isTrusted ? Colors.green : Colors.orange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      GestureDetector(
                                        onTap: () => _showDeviceDetails(device),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Details',
                                            style: AppTextStyles.body.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: 16),
                            // Warning info
                            GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.white.withValues(alpha: 0.3), size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Remove any device you don't recognise immediately.\nUnknown devices may indicate unauthorised access.",
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

