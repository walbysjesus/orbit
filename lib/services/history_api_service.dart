import 'package:http/http.dart' as http;
import 'dart:convert';

class HistoryApiService {
  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    final url = Uri.parse('http://10.0.2.2:3000/api/history');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Error al cargar historial');
  }
}
