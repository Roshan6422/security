import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with SingleTickerProviderStateMixin {
  String _display = '0';
  String _equation = '';
  String _pendingOperator = '';
  final List<String> _history = [];
  bool _showHistory = false;
  bool _hasError = false;
  bool _resultDisplayed = false;
  String? _stealthPin;

  late final AnimationController _historyAnimController;
  late final Animation<double> _historySlideAnimation;

  // --- Lifecycle -------------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchStealthPin();

    _historyAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _historySlideAnimation = CurvedAnimation(
      parent: _historyAnimController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _historyAnimController.dispose();
    super.dispose();
  }

  // --- Stealth Pin ----------------------------------------

  Future<void> _fetchStealthPin() async {
    const storage = FlutterSecureStorage();

    try {
      final savedPin = await storage.read(key: 'calculator_pin');

      if (savedPin != null && savedPin.isNotEmpty) {
        if (mounted) setState(() => _stealthPin = savedPin);
        return;
      }
    } catch (_) {
      // Secure storage read failed, continue to API fallback
    }

    try {
      final response = await ApiService().get('/auth/me');
      if (response != null && response['calculatorPassword'] != null) {
        final pin = response['calculatorPassword'].toString();
        if (pin.isNotEmpty) {
          if (mounted) setState(() => _stealthPin = pin);
          await storage.write(key: 'calculator_pin', value: pin);
        }
      }
    } catch (_) {
      // Offline and no cached pin — fallback handled in _checkStealthTrigger
    }
  }

  bool _checkStealthTrigger() {
    final targetPin = _stealthPin ?? '112233';

    if (_display == targetPin) {
      // Clear display before navigating so it's not visible on transition
      setState(() {
        _display = '0';
        _equation = '';
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return true;
    }
    return false;
  }

  // --- Input Handlers -------------------------------------

  void _handleNumber(String num) {
    HapticFeedback.lightImpact();

    setState(() {
      // Clear error state on any new input
      if (_hasError) {
        _display = '0';
        _equation = '';
        _hasError = false;
      }

      // Start fresh number after result was displayed
      if (_resultDisplayed) {
        if (_pendingOperator.isEmpty) {
          // No operator queued — start entirely new calculation
          _equation = '';
        }
        _resultDisplayed = false;
      }

      // Prevent multiple decimal points
      if (num == '.' && _display.contains('.')) return;

      // Prevent leading zeros (but allow "0.")
      if (_display == '0' && num != '.') {
        _display = num;
      } else {
        _display += num;
      }
    });

    // AUTO UNLOCK: Check trigger as soon as number is typed
    _checkStealthTrigger();
  }

  void _handleOperator(String displayOp) {
    HapticFeedback.lightImpact();

    setState(() {
      if (_hasError) {
        _hasError = false;
        _display = '0';
        _equation = '';
      }

      // If there's a pending operation, calculate intermediate result first
      if (_pendingOperator.isNotEmpty && !_resultDisplayed) {
        _evaluateIntermediate();
      }

      _equation = '$_display $displayOp ';
      _pendingOperator = displayOp;
      _resultDisplayed = true; // Next number input starts fresh
    });
  }

  void _handleEquals() {
    HapticFeedback.lightImpact();

    // Check stealth trigger BEFORE any calculation
    if (_checkStealthTrigger()) return;

    if (_equation.isEmpty || _pendingOperator.isEmpty) return;

    _evaluateAndFinalize();
  }

  void _handleClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _display = '0';
      _equation = '';
      _pendingOperator = '';
      _hasError = false;
      _resultDisplayed = false;
    });
  }

  void _handleBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_hasError) {
        _display = '0';
        _hasError = false;
        return;
      }
      _display = _display.length > 1
          ? _display.substring(0, _display.length - 1)
          : '0';
    });
  }

  void _handlePercentage() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_hasError) return;

      try {
        final value = double.parse(_display);
        final result = value / 100;
        _display = _formatResult(result);
      } catch (_) {
        _display = 'Error';
        _hasError = true;
      }
    });
  }

  // --- Calculation Engine ---------------------------------

  void _evaluateIntermediate() {
    try {
      final fullEquation = _equation + _display;
      final result = _evaluate(fullEquation);
      _display = _formatResult(result);
    } catch (_) {
      _display = 'Error';
      _hasError = true;
      _equation = '';
      _pendingOperator = '';
    }
  }

  void _evaluateAndFinalize() {
    try {
      final fullEquation = _equation + _display;
      final result = _evaluate(fullEquation);
      final resultStr = _formatResult(result);

      // Build display equation with proper symbols
      final displayEquation = fullEquation;

      setState(() {
        _history.insert(0, '$displayEquation = $resultStr');
        if (_history.length > 50) _history.removeLast();
        _display = resultStr;
        _equation = '';
        _pendingOperator = '';
        _resultDisplayed = true;
      });
    } catch (_) {
      setState(() {
        _display = 'Error';
        _hasError = true;
        _equation = '';
        _pendingOperator = '';
      });
    }
  }

  double _evaluate(String expression) {
    // Convert display operators to math operators
    final mathExpr = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(' ', '');

    // Check for division by zero
    if (mathExpr.contains('/0') && !mathExpr.contains('/0.')) {
      // More precise check
      final parts = mathExpr.split('/');
      if (parts.length == 2 && double.tryParse(parts[1]) == 0) {
        throw ArgumentError('Division by zero');
      }
    }

    final parser = Parser();
    final exp = parser.parse(mathExpr);
    final contextModel = ContextModel();
    final result = exp.evaluate(EvaluationType.REAL, contextModel) as double;

    if (result.isInfinite || result.isNaN) {
      throw ArgumentError('Invalid result');
    }

    return result;
  }

  String _formatResult(double value) {
    if (value == value.truncateToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }

    // For very large or very small numbers, use scientific notation
    if (value.abs() >= 1e15 || (value.abs() < 1e-10 && value != 0)) {
      return value.toStringAsPrecision(8);
    }

    return value
        .toStringAsFixed(10)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  // --- History Toggle -------------------------------------

  void _toggleHistory() {
    setState(() => _showHistory = !_showHistory);
    if (_showHistory) {
      _historyAnimController.forward();
    } else {
      _historyAnimController.reverse();
    }
  }

  // --- Build ----------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            _buildDisplay(),
            if (_showHistory) _buildHistoryDrawer(),
            _buildKeypad(bottomPadding),
          ],
        ),
      ),
    );
  }

  // --- Top Bar --------------------------------------------

  Widget _buildTopBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: const Color(0xFF11161D).withOpacity(0.5),
          child: Row(
            children: [
              const Spacer(),
              _topBarButton(
                _showHistory ? Icons.calculate : Icons.history,
                _toggleHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBarButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.6), size: 20),
      ),
    );
  }

  // --- Display --------------------------------------------

  Widget _buildDisplay() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.bottomRight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_equation.isNotEmpty)
              AnimatedOpacity(
                opacity: _equation.isNotEmpty ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _equation,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _display,
                style: TextStyle(
                  color: _hasError
                      ? const Color(0xFFFF453A)
                      : Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- History Drawer -------------------------------------

  Widget _buildHistoryDrawer() {
    return SizeTransition(
      sizeFactor: _historySlideAnimation,
      axisAlignment: -1.0,
      child: Container(
        height: 200,
        decoration: const BoxDecoration(
          color: Color(0xFF11161D),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HISTORY',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _history.clear()),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _history.isEmpty
                  ? Center(
                      child: Text(
                        'No history yet',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _history.length,
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              // Tap history item to load result
                              final parts = _history[index].split(' = ');
                              if (parts.length == 2) {
                                setState(() {
                                  _display = parts[1];
                                  _equation = '';
                                  _pendingOperator = '';
                                  _resultDisplayed = true;
                                  _showHistory = false;
                                });
                                _historyAnimController.reverse();
                              }
                            },
                            child: Text(
                              _history[index],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Keypad ---------------------------------------------

  Widget _buildKeypad(double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF11161D),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            offset: const Offset(0, -20),
            blurRadius: 40,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _keyRow([
            _key('AC', type: 'special', onTap: _handleClear),
            _key('?', type: 'special', onTap: _handleBackspace),
            _key('%', type: 'special', onTap: _handlePercentage),
            _key('÷', type: 'operator', onTap: () => _handleOperator('÷')),
          ]),
          const SizedBox(height: 12),
          _keyRow([
            _key('7', onTap: () => _handleNumber('7')),
            _key('8', onTap: () => _handleNumber('8')),
            _key('9', onTap: () => _handleNumber('9')),
            _key('×', type: 'operator', onTap: () => _handleOperator('×')),
          ]),
          const SizedBox(height: 12),
          _keyRow([
            _key('4', onTap: () => _handleNumber('4')),
            _key('5', onTap: () => _handleNumber('5')),
            _key('6', onTap: () => _handleNumber('6')),
            _key('-', type: 'operator', onTap: () => _handleOperator('-')),
          ]),
          const SizedBox(height: 12),
          _keyRow([
            _key('1', onTap: () => _handleNumber('1')),
            _key('2', onTap: () => _handleNumber('2')),
            _key('3', onTap: () => _handleNumber('3')),
            _key('+', type: 'operator', onTap: () => _handleOperator('+')),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _key('0', onTap: () => _handleNumber('0')),
              ),
              const SizedBox(width: 12),
              Expanded(child: _key('.', onTap: () => _handleNumber('.'))),
              const SizedBox(width: 12),
              Expanded(child: _key('=', type: 'action', onTap: _handleEquals)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyRow(List<Widget> keys) {
    final List<Widget> children = [];
    for (int i = 0; i < keys.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 12));
      children.add(Expanded(child: keys[i]));
    }
    return Row(children: children);
  }

  Widget _key(String char, {String type = 'number', required VoidCallback onTap}) {
    Color bg;
    Color textColor;
    Gradient? gradient;

    switch (type) {
      case 'operator':
        bg = const Color(0xFFFF9500);
        textColor = Colors.white;
        break;
      case 'special':
        bg = const Color(0xFFA5A5A5);
        textColor = Colors.black;
        break;
      case 'action':
        bg = AppColors.primary;
        textColor = Colors.white;
        gradient = const LinearGradient(
          colors: [AppColors.primary, Color(0xFF7C3AED)],
        );
        break;
      default:
        bg = const Color(0xFF333333);
        textColor = Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 70,
        decoration: BoxDecoration(
          color: gradient == null ? bg : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(35),
        ),
        alignment: Alignment.center,
        child: Text(
          char,
          style: TextStyle(
            color: textColor,
            fontSize: 28,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}