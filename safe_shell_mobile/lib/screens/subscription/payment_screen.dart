import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import '../../widgets/glass_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'payment_success_screen.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = false;
  String _billing = 'monthly'; // 'monthly' or 'yearly'
  String _paymentMethod = 'payhere'; // 'payhere' or 'bank'

  final Map<String, dynamic> _plans = {
    'monthly': {'price': 9.99, 'suffix': '/month', 'note': 'Billed monthly'},
    'yearly': {'price': 99.99, 'suffix': '/year', 'note': 'Save ~17% vs monthly'},
  };

  void _handlePayment() async {
    if (_paymentMethod == 'payhere') {
      _startPayHereCheckout();
    } else {
      _showBankTransferInfo();
    }
  }

  Future<void> _startPayHereCheckout() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      // Simulate backend payment hash and processing for pure Firebase architecture
      await Future.delayed(const Duration(seconds: 2));
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'subscriptionStatus': 'pro',
      });

      if (!mounted) return;

      // CRITICAL BUG FIX: Refresh the provider so the app knows we are now PRO
      // without requiring a full app restart.
      await Provider.of<AuthProvider>(context, listen: false).refreshUser();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PaymentSuccessScreen()),
      );
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showBankTransferInfo() async {
    setState(() => _loading = true);
    try {
      // Simulated bank details from the retired backend
      final bankInfo = {
        'bankName': 'Commercial Bank',
        'accountHolder': 'SafeShell Pro',
        'accountNumber': '1234567890',
        'branch': 'Colombo 03',
        'swiftCode': 'CBLKLKX',
      };
      
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bank Transfer Details', style: AppTextStyles.heading.copyWith(fontSize: 20)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white60)),
                ],
              ),
              const SizedBox(height: 20),
              _buildBankRow('Bank', bankInfo['bankName'] ?? ''),
              _buildBankRow('Account Holder', bankInfo['accountHolder'] ?? ''),
              _buildBankRow('Account Number', bankInfo['accountNumber'] ?? ''),
              _buildBankRow('Branch', bankInfo['branch'] ?? ''),
              _buildBankRow('SWIFT / IFSC', bankInfo['swiftCode'] ?? ''),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'After transferring, please send a screenshot of the receipt to our support chat for verification.',
                        style: AppTextStyles.caption.copyWith(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('I Have Transferred', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load bank info: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildBankRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.caption.copyWith(fontSize: 10, color: Colors.white30, letterSpacing: 1)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: AppTextStyles.subheading.copyWith(fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: AppColors.primary),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied $label to clipboard'), duration: const Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlan = _plans[_billing];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradients
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 500, height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4DA3FF).withOpacity(0.1),
                boxShadow: [BoxShadow(color: const Color(0xFF4DA3FF).withOpacity(0.1), blurRadius: 120)],
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -120,
            child: Container(
              width: 460, height: 460,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0A2A4F).withOpacity(0.3),
                boxShadow: [BoxShadow(color: const Color(0xFF0A2A4F).withOpacity(0.3), blurRadius: 110)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text('Upgrade to Pro', style: AppTextStyles.heading.copyWith(fontSize: 20)),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Hero Card
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 48, height: 48,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          gradient: const LinearGradient(colors: [Color(0xFF4DA3FF), Color(0xFFA1B3CC)]),
                                          boxShadow: [BoxShadow(color: const Color(0xFF4DA3FF).withOpacity(0.4), blurRadius: 24)],
                                        ),
                                        child: const Icon(Icons.star, color: Colors.white, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('SafeShell Pro', style: AppTextStyles.heading.copyWith(fontSize: 16)),
                                          Text('Premium vault experience', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary.withOpacity(0.6))),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Text('Most Popular', style: AppTextStyles.caption.copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Plan Selection
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Row(
                                  children: [
                                    _buildSelectionTab('Monthly', _billing == 'monthly', () => setState(() => _billing = 'monthly')),
                                    _buildSelectionTab('Yearly', _billing == 'yearly', () => setState(() => _billing = 'yearly'), showDiscount: true),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Price
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text('\$${selectedPlan['price']}', style: AppTextStyles.heading.copyWith(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1)),
                                  Text(selectedPlan['suffix'], style: AppTextStyles.subheading.copyWith(color: Colors.white60)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(selectedPlan['note'], style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary.withOpacity(0.6))),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Payment Method', style: AppTextStyles.heading.copyWith(fontSize: 18)),
                        ),
                        const SizedBox(height: 16),

                        // Payment Methods
                        Row(
                          children: [
                            Expanded(child: _buildMethodCard('PayHere', 'payhere', Icons.credit_card, const Color(0xFF4DA3FF))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMethodCard('Bank', 'bank', Icons.account_balance, const Color(0xFF10B981))),
                          ],
                        ),

                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Pro Features', style: AppTextStyles.heading.copyWith(fontSize: 18)),
                        ),
                        const SizedBox(height: 16),

                        _buildFeatureCard(Icons.cloud_queue, '8GB Storage', 'Store files, media, docs & more', const Color(0xFF4DA3FF)),
                        _buildFeatureCard(Icons.security, 'Advanced Security', 'Strong encryption + vault hardening', const Color(0xFF10B981)),
                        _buildFeatureCard(Icons.flash_on, 'Priority Support', 'Faster replies, dedicated help', const Color(0xFFF59E0B)),

                        const SizedBox(height: 24),
                        // CTA
                        SizedBox(
                          width: double.infinity, height: 56,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handlePayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(_paymentMethod == 'payhere' ? 'Pay with PayHere' : 'Show Bank Details', 
                                           style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Secure checkout. No hidden fees.', style: TextStyle(color: Colors.white30, fontSize: 12)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTab(String label, bool isSelected, VoidCallback onTap, {bool showDiscount = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4DA3FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            gradient: isSelected ? const LinearGradient(colors: [Color(0xFF4DA3FF), Color(0xFFA1B3CC)]) : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: FontWeight.bold, fontSize: 13)),
              if (showDiscount && !isSelected) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text('Save 17%', style: TextStyle(color: AppColors.primary, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodCard(String label, String method, IconData icon, Color color) {
    final isSelected = _paymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = method),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        border: isSelected ? Border.all(color: color.withOpacity(0.5), width: 2) : Border.all(color: Colors.white.withOpacity(0.1)),
        child: Column(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.subheading.copyWith(fontSize: 14)),
                  Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }
}

class _PayHereWebView extends StatefulWidget {
  final String url;
  const _PayHereWebView({required this.url});

  @override
  State<_PayHereWebView> createState() => _PayHereWebViewState();
}

class _PayHereWebViewState extends State<_PayHereWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            // Monitor success/cancel URLs
            if (request.url.contains('/payment/success')) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }
            if (request.url.contains('/payment/cancel')) {
              Navigator.pop(context, false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          title: Text('Secure Checkout', style: const TextStyle(fontSize: 16, color: Colors.white)),
          leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

