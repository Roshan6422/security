import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

import '../../security/key_manager.dart';
import '../main_shell.dart';

class KeySetupScreen extends StatefulWidget {
  const KeySetupScreen({super.key});

  @override
  State<KeySetupScreen> createState() => _KeySetupScreenState();
}

class _KeySetupScreenState extends State<KeySetupScreen>
    with SingleTickerProviderStateMixin {
  final _km = KeyManager();
  final _manual = TextEditingController();
  bool _saving = false;

  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
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
    _manual.dispose();
    super.dispose();
  }

  Future<void> _auto() async {
    setState(() => _saving = true);
    await _km.generateAndStoreKey();
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  Future<void> _manualSave() async {
    try {
      setState(() => _saving = true);
      await _km.storeManualKey(_manual.text.trim());
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Key error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Key Setup',
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
            top: 210,
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
                        const SizedBox(height: 6),
                        Text(
                          'Set up your private key',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This protects your vault. Keep it safe and never share it.',
                          style: TextStyle(color: cs.onSurface.withOpacity(0.72)),
                        ),
                        const SizedBox(height: 16),

                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Option 1',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),

                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _auto,
                                  icon: const Icon(Icons.auto_fix_high),
                                  label: Text(_saving ? 'Working...' : 'Generate Auto Key'),
                                ),
                              ),

                              const SizedBox(height: 18),

                              Text(
                                'Option 2',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),

                              _GlassInput(
                                child: TextField(
                                  controller: _manual,
                                  enabled: !_saving,
                                  style: TextStyle(color: cs.onSurface),
                                  decoration: const InputDecoration(
                                    labelText: 'Enter Manual Key (base64)',
                                    prefixIcon: Icon(Icons.key),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: _saving ? null : _manualSave,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Save Manual Key'),
                                ),
                              ),

                              const SizedBox(height: 6),
                              Text(
                                'Tip: Auto key is recommended for most users.',
                                style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                              ),
                            ],
                          ),
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

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
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

class _GlassInput extends StatelessWidget {
  final Widget child;
  const _GlassInput({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: cs.surface.withOpacity(0.66),
        border: Border.all(color: cs.onSurface.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: child,
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
