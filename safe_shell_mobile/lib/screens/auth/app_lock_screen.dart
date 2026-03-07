import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/theme.dart';
import '../../widgets/premium_snackbar.dart';

class AppLockScreen extends StatefulWidget {
  final String packageName;
  const AppLockScreen({super.key, required this.packageName});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  String _correctPin = "1234";
  static const _storage = FlutterSecureStorage();
  static const _channel = MethodChannel('com.safeshell.safe_shell_mobile/stealth');

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final pin = await _storage.read(key: 'calculator_pin');
    if (pin != null && pin.isNotEmpty) {
      setState(() => _correctPin = pin);
    }
  }

  void _onNumberPressed(String number) {
    if (_pinController.text.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _pinController.text += number;
      });
      
      if (_pinController.text.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDelete() {
    if (_pinController.text.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    if (_pinController.text == _correctPin) {
      HapticFeedback.mediumImpact();
      
      // Unlock package natively
      try {
        await _channel.invokeMethod('unlockPackage', {'packageName': widget.packageName});
        
        // IMPORTANT: Launch the intercepted app so the user goes straight to it!
        await _channel.invokeMethod('launchApp', {'packageName': widget.packageName});
        
      } catch (e) {
        debugPrint('Error unlocking package: $e');
      }

      // Close the lock screen
      if (mounted) {
         // Because we might have intercepted this over the dashboard, we pop to hide the lock screen
         if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
         }
         // Move SafeShell back to the background so the launched app comes up
         SystemNavigator.pop(); 
      }
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _pinController.clear();
      });
      PremiumSnackbar.show(context, message: 'Incorrect PIN', emoji: '❌', color: Colors.redAccent);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final backgroundColor = isLight ? AppColors.background : Colors.black;
    final textColor = isLight ? AppColors.textPrimary : const Color(0xFFF1F5F9);
    final subColor = isLight ? AppColors.textSecondary : const Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Logo & Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'ACCESS RESTRICTED',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Protected by SafeShell Midnight',
              style: TextStyle(color: subColor, fontSize: 13),
            ),
            const SizedBox(height: 48),
            
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                bool isFilled = _pinController.text.length > index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? AppColors.primary : (isLight ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.1)),
                    boxShadow: isFilled ? [
                      BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)
                    ] : [],
                  ),
                );
              }),
            ),
            const Spacer(),
            
            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Column(
                children: [
                  _buildKeypadRow(['1', '2', '3']),
                  const SizedBox(height: 20),
                  _buildKeypadRow(['4', '5', '6']),
                  const SizedBox(height: 20),
                  _buildKeypadRow(['7', '8', '9']),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 80),
                      _buildKeypadButton('0'),
                      SizedBox(
                        width: 80,
                        child: IconButton(
                          onPressed: _onDelete,
                          icon: Icon(Icons.backspace_outlined, color: isLight ? Colors.black54 : Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildKeypadButton(n)).toList(),
    );
  }

  Widget _buildKeypadButton(String number) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final btnBg = isLight ? AppColors.surface : const Color(0xFF1E293B);
    final btnBorder = isLight ? Colors.black12 : const Color(0xFF334155);
    final btnText = isLight ? AppColors.textPrimary : const Color(0xFFF1F5F9);

    return InkWell(
      onTap: () => _onNumberPressed(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: btnBg,
          border: Border.all(color: btnBorder),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(color: btnText, fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

