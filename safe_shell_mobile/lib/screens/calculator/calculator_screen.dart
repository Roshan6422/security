import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../main.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _expression = '';
  final _storage = const FlutterSecureStorage();
  String _pinBuffer = '';

  void _onPressed(String char) {
    HapticFeedback.lightImpact();
    setState(() {
      if (char == 'AC') {
        _display = '0';
        _expression = '';
        _pinBuffer = '';
      } else if (char == '=') {
        _evaluate();
        _pinBuffer = '';
      } else if (char == '+' || char == '-' || char == '' || char == '') {
        _expression = _display + char;
        _display = '0';
        _pinBuffer = '';
      } else {
        if (_display == '0') {
          _display = char;
        } else {
          _display += char;
        }
        
        // PIN Detection Logic
        _pinBuffer += char;
        if (_pinBuffer.length > 4) {
          _pinBuffer = _pinBuffer.substring(_pinBuffer.length - 4);
        }
        _checkPin();
      }
    });
  }

  Future<void> _checkPin() async {
    final savedPin = await _storage.read(key: 'calculator_pin');
    if (savedPin != null && _pinBuffer == savedPin) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        _unlockVault();
      }
    }
  }

  void _unlockVault() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
    );
  }

  void _evaluate() {
    try {
      double res = 0;
      if (_expression.contains('+')) {
        res = double.parse(_expression.split('+')[0]) + double.parse(_display);
      } else if (_expression.contains('-')) {
        res = double.parse(_expression.split('-')[0]) - double.parse(_display);
      } else if (_expression.contains('')) {
        res = double.parse(_expression.split('')[0]) * double.parse(_display);
      } else if (_expression.contains('')) {
        res = double.parse(_expression.split('')[0]) / double.parse(_display);
      } else {
        return;
      }
      _display = res.toString().replaceAll('.0', '');
      _expression = '';
    } catch (e) {
      _display = 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Text(
                  _display,
                  style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w300),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            _buildButtonRow(['AC', '+/-', '%', '÷'], [const Color(0xFFA5A5A5), const Color(0xFFA5A5A5), const Color(0xFFA5A5A5), const Color(0xFFFF9F0A)], isTopRow: true),
            _buildButtonRow(['7', '8', '9', '×'], [const Color(0xFF333333), const Color(0xFF333333), const Color(0xFF333333), const Color(0xFFFF9F0A)]),
            _buildButtonRow(['4', '5', '6', '-'], [const Color(0xFF333333), const Color(0xFF333333), const Color(0xFF333333), const Color(0xFFFF9F0A)]),
            _buildButtonRow(['1', '2', '3', '+'], [const Color(0xFF333333), const Color(0xFF333333), const Color(0xFF333333), const Color(0xFFFF9F0A)]),
            _buildLastRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow(List<String> labels, List<Color> colors, {bool isTopRow = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (i) => _buildButton(labels[i], colors[i], isTopRow: isTopRow)),
      ),
    );
  }

  Widget _buildLastRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildButton('0', const Color(0xFF333333), isWide: true),
          _buildButton('.', const Color(0xFF333333)),
          _buildButton('=', const Color(0xFFFF9F0A)),
        ],
      ),
    );
  }

  Widget _buildButton(String label, Color color, {bool isWide = false, bool isTopRow = false}) {
    double size = (MediaQuery.of(context).size.width - 64) / 4;
    Color textColor = isTopRow ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: () => _onPressed(label),
      child: Container(
        height: size,
        width: isWide ? (size * 2) + 16 : size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size / 2),
        ),
        alignment: isWide ? Alignment.centerLeft : Alignment.center,
        padding: isWide ? const EdgeInsets.only(left: 32) : null,
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 34,
            fontWeight: isTopRow ? FontWeight.w400 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

