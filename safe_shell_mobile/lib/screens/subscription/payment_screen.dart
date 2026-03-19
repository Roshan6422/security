import 'package:flutter/material.dart';
import 'package:safe_shell_mobile/core/theme.dart';
import '../../widgets/glass_card.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/iap_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = false;
  
  @override
  void initState() {
    super.initState();
    // Initialize IAPService if not already
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    IAPService().initialize(authProvider).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _handlePayment() async {
    setState(() => _loading = true);
    try {
      await IAPService().buyPremium();
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

  void _handleRestore() async {
    setState(() => _loading = true);
    try {
      await IAPService().restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored. Processing...'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ProductDetails? selectedProduct;
    if (IAPService().products.isNotEmpty) {
      selectedProduct = IAPService().products.first;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradients
          Positioned(
            top: -100, right: -100,
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
            bottom: -120, left: -120,
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
                      const Spacer(),
                      TextButton(
                        onPressed: _loading ? null : _handleRestore,
                        child: const Text('Restore', style: TextStyle(color: Colors.white70)),
                      ),
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
                              const SizedBox(height: 32),

                              // Price
                              if (!IAPService().isAvailable)
                                const Text('Store Unavailable', style: TextStyle(color: Colors.redAccent))
                              else if (selectedProduct == null)
                                const CircularProgressIndicator(color: AppColors.primary)
                              else
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(selectedProduct.price, style: AppTextStyles.heading.copyWith(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 6),
                                        Text('Billed Monthly (Auto-Renews)', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary.withOpacity(0.6))),
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Pro Features', style: AppTextStyles.heading.copyWith(fontSize: 18)),
                        ),
                        const SizedBox(height: 16),

                        _buildFeatureCard(Icons.screenshot_rounded, 'Allow Screenshots', 'Temporarily enable screenshots', const Color(0xFF4DA3FF)),
                        _buildFeatureCard(Icons.security, 'Anti-Uninstall', 'Prevent unauthorized app removal', const Color(0xFF10B981)),
                        _buildFeatureCard(Icons.block, 'Ad-Free Experience', 'Zero interruptions across the vault', const Color(0xFFF59E0B)),

                        const SizedBox(height: 32),
                        // CTA
                        SizedBox(
                          width: double.infinity, height: 56,
                          child: ElevatedButton(
                            onPressed: (_loading || selectedProduct == null) ? null : _handlePayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Subscribe with Google Play', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Secure checkout via Google Play.', style: TextStyle(color: Colors.white30, fontSize: 12)),
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
