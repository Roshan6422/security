import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:payhere_mobilesdk_flutter/payhere_mobilesdk_flutter.dart';
import '../../widgets/primary_button.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slideUp = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Go Pro',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          //  Ultra background (blue-dominant + soft depth)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.14),
                  cs.surface,
                  cs.secondary.withValues(alpha: 0.06),
                  cs.primary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          //  Glow blobs (calmer + consistent hue)
          Positioned(
            top: -70,
            left: -45,
            child: _GlowBlob(color: cs.primary.withValues(alpha: 0.16), size: 220),
          ),
          Positioned(
            bottom: -90,
            right: -50,
            child: _GlowBlob(color: cs.primary.withValues(alpha: 0.10), size: 260),
          ),
          Positioned(
            top: 210,
            right: -20,
            child: _GlowBlob(color: cs.secondary.withValues(alpha: 0.06), size: 160),
          ),

          SafeArea(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                return Opacity(
                  opacity: _fade.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideUp.value),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
                      children: [
                        // Pro header card (glass)
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),

                                      //  Blue-consistent icon gradient
                                      gradient: LinearGradient(
                                        colors: [
                                          cs.primary.withValues(alpha: 0.92),
                                          cs.primary.withValues(alpha: 0.62),
                                        ],
                                      ),

                                      //  Softer blue glow
                                      boxShadow: [
                                        BoxShadow(
                                          blurRadius: 22,
                                          spreadRadius: 1,
                                          color: cs.primary.withValues(alpha: 0.14),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.workspace_premium_rounded,
                                      color: cs.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Pro Plan',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '\$2.99 / month',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Unlimited vault + USB protection + no ads',
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        _feature('Unlimited files', Icons.all_inbox_rounded),
                        _feature('USB protection (permanent)', Icons.usb_rounded),
                        _feature(
                          'Ghost mode + Calculator stealth',
                          Icons.visibility_off_rounded,
                        ),
                        _feature('Fragment storage', Icons.call_split_rounded),
                        _feature('Emergency lock', Icons.warning_rounded),
                        _feature('Remove ads', Icons.block_rounded),

                        const SizedBox(height: 16),

                        PrimaryButton(
                          text: _isProcessing ? 'Processing...' : 'Go Pro with PayHere',
                          icon: Icons.payment_rounded,
                          isLoading: _isProcessing,
                          onPressed: _startPayHerePayment,
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'Secure payments via PayHere. All major credit and debit cards accepted.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Subtle blur under appbar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: 74,
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feature(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: ListTile(
          leading: Icon(icon),
          title: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  bool _isProcessing = false;

  Future<void> _startPayHerePayment() async {
    if (_isProcessing) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to purchase the Pro Plan')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final orderId = 'PRO_${DateTime.now().millisecondsSinceEpoch}_${user.id}';
      
      // 1. Get Hash from Backend
      final response = await ApiService().post('/payment/generate-hash', {
        'order_id': orderId,
        'amount': '800.00', // Example: LKR 800
        'currency': 'LKR',
      });

      final String merchantId = response['merchant_id'];
      final String hash = response['hash'];

      // 2. Prepare PayHere Object
      Map paymentObject = {
        "sandbox": false, // Change to true for testing
        "merchant_id": merchantId, 
        "merchant_secret": "", // Handled by hash generated in backend via secret, so leave empty/ignore
        "notify_url": "${ApiService.currentBaseUrl}/payment/notify", 
        "order_id": orderId,
        "items": "SafeShell Pro Plan",
        "amount": "800.00",
        "currency": "LKR",
        "hash": hash,
        "first_name": user.name.split(' ').first,
        "last_name": user.name.split(' ').length > 1 ? user.name.split(' ').last : 'User',
        "email": user.email,
        "phone": "0771234567", // TODO: collect phone if mandatory
        "address": "Sri Lanka",
        "city": "Colombo",
        "country": "Sri Lanka",
        "delivery_address": "",
        "delivery_city": "",
        "delivery_country": "",
        "custom_1": user.id,
        "custom_2": ""
      };

      // 3. Start Payment
      PayHere.startPayment(
        paymentObject, 
        (paymentId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment Successful! You are now a Pro.'), backgroundColor: Colors.green),
            );
            context.read<AuthProvider>().checkAuth(); // refresh user status
            Navigator.pop(context);
          }
        }, 
        (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Payment Failed: $error'), backgroundColor: Colors.red),
            );
          }
        }, 
        () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment Cancelled')),
            );
          }
        }
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initiating payment: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),

            //  slightly more front-surface feel
            color: cs.surface.withValues(alpha: 0.78),

            //  slightly clearer border
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),

            boxShadow: [
              BoxShadow(
                blurRadius: 30,
                spreadRadius: 2,
                color: Colors.black.withValues(alpha: 0.10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

