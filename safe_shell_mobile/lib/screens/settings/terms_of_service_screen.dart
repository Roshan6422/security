import 'package:flutter/material.dart';
import '../../core/theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Terms of Service', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms of Service',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text('Last Updated: March 2026', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
            const SizedBox(height: 24),
            _section('1. Acceptance of Terms', 'By using SafeShell, you agree to these terms. If you do not agree, please do not use the application.'),
            _section('2. Privacy & Encryption', 'SafeShell is a privacy-first application. We use AES-256 encryption. You are responsible for maintaining your recovery key. If you lose your key and your password, we cannot recover your data.'),
            _section('3. User Conduct', 'You agree not to use SafeShell for any illegal activities. We do not monitor your content, but we comply with legal requests regarding account metadata where required by law.'),
            _section('4. Pro Subscription', 'Subscriptions are managed via Google Play. Cancellations must be made through your Google account settings.'),
            _section('5. Disclaimer', 'SafeShell is provided "as is". While we strive for 100% security, we cannot guarantee absolute protection against all possible threats.'),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© 2026 SafeShell Global Security',
                style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11),
              ),
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
            style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          Text(content, 
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.5)
          ),
        ],
      ),
    );
  }
}
