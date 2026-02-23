import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';

class BillingService {
  final _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _sub;

  final String proMonthlyId = 'pro_monthly'; // Play Console product id

  Future<void> init({
    required void Function(bool isPro) onProChanged,
  }) async {
    final available = await _iap.isAvailable();
    if (!available) return;

    _sub = _iap.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.productID == proMonthlyId) {
          if (p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored) {
            onProChanged(true);
          }
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
        }
      }
    });
  }

  Future<ProductDetails?> getProProduct() async {
    final res = await _iap.queryProductDetails({proMonthlyId});
    if (res.productDetails.isEmpty) return null;
    return res.productDetails.first;
  }

  Future<void> buyPro(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> dispose() async => _sub.cancel();
}
