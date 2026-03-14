import 'package:flutter/material.dart';

/// Premium animated snackbar that slides in from top with blur and gradient
class PremiumSnackbar {
  static void show(BuildContext context, {
    required String message,
    String? emoji,
    Color color = const Color(0xFF4DA3FF),
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _AnimatedSnackbar(
        message: message,
        emoji: emoji,
        color: color,
        onDismiss: () => entry.remove(),
        duration: duration,
      ),
    );

    overlay.insert(entry);
  }
}

class _AnimatedSnackbar extends StatefulWidget {
  final String message;
  final String? emoji;
  final Color color;
  final VoidCallback onDismiss;
  final Duration duration;

  const _AnimatedSnackbar({required this.message, this.emoji, required this.color, required this.onDismiss, required this.duration});

  @override
  State<_AnimatedSnackbar> createState() => _AnimatedSnackbarState();
}

class _AnimatedSnackbarState extends State<_AnimatedSnackbar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [widget.color.withOpacity(0.15), widget.color.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.color.withOpacity(0.15)),
              boxShadow: [BoxShadow(color: widget.color.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                if (widget.emoji != null) ...[
                  Text(widget.emoji!, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
