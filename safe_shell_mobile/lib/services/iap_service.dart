import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'network_service.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  // Example IDs. The user MUST change this to their real product ID matching Play Console.
  static const String premiumSubscriptionId = 'premium_monthly_sub';

  List<ProductDetails> products = [];
  bool isAvailable = false;
  AuthProvider? _authProvider;

  Future<void> initialize(AuthProvider provider) async {
    _authProvider = provider;
    isAvailable = await _iap.isAvailable();
    if (isAvailable) {
      await _getProducts();
      final purchaseUpdated = _iap.purchaseStream;
      _subscription = purchaseUpdated.listen((purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {
        _subscription?.cancel();
      }, onError: (error) {
        if (kDebugMode) debugPrint("IAP Stream Error: $error");
      });
    }
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> _getProducts() async {
    final ProductDetailsResponse response =
        await _iap.queryProductDetails({premiumSubscriptionId});
    if (response.error == null && response.productDetails.isNotEmpty) {
      products = response.productDetails;
    } else {
      if (kDebugMode) debugPrint("Failed to load products or none found.");
    }
  }

  Future<void> buyPremium() async {
    if (products.isEmpty) {
      if (kDebugMode) debugPrint('No products available to buy.');
      return;
    }
    final product = products.firstWhere((p) => p.id == premiumSubscriptionId, orElse: () => products.first);
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    // Use buyNonConsumable for auto-renewing subscriptions in the in_app_purchase plugin
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint("Purchase is pending...");
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          if (kDebugMode) debugPrint("Purchase error: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          _verifySubscriptionOnBackend(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifySubscriptionOnBackend(PurchaseDetails purchaseDetails) async {
    final user = _authProvider?.user;
    if (user == null || (user.token?.isEmpty ?? true)) return;

    try {
      final String purchaseToken = purchaseDetails.verificationData.serverVerificationData;
      final String platform = defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';

      // Send the token to the Koyeb backend so it can call Google Play Developer API to verify it
      final response = await NetworkService.client.post(
        Uri.parse('${AppConstants.baseUrl}/auth/verify-subscription'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
        body: jsonEncode({
          'purchaseToken': purchaseToken,
          'productId': purchaseDetails.productID,
          'platform': platform,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("Server validation passed! Refreshing user...");
        await _authProvider?.refreshUser();
      } else {
        if (kDebugMode) debugPrint("Server validation failed: ${response.body}");
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error during backend validation: $e");
    }
  }
}
