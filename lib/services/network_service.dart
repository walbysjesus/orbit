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

enum ThermalLevel {
  cool,
  warm,
  hot,
  critical,
}

class CallAdaptiveProfile {
  final int maxWidth;
  final int maxHeight;
  final int maxFps;
  final int targetBitrateKbps;
  final int minBitrateKbps;
  final bool pauseVideo;
  final bool batterySaver;
  final ThermalLevel thermalLevel;

  const CallAdaptiveProfile({
    required this.maxWidth,
    required this.maxHeight,
    required this.maxFps,
    required this.targetBitrateKbps,
    required this.minBitrateKbps,
    required this.pauseVideo,
    required this.batterySaver,
    required this.thermalLevel,
  });
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
    // Heurística robusta: solo móvil + mediana de varias muestras de latencia.
    final connectivity = await _provider.checkConnectivity();
    ConnectivityResult? current;

    if (connectivity is ConnectivityResult) {
      current = connectivity;
    } else if (connectivity is List<ConnectivityResult> &&
        connectivity.isNotEmpty) {
      current = connectivity.first;
    }

    if (current != ConnectivityResult.mobile) {
      return false;
    }

    final samples = <int>[];
    for (var i = 0; i < 3; i++) {
      final latency = await measureLatencyMs();
      if (latency != null) {
        samples.add(latency);
      }
    }

    if (samples.length < 2) {
      return false;
    }

    samples.sort();
    final median = samples[samples.length ~/ 2];
    return median >= 450;
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

  ThermalLevel estimateThermalLevel({
    required NetworkQuality quality,
    required bool isSatellite,
    int? latencyMs,
    int reconnectAttempts = 0,
    int unhealthyHeartbeatTicks = 0,
  }) {
    final latency = latencyMs ?? 0;
    final stressScore = (isSatellite ? 2 : 0) +
        (quality == NetworkQuality.low || quality == NetworkQuality.none ? 2 : 0) +
        (latency >= 700 ? 2 : (latency >= 450 ? 1 : 0)) +
        (reconnectAttempts >= 4 ? 2 : (reconnectAttempts >= 2 ? 1 : 0)) +
        (unhealthyHeartbeatTicks >= 4 ? 2 : (unhealthyHeartbeatTicks >= 2 ? 1 : 0));

    if (stressScore >= 7) return ThermalLevel.critical;
    if (stressScore >= 5) return ThermalLevel.hot;
    if (stressScore >= 3) return ThermalLevel.warm;
    return ThermalLevel.cool;
  }

  CallAdaptiveProfile getAdaptiveCallProfile({
    required bool audioOnly,
    required NetworkQuality quality,
    required bool isSatellite,
    int? latencyMs,
    int reconnectAttempts = 0,
    int unhealthyHeartbeatTicks = 0,
    bool batterySaverHint = false,
  }) {
    if (audioOnly) {
      return const CallAdaptiveProfile(
        maxWidth: 0,
        maxHeight: 0,
        maxFps: 0,
        targetBitrateKbps: 48,
        minBitrateKbps: 24,
        pauseVideo: true,
        batterySaver: true,
        thermalLevel: ThermalLevel.cool,
      );
    }

    final thermal = estimateThermalLevel(
      quality: quality,
      isSatellite: isSatellite,
      latencyMs: latencyMs,
      reconnectAttempts: reconnectAttempts,
      unhealthyHeartbeatTicks: unhealthyHeartbeatTicks,
    );

    final poorNetwork = quality == NetworkQuality.low || quality == NetworkQuality.none;
    final highLatency = (latencyMs ?? 0) >= 550;
    final batterySaver = batterySaverHint ||
        thermal == ThermalLevel.hot ||
        thermal == ThermalLevel.critical ||
        poorNetwork ||
        isSatellite;

    if (thermal == ThermalLevel.critical || quality == NetworkQuality.none) {
      return CallAdaptiveProfile(
        maxWidth: 640,
        maxHeight: 480,
        maxFps: 12,
        targetBitrateKbps: 220,
        minBitrateKbps: 120,
        pauseVideo: true,
        batterySaver: true,
        thermalLevel: thermal,
      );
    }

    if (batterySaver || highLatency) {
      return CallAdaptiveProfile(
        maxWidth: 640,
        maxHeight: 480,
        maxFps: 18,
        targetBitrateKbps: 450,
        minBitrateKbps: 180,
        pauseVideo: false,
        batterySaver: true,
        thermalLevel: thermal,
      );
    }

    return CallAdaptiveProfile(
      maxWidth: 1280,
      maxHeight: 720,
      maxFps: 24,
      targetBitrateKbps: 1200,
      minBitrateKbps: 350,
      pauseVideo: false,
      batterySaver: false,
      thermalLevel: thermal,
    );
  }
}
