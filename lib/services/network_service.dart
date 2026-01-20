import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  // Devuelve la calidad de red como un string simple
  static Future<String> getNetworkQuality() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    switch (connectivityResult) {
      case ConnectivityResult.wifi:
        return "good";
      case ConnectivityResult.mobile:
        return "average";
      case ConnectivityResult.ethernet:
        return "good";
      case ConnectivityResult.bluetooth:
        return "average";
      case ConnectivityResult.none:
        return "none";
      default:
        return "unknown";
    }
  }
}
