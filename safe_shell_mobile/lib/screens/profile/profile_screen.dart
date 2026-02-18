import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_text_field.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      await ApiService().put('/auth/profile', {
        'name': _nameController.text,
        'email': _emailController.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
        _fetchProfile();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _storage.deleteAll();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.error.withOpacity(0.9),
        title: const Text('Delete Account?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This action is irreversible. All your data will be lost permanently.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().delete('/auth/delete-account');
        await _logout();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
      }
    }
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied!'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Profile', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _userData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.2),
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        (_userData?['name'] ?? 'U')[0].toUpperCase(),
                        style: AppTextStyles.display.copyWith(fontSize: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recovery Key
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _keyRow('Recovery Key', _userData?['recoveryKey'] ?? 'N/A', Icons.vpn_key),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Edit Form
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Personal Info', style: AppTextStyles.subheading),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Full Name',
                          prefixIcon: Icons.person,
                          controller: _nameController,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Email Address',
                          prefixIcon: Icons.email,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          text: 'Save Changes',
                          onPressed: _updateProfile,
                          isLoading: _isLoading,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Actions
                  GlassCard(
                    padding: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.orange),
                      title: const Text('Logout', style: TextStyle(color: Colors.white)),
                      onTap: _logout,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Dangerous Zone
                  GlassCard(
                    padding: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: const Icon(Icons.delete_forever, color: AppColors.error),
                      title: const Text('Delete Account', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      onTap: _deleteAccount,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _keyRow(String label, String value, IconData icon) {
    return GestureDetector(
      onTap: () => _copyToClipboard(label, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ],
              ),
            ),
            Icon(Icons.copy, color: Colors.white.withOpacity(0.3), size: 16),
          ],
        ),
      ),
    );
  }
}
