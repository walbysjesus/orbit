import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'subscription_service.dart';

class InAppPurchaseService {
  static final InAppPurchaseService _instance = InAppPurchaseService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  final List<String> _kIds = <String>['orbit_pro', 'orbit_premium'];
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  InAppPurchaseService._() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(_onPurchaseUpdated, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Ignorar por ahora, se maneja en UI
    });
  }

  static InAppPurchaseService get instance => _instance;

  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
      throw Exception('In-app purchase not available on this device');
    }
  }

  Future<List<ProductDetails>> loadProducts() async {
    final response = await _iap.queryProductDetails(_kIds.toSet());
    if (response.error != null) {
      throw Exception('Error loading products: ${response.error!.message}');
    }
    return response.productDetails;
  }

  Future<void> buyPro() async {
    await _buyProduct('orbit_pro');
  }

  Future<void> buyPremium() async {
    await _buyProduct('orbit_premium');
  }

  Future<void> _buyProduct(String id) async {
    final products = await loadProducts();
    final product = products.firstWhere((p) => p.id == id,
        orElse: () => throw Exception('Product not found'));

    final purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _verifyPurchase(purchase);
      }
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    // Integrar aquí https://developer.apple.com/documentation/appstorereceipts y https://developers.google.com/android-publisher/api-ref
    // Mock: aceptamos directamente
    if (purchase.productID == 'orbit_pro') {
      subscriptionService.upgradeTo(SubscriptionLevel.pro);
    } else if (purchase.productID == 'orbit_premium') {
      subscriptionService.upgradeTo(SubscriptionLevel.premium);
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
