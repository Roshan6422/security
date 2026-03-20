import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? AppColors.textPrimary : Colors.white;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Support', style: AppTextStyles.heading.copyWith(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How can we help?', style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            )),
            const SizedBox(height: 16),
            Text(
              'If you have questions about your account, security, or subscription, our team is here to assist you.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 40),
            _buildSupportOption(
              context,
              icon: Icons.email_rounded,
              title: 'Email Us',
              subtitle: 'support@safeshell.io',
              onTap: () => _launchEmail(),
            ),
            const SizedBox(height: 16),
            _buildSupportOption(
              context,
              icon: Icons.help_center_rounded,
              title: 'Help Center',
              subtitle: 'Frequently asked questions',
              onTap: () => _launchUrl('https://safeshell.io/help'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportOption(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isLight ? Colors.white : Colors.white.withOpacity(0.05),
          border: Border.all(color: isLight ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.subheading.copyWith(color: isLight ? AppColors.textPrimary : Colors.white)),
                  Text(subtitle, style: AppTextStyles.caption.copyWith(color: isLight ? AppColors.textSecondary : Colors.white54)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isLight ? AppColors.textTertiary : Colors.white24),
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@safeshell.io',
      query: 'subject=SafeShell Support Request',
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
