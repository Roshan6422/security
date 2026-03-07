import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../main_shell.dart';
import '../auth/login_screen.dart';

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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Text(
                  _display,
                  style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w300),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            _buildButtonRow(['AC', '+/-', '%', ''], [Colors.grey[400]!, Colors.grey[400]!, Colors.grey[400]!, Colors.orange]),
            _buildButtonRow(['7', '8', '9', ''], [Colors.grey[850]!, Colors.grey[850]!, Colors.grey[850]!, Colors.orange]),
            _buildButtonRow(['4', '5', '6', '-'], [Colors.grey[850]!, Colors.grey[850]!, Colors.grey[850]!, Colors.orange]),
            _buildButtonRow(['1', '2', '3', '+'], [Colors.grey[850]!, Colors.grey[850]!, Colors.grey[850]!, Colors.orange]),
            _buildLastRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow(List<String> labels, List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (i) => _buildButton(labels[i], colors[i])),
      ),
    );
  }

  Widget _buildLastRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildButton('0', Colors.grey[850]!, isWide: true),
          _buildButton('.', Colors.grey[850]!),
          _buildButton('=', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildButton(String label, Color color, {bool isWide = false}) {
    double size = (MediaQuery.of(context).size.width - 60) / 4;
    return GestureDetector(
      onTap: () => _onPressed(label),
      child: Container(
        height: size,
        width: isWide ? (size * 2) + 12 : size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size / 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color == Colors.grey[400] ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            fontSize: 32,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

