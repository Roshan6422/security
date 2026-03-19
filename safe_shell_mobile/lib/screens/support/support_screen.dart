import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slideUp = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Support',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
              colors: [
                  AppColors.darkBackground,
                  AppColors.darkSurface,
                  AppColors.darkSurface.withOpacity(0.8),
                  AppColors.darkBackground,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Positioned(
            top: -70,
            left: -45,
            child: _GlowBlob(color: cs.primary.withOpacity(0.16), size: 220),
          ),
          Positioned(
            bottom: -90,
            right: -50,
            child: _GlowBlob(color: cs.primary.withOpacity(0.10), size: 260),
          ),
          Positioned(
            top: 200,
            right: -20,
            child: _GlowBlob(color: cs.secondary.withOpacity(0.06), size: 160),
          ),

          SafeArea(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                return Opacity(
                  opacity: _fade.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideUp.value),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      children: [
                        _SupportTile(
                          icon: Icons.chat_rounded,
                          title: 'Live Chat',
                          subtitle: 'Connect via WhatsApp',
                          onTap: () => _launch('https://wa.me/94XXXXXXXXX?text=Hi%20SafeShell%20Support'),
                        ),
                        const SizedBox(height: 10),
                        _SupportTile(
                          icon: Icons.email_rounded,
                          title: 'Email Support',
                          subtitle: 'support@safeshell.app',
                          onTap: () => _launch('mailto:support@safeshell.app?subject=SafeShell%20Support%20Request'),
                        ),
                        const SizedBox(height: 10),
                        _SupportTile(
                          icon: Icons.help_center_rounded,
                          title: 'Help Center',
                          subtitle: 'FAQs & guides',
                          onTap: () => _launch('https://safeshell.app/help'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: 74,
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                cs.primary.withOpacity(0.92),
                cs.primary.withOpacity(0.62),
              ],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                spreadRadius: 1,
                color: cs.primary.withOpacity(0.12),
              ),
            ],
          ),
          child: Icon(icon, color: cs.onPrimary),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: cs.onSurface.withOpacity(0.3),
        ),
      ),
    );
  }
}


class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: cs.surface.withOpacity(0.78),
            border: Border.all(color: cs.onSurface.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                blurRadius: 30,
                spreadRadius: 2,
                color: Colors.black.withOpacity(0.10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}
