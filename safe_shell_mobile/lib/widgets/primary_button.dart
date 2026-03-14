import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrimaryButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.width,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = widget.onPressed == null || widget.isLoading;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    blurRadius: 26,
                    spreadRadius: 1,
                    color: cs.primary.withOpacity(0.22),
                  ),
                ],
        ),
        child: FilledButton(
          onPressed: disabled
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  widget.onPressed!();
                },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
          ),
          child: Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shine overlay (blue-glass feel)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.18),
                            Colors.white.withOpacity(0.06),
                            Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.isLoading)
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.text,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (widget.icon != null) ...[
                        const SizedBox(width: 10),
                        Icon(widget.icon, size: 18),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
