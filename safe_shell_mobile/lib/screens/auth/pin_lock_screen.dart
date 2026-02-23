import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final String correctPin;
  const PinLockScreen({super.key, required this.onSuccess, required this.correctPin});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> with TickerProviderStateMixin {
  String _entered = '';
  bool _isError = false;
  late AnimationController _shakeController;
  late AnimationController _fadeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _shakeAnimation = Tween<double>(begin: 0, end: 24).animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
    _fadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onKeyTap(String key) {
    HapticFeedback.lightImpact();
    if (_entered.length >= 4) return;
    setState(() {
      _entered += key;
      _isError = false;
    });
    if (_entered.length == 4) {
      _checkPin();
    }
  }

  void _onDelete() {
    HapticFeedback.selectionClick();
    if (_entered.isNotEmpty) {
      setState(() {
        _entered = _entered.substring(0, _entered.length - 1);
        _isError = false;
      });
    }
  }

  void _checkPin() {
    if (_entered == widget.correctPin) {
      HapticFeedback.heavyImpact();
      widget.onSuccess();
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _isError = true);
      _shakeController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() { _entered = ''; _isError = false; });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A12),
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Shield icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [const Color(0xFFA855F7).withOpacity(0.12), const Color(0xFF8B5CF6).withOpacity(0.05)]),
                  border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.15)),
                ),
                child: const Icon(Icons.lock_rounded, color: Color(0xFFA855F7), size: 32),
              ),
              const SizedBox(height: 24),
              Text('Enter PIN', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                _isError ? 'Wrong PIN, try again' : 'Enter your 4-digit PIN',
                style: TextStyle(color: _isError ? const Color(0xFFEF4444) : Colors.white.withOpacity(0.25), fontSize: 13),
              ),
              const SizedBox(height: 32),
              // PIN dots
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(math.sin(_shakeAnimation.value) * 3, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _entered.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: filled ? 18 : 14,
                      height: filled ? 18 : 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isError
                            ? const Color(0xFFEF4444)
                            : filled
                                ? const Color(0xFFA855F7)
                                : Colors.white.withOpacity(0.08),
                        boxShadow: filled && !_isError
                            ? [BoxShadow(color: const Color(0xFFA855F7).withOpacity(0.4), blurRadius: 8)]
                            : null,
                      ),
                    );
                  }),
                ),
              ),
              const Spacer(flex: 1),
              // Number keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    _buildRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    _buildRow(['', '0', 'DEL']),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox(width: 72, height: 72);
        return _buildKey(key);
      }).toList(),
    );
  }

  Widget _buildKey(String key) {
    final isDelete = key == 'DEL';
    return GestureDetector(
      onTap: isDelete ? _onDelete : () => _onKeyTap(key),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.0),
        duration: const Duration(milliseconds: 100),
        builder: (context, value, child) {
          return Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDelete ? Colors.transparent : const Color(0xFF0D1520),
              border: Border.all(color: isDelete ? Colors.transparent : Colors.white.withOpacity(0.04)),
            ),
            child: Center(
              child: isDelete
                  ? Icon(Icons.backspace_rounded, color: Colors.white.withOpacity(0.4), size: 22)
                  : Text(key, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }
}
