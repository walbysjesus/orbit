enum SubscriptionLevel { free, pro, premium }

final SubscriptionService subscriptionService = SubscriptionService();

class SubscriptionService {
  SubscriptionLevel level = SubscriptionLevel.free;

  bool get isPro => level == SubscriptionLevel.pro || level == SubscriptionLevel.premium;
  bool get isPremium => level == SubscriptionLevel.premium;

  static const Map<SubscriptionLevel, List<String>> features = {
    SubscriptionLevel.free: [
      'chat',
      'voice_call',
    ],
    SubscriptionLevel.pro: [
      'chat',
      'voice_call',
      'group_call',
      'local_recording',
    ],
    SubscriptionLevel.premium: [
      'chat',
      'voice_call',
      'group_call',
      'local_recording',
      'cloud_recording',
      'priority_support',
      'analytics',
    ],
  };

  bool hasFeature(String feature) {
    final List<String>? current = features[level];
    return current?.contains(feature) ?? false;
  }

  Future<void> upgradeTo(SubscriptionLevel targetLevel) async {
    // TODO: Conectar con in_app_purchase + backend.
    level = targetLevel;
  }

  Future<void> restorePurchases() async {
    // TODO: Implementar restauración con in_app_purchase.
  }
}
