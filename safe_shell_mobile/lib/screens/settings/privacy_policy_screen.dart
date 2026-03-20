import 'package:flutter/material.dart';
import '../../core/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text('Privacy Policy', 
          style: AppTextStyles.heading.copyWith(color: Colors.white)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: AppTextStyles.display.copyWith(
                color: Colors.white, 
                fontSize: 28, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 24),
            _section('1. Data Collection', 'We do not collect personal data. Your photos and videos are encrypted and stored on your device or your private cloud storage.'),
            _section('2. Permissions', 'We request access to your camera and gallery solely to allow you to encrypt and secure your media.'),
            _section('3. Background Activity', 'To ensure your files remain protected at all times, this app may run a background service. This service does not collect data; it simply maintains the security of your vault.'),
            _section('4. Security', 'Your data is protected with industry-standard encryption. We cannot access your vault content.'),
            _section('5. Third Parties', 'We do not share your data with any third-party services.'),
            const SizedBox(height: 32),
            Text(
              'Contact Us',
              style: AppTextStyles.subheading.copyWith(
                color: Colors.white, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'If you have any questions, please contact support@safeshell.io',
              style: AppTextStyles.body.copyWith(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, 
            style: AppTextStyles.subheading.copyWith(
              color: AppColors.primary, 
              fontSize: 18, 
              fontWeight: FontWeight.bold
            )
          ),
          const SizedBox(height: 10),
          Text(content, 
            style: AppTextStyles.body.copyWith(
              color: Colors.white.withOpacity(0.8), 
              fontSize: 15, 
              height: 1.6
            )
          ),
        ],
      ),
    );
  }
}
