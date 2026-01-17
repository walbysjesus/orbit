 import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/api.dart';

class AuthService {
  // LOGIN
  static Future<bool> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${Api.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt', token);

      return true;
    }
    return false;
  }

  // REGISTRO + AUTO LOGIN
  static Future<bool> register(
    String name,
    String email,
    String password,
  ) async {
    // Genera un ID único para el usuario (puedes usarlo en tu lógica real)
    final String userId = const Uuid().v4();
    // Ejemplo: print(userId) o úsalo en el registro
    print('ID único generado para el usuario: $userId');
    final response = await http.post(
      Uri.parse('${Api.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      // auto-login
      return await login(email, password);
    }
    return false;
  }

  // TOKEN EXISTE?
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt') != null;
  }

  // LOGOUT
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
  }
}
