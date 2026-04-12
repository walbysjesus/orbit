import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/services/subscription_service.dart';

void main() {
  test('Subscription default es free', () {
    final service = SubscriptionService();
    expect(service.level, SubscriptionLevel.free);
    expect(service.isPro, false);
    expect(service.isPremium, false);
    expect(service.hasFeature('chat'), true);
    expect(service.hasFeature('cloud_recording'), false);
  });

  test('Subscription pro habilita group_call', () async {
    final service = SubscriptionService();
    await service.upgradeTo(SubscriptionLevel.pro);
    expect(service.isPro, true);
    expect(service.hasFeature('group_call'), true);
    expect(service.hasFeature('cloud_recording'), false);
  });

  test('Subscription premium habilita cloud_recording', () async {
    final service = SubscriptionService();
    await service.upgradeTo(SubscriptionLevel.premium);
    expect(service.isPremium, true);
    expect(service.hasFeature('cloud_recording'), true);
  });
}
