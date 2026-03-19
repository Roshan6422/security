import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../main.dart';
import '../utils/sound_effects.dart';

/// A dramatic hold-to-lock panic button.
/// Long press for ~1.5 s to instantly lock the app and navigate to login.
class PanicButton extends StatefulWidget {
  final String? label;
  const PanicButton({super.key, this.label});

  @override
  State<PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<PanicButton> with TickerProviderStateMixin {
  late AnimationController _fillController;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;

  bool _isHolding = false;

  @override
  void initState() {
    super.initState();

    _fillController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fillController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerPanic();
      }
    });
  }

  @override
  void dispose() {
    _fillController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    setState(() => _isHolding = true);
    HapticFeedback.heavyImpact();
    _fillController.forward(from: 0);
    // Haptic pulses during hold
    _hapticPulseLoop();
  }

  void _hapticPulseLoop() async {
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!_isHolding || !mounted) return;
      HapticFeedback.mediumImpact();
    }
  }

  void _onHoldEnd() {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    if (_fillController.value < 1.0) {
      // Not held long enough  reset
      _fillController.reverse();
      _shakeController.forward(from: 0).then((_) => _shakeController.reset());
    }
  }

  void _triggerPanic() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.heavyImpact();
    await SoundEffects.lockApp();

    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _onHoldStart(),
      onLongPressEnd: (_) => _onHoldEnd(),
      onLongPressCancel: _onHoldEnd,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _fillController, _shakeController]),
        builder: (context, child) {
          final shake = math.sin(_shakeController.value * math.pi * 4) * 6;
          return Transform.translate(
            offset: Offset(shake, 0),
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF1A0A0A),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                    width: _isHolding ? 2 : 1,
                  ),
                  boxShadow: _isHolding
                      ? [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.3), blurRadius: 20, spreadRadius: 4)]
                      : [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.08), blurRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Stack(
                    children: [
                      // Fill animation
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _fillController.value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFEF4444).withOpacity(0.4),
                                  const Color(0xFFDC2626).withOpacity(0.3),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Label
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.emergency_rounded,
                              color: _isHolding ? Colors.white : const Color(0xFFEF4444),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.label ?? 'PANIC LOCK',
                                  style: TextStyle(
                                    color: _isHolding ? Colors.white : const Color(0xFFEF4444),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                if (!_isHolding)
                                  Text(
                                    'Hold to instantly lock',
                                    style: TextStyle(
                                      color: const Color(0xFFEF4444).withOpacity(0.5),
                                      fontSize: 10,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                if (_isHolding)
                                  Text(
                                    'Locking ${(_fillController.value * 100).toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

