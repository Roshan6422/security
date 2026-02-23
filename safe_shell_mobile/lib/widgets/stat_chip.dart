import 'package:flutter/material.dart';

class StatChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const StatChip({
    super.key,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.surface.withOpacity(0.72),
        border: Border.all(color: cs.onSurface.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 1,
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  cs.primary,
                  cs.secondary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 15,
                  spreadRadius: 1,
                  color: cs.primary.withOpacity(0.35),
                ),
              ],
            ),
            child: Icon(icon, size: 14, color: cs.onPrimary),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: -0.2,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
