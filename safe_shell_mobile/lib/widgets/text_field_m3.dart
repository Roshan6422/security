import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextFieldM3 extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;

  const TextFieldM3({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
  });

  @override
  State<TextFieldM3> createState() => _TextFieldM3State();
}

class _TextFieldM3State extends State<TextFieldM3> {
  late final FocusNode _focusNode;
  bool _focused = false;
  bool _obscureNow = false;

  @override
  void initState() {
    super.initState();
    _obscureNow = widget.obscure;
    _focusNode = FocusNode()
      ..addListener(() {
        if (_focused != _focusNode.hasFocus) {
          setState(() => _focused = _focusNode.hasFocus);
          if (_focusNode.hasFocus) {
            HapticFeedback.selectionClick();
          }
        }
      });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: cs.surface.withOpacity(0.72),
        border: Border.all(
          color: _focused
              ? cs.primary.withOpacity(0.55)
              : cs.onSurface.withOpacity(0.12),
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  blurRadius: 22,
                  spreadRadius: 1,
                  color: cs.primary.withOpacity(0.16),
                ),
              ]
            : [
                BoxShadow(
                  blurRadius: 16,
                  spreadRadius: 1,
                  color: Colors.black.withOpacity(0.05),
                ),
              ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: _obscureNow,
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        cursorColor: cs.primary,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: _focused ? cs.primary : cs.onSurface.withOpacity(0.72),
          ),
          floatingLabelStyle: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w800,
          ),
          prefixIcon: Icon(
            widget.icon,
            color: _focused ? cs.primary : cs.onSurface.withOpacity(0.78),
          ),
          suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(
                    _obscureNow
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: cs.onSurface.withOpacity(0.78),
                  ),
                  onPressed: () {
                    setState(() => _obscureNow = !_obscureNow);
                    HapticFeedback.lightImpact();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
