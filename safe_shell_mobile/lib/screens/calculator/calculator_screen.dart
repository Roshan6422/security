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

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _equation = '';
  final List<String> _history = [];
  bool _showHistory = false;
  String? _stealthPin;

  @override
  void initState() {
    super.initState();
    _fetchStealthPin();
  }

  Future<void> _fetchStealthPin() async {
    // Check local storage first (OFFLINE SUPPORT)
    const storage = FlutterSecureStorage();
    final savedPin = await storage.read(key: 'calculator_pin');
    
    if (savedPin != null) {
      if (mounted) setState(() => _stealthPin = savedPin);
      return;
    }

    // Fallback: Try fetching from API if online (and save it)
    try {
      final response = await ApiService().get('/auth/me');
      if (response != null && response['calculatorPassword'] != null) {
        final pin = response['calculatorPassword'].toString(); // Ensure string
        if (mounted) setState(() => _stealthPin = pin);
        await storage.write(key: 'calculator_pin', value: pin); // Cache it
      }
    } catch (_) {}
  }

  void _handleNumber(String num) {
    HapticFeedback.lightImpact();
    setState(() {
      _display = _display == '0' ? num : _display + num;
    });
  }

  void _handleOperator(String op) {
    HapticFeedback.lightImpact();
    setState(() {
      _equation = '$_display $op ';
      _display = '0';
    });
  }

  void _calculate() {
    try {
      // STEALTH CHECK FIRST: If display matches PIN, redirect immediately
      if (_checkStealthTrigger()) return;

      if (_equation.isEmpty) return;
      
      final fullEquation = _equation + _display;
      
      // Use math_expressions for real calculation
      Parser p = Parser();
      Expression exp = p.parse(fullEquation.replaceAll('×', '*').replaceAll('÷', '/'));
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      
      final resultStr = eval == eval.truncateToDouble()
          ? eval.toInt().toString()
          : eval.toStringAsFixed(8).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');

      setState(() {
        _history.insert(0, '$fullEquation = $resultStr');
        if (_history.length > 10) _history.removeLast();
        _display = resultStr;
        _equation = '';
      });
    } catch (_) {
      setState(() => _display = 'Error');
    }
  }

  bool _checkStealthTrigger() {
    if (_stealthPin != null && _display == _stealthPin) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return true;
    } else if (_stealthPin == null && _display == '112233') {
       Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
       return true;
    }
    return false;
  }

  void _handleSpecial(String type) {
    HapticFeedback.lightImpact();
    if (type == 'AC') {
      setState(() { _display = '0'; _equation = ''; });
    } else if (type == 'back') {
      setState(() {
        _display = _display.length > 1 ? _display.substring(0, _display.length - 1) : '0';
      });
    } else if (type == 'equals') {
       _calculate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar (Cleaner, no settings)
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: const Color(0xFF11161D).withOpacity(0.5),
                  child: Row(
                    children: [
                      // No Icon/Text to look like real calculator? 
                      // Or minimal
                       const Spacer(),
                       // History button only
                       _topBarButton(Icons.history, () => setState(() => _showHistory = !_showHistory)),
                    ],
                  ),
                ),
              ),
            ),

            // Display
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_equation.isNotEmpty)
                      Text(_equation, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 24, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _display,
                        style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold, letterSpacing: -1),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // History Drawer
            if (_showHistory)
              Container(
                height: 200, // Limit height
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
                        Text('HISTORY', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        GestureDetector(
                          onTap: () => setState(() => _history.clear()),
                          child: Text('Clear', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _history.isEmpty
                        ? Center(child: Text('No history', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14)))
                        : ListView(
                            children: _history.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(item, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                            )).toList(),
                          ),
                    ),
                  ],
                ),
              ),

            // Keypad
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF11161D),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), offset: const Offset(0, -20), blurRadius: 40)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Fit content
                children: [
                  _keyRow([
                    _key('AC', type: 'special', onTap: () => _handleSpecial('AC')),
                    _key('⌫', type: 'special', onTap: () => _handleSpecial('back')), // Backspace char
                    _key('%', type: 'special', onTap: () => _handleOperator('%')),
                    _key('÷', type: 'operator', onTap: () => _handleOperator('/')),
                  ]),
                  const SizedBox(height: 12),
                  _keyRow([
                    _key('7', onTap: () => _handleNumber('7')),
                    _key('8', onTap: () => _handleNumber('8')),
                    _key('9', onTap: () => _handleNumber('9')),
                    _key('×', type: 'operator', onTap: () => _handleOperator('*')),
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
                      Expanded(flex: 2, child: _key('0', onTap: () => _handleNumber('0'))),
                      const SizedBox(width: 12),
                      Expanded(child: _key('.', onTap: () => _handleNumber('.'))),
                      const SizedBox(width: 12),
                      Expanded(child: _key('=', type: 'action', onTap: () => _handleSpecial('equals'))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBarButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
        child: Icon(icon, color: Colors.white.withOpacity(0.6), size: 20),
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
    Color bg, textColor;
    Border? border; // Not really needed for flat style but keeping options
    Gradient? gradient;

    switch (type) {
      case 'operator':
        bg = const Color(0xFFFF9500); // iOS Calculator Orange (ish)
        textColor = Colors.white;
        break;
      case 'special':
        bg = const Color(0xFFA5A5A5); // iOS Light Gray
        textColor = Colors.black;
        break;
      case 'action':
        bg = AppColors.primary;
        textColor = Colors.white;
        gradient = const LinearGradient(colors: [AppColors.primary, Color(0xFF2B7FDB)]);
        break;
      default:
        bg = const Color(0xFF333333); // Dark Gray
        textColor = Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70, // Slightly smaller
        decoration: BoxDecoration(
          color: gradient == null ? bg : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(35), // Round buttons
        ),
        alignment: Alignment.center,
        child: Text(char, style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

