import 'dart:convert';
import 'package:http/http.dart' as http;

class OrbitIAService {
  static const String _baseUrl = 'https://api.orbit.ai'; 
  // ← aquí va TU backend real

  static Future<String> sendMessage({
    required String userId,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/ia/chat'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer YOUR_TOKEN',
      },
      body: jsonEncode({
        'userId': userId,
        'message': message,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'];
    } else {
      throw Exception('Orbit IA error');
    }
  }
}
