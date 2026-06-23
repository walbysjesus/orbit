import 'package:weather/weather.dart';
import '../ia_core/decision_engine.dart';
import 'config_service.dart';

class WeatherService {
  static Future<WeatherCondition> getCurrentWeather({
    required double lat,
    required double lon,
  }) async {
    try {
      final apiKey = ConfigService.getOpenWeatherApiKey();
      if (apiKey.isEmpty) {
        return WeatherCondition.unknown;
      }
      final weatherFactory =
          WeatherFactory(apiKey, language: Language.SPANISH);
      final Weather weather =
          await weatherFactory.currentWeatherByLocation(lat, lon);
      final description = (weather.weatherDescription ?? '').toLowerCase();

      if (description.contains('tormenta') ||
          description.contains('storm') ||
          description.contains('thunder')) {
        return WeatherCondition.storm;
      }
      if (description.contains('lluvia') ||
          description.contains('rain') ||
          description.contains('drizzle')) {
        return WeatherCondition.rain;
      }
      if (description.contains('niebla') ||
          description.contains('fog') ||
          description.contains('mist') ||
          description.contains('haze')) {
        return WeatherCondition.fog;
      }
      if (description.contains('despejado') ||
          description.contains('clear') ||
          description.contains('sun')) {
        return WeatherCondition.clear;
      }
      if (description.contains('calor extremo') ||
          description.contains('extreme heat')) {
        return WeatherCondition.extremeHeat;
      }
      return WeatherCondition.unknown;
    } catch (e) {
      return WeatherCondition.unknown;
    }
  }
}
