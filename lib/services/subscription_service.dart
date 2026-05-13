enum SubscriptionLevel { free, pro, premium }

enum CommercialPlan {
  b2cFree,
  b2cPro,
  b2bStarter,
  b2bOps,
  enterpriseGov,
}

final SubscriptionService subscriptionService = SubscriptionService();

class SubscriptionService {
  SubscriptionLevel level = SubscriptionLevel.free;
  CommercialPlan commercialPlan = CommercialPlan.b2cFree;

  bool get isPro =>
      level == SubscriptionLevel.pro || level == SubscriptionLevel.premium;
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

  static const Map<CommercialPlan, List<String>> commercialFeatures = {
    CommercialPlan.b2cFree: [
      'chat',
      'voice_call',
      'basic_history',
    ],
    CommercialPlan.b2cPro: [
      'chat',
      'voice_call',
      'video_call',
      'adaptive_quality',
      'encrypted_backup',
    ],
    CommercialPlan.b2bStarter: [
      'chat',
      'voice_call',
      'video_call',
      'adaptive_quality',
      'team_admin',
      'seat_management',
      'priority_delivery',
    ],
    CommercialPlan.b2bOps: [
      'chat',
      'voice_call',
      'video_call',
      'adaptive_quality',
      'team_admin',
      'seat_management',
      'priority_delivery',
      'voice_channels',
      'audit_logs',
      'safety_pack',
    ],
    CommercialPlan.enterpriseGov: [
      'chat',
      'voice_call',
      'video_call',
      'adaptive_quality',
      'team_admin',
      'seat_management',
      'priority_delivery',
      'voice_channels',
      'audit_logs',
      'safety_pack',
      'private_cloud',
      'sla_24_7',
      'compliance_retention',
    ],
  };

  bool hasFeature(String feature) {
    final List<String>? current = features[level];
    return current?.contains(feature) ?? false;
  }

  bool hasCommercialFeature(String feature) {
    final List<String>? current = commercialFeatures[commercialPlan];
    return current?.contains(feature) ?? false;
  }

  Future<void> upgradeTo(SubscriptionLevel targetLevel) async {
    // TODO: Conectar con in_app_purchase + backend.
    level = targetLevel;
  }

  Future<void> switchCommercialPlan(CommercialPlan targetPlan) async {
    // TODO: Conectar con backend de billing y control de licencias.
    commercialPlan = targetPlan;
  }

  Future<void> restorePurchases() async {
    // TODO: Implementar restauración con in_app_purchase.
  }
}
