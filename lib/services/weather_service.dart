import 'package:google_weather_flutter/google_weather_flutter.dart';
import '../ia_core/decision_engine.dart';

class WeatherService {
  // Devuelve el estado del clima como WeatherCondition
  static Future<WeatherCondition> getCurrentWeather({required double lat, required double lon}) async {
    try {
      final weather = await GoogleWeather().getWeather(lat: lat, lon: lon);
      final code = weather.currentWeather?.weatherCode ?? 0;
      // Mapear el código de GoogleWeather a WeatherCondition
      if (code >= 200 && code < 300) return WeatherCondition.storm;
      if (code >= 300 && code < 600) return WeatherCondition.rain;
      if (code >= 600 && code < 700) return WeatherCondition.fog;
      if (code >= 700 && code < 800) return WeatherCondition.fog;
      if (code == 800) return WeatherCondition.clear;
      if (code > 800) return WeatherCondition.rain;
      return WeatherCondition.unknown;
    } catch (_) {
      return WeatherCondition.unknown;
    }
  }
}
