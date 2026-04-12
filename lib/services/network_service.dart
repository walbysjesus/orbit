import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

enum NetworkQuality {
  none,
  low,
  medium,
  high,
  unknown,
}

enum ConnectivityType {
  wifi,
  mobile,
  ethernet,
  bluetooth,
  none,
  satellite, // Agregado para conectividad satelital
}

class NetworkException implements Exception {
  final String message;

  NetworkException([this.message = 'No internet connection']);

  @override
  String toString() => 'NetworkException: $message';
}

class ConnectivityProvider {
  Future<dynamic> checkConnectivity() {
    return Connectivity().checkConnectivity();
  }
}

class NetworkService {
  final ConnectivityProvider _provider;

  NetworkService([ConnectivityProvider? provider])
      : _provider = provider ?? ConnectivityProvider();

  Future<ConnectivityType> getConnectivityType() async {
    final connectivity = await _provider.checkConnectivity();
    ConnectivityResult? current;

    if (connectivity is ConnectivityResult) {
      current = connectivity;
    } else if (connectivity is List<ConnectivityResult> &&
        connectivity.isNotEmpty) {
      current = connectivity.first;
    }

    if (current == null) {
      return ConnectivityType.none;
    }

    switch (current) {
      case ConnectivityResult.wifi:
        return ConnectivityType.wifi;
      case ConnectivityResult.ethernet:
        return ConnectivityType.ethernet;
      case ConnectivityResult.mobile:
        // Detectar satélite midiendo latencia real (>300ms + móvil)
        if (await isSatelliteConnected()) {
          return ConnectivityType.satellite;
        }
        return ConnectivityType.mobile;
      case ConnectivityResult.bluetooth:
        return ConnectivityType.bluetooth;
      case ConnectivityResult.none:
        return ConnectivityType.none;
      default:
        return ConnectivityType.none;
    }
  }

  Future<bool> isSatelliteConnected() async {
    // Detectar satélite midiendo latencia real (>300ms indica satélite)
    final latency = await measureLatencyMs();
    return latency != null && latency > 300;
  }

  Future<NetworkQuality> getNetworkQuality() async {
    final connectivity = await _provider.checkConnectivity();
    ConnectivityResult? current;

    if (connectivity is ConnectivityResult) {
      current = connectivity;
    } else if (connectivity is List<ConnectivityResult> &&
        connectivity.isNotEmpty) {
      current = connectivity.first;
    }

    if (current == null) {
      return NetworkQuality.unknown;
    }

    switch (current) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        return NetworkQuality.high;
      case ConnectivityResult.mobile:
      case ConnectivityResult.bluetooth:
        return NetworkQuality.medium;
      case ConnectivityResult.none:
        return NetworkQuality.none;
      default:
        return NetworkQuality.unknown;
    }
  }

  Future<bool> get hasConnection async {
    final result = await getNetworkQuality();
    return result == NetworkQuality.high || result == NetworkQuality.medium;
  }

  Future<void> ensureConnected() async {
    if (!await hasConnection) {
      throw NetworkException();
    }
  }

  Future<int?> measureLatencyMs({
    String probeUrl = 'https://www.gstatic.com/generate_204',
  }) async {
    final uri = Uri.tryParse(probeUrl);
    if (uri == null) return null;

    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      stopwatch.stop();
      if (response.statusCode >= 200 && response.statusCode < 500) {
        return stopwatch.elapsedMilliseconds;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
