import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  late FirebaseRemoteConfig _remoteConfig;

  Future<void> initialize() async {
    _remoteConfig = FirebaseRemoteConfig.instance;

    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    await _remoteConfig.setDefaults({
      'show_promotion_banner': false,
      'promotion_message': 'Upgrade to Premium for satellite connectivity!',
      'enable_group_calls': false,
    });

    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      // Handle error silently or log
    }
  }

  bool get showPromotionBanner => _remoteConfig.getBool('show_promotion_banner');
  String get promotionMessage => _remoteConfig.getString('promotion_message');
  bool get enableGroupCalls => _remoteConfig.getBool('enable_group_calls');
}