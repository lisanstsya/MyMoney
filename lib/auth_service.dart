import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = 'http://10.0.2.2:3000'; // Ganti sesuai IP lokal / server kamu

  Future<String> register(String email, String password, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.toLowerCase().trim(),
          'password': password,
          'name': name.trim(),
        }),
      );

      print("DEBUG: Register - statusCode = ${response.statusCode}");
      print("DEBUG: Register - body = ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 &&
          data is Map &&
          data.containsKey('userId') &&
          data.containsKey('name')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', data['userId'].toString());
        await prefs.setString('userName', data['name'].toString());

        return "Register successful";
      } else {
        // Ambil pesan error dari response
        final message = data['message'];
        String errorMessage;

        if (message == null) {
          errorMessage = 'Registration failed';
        } else if (message is String) {
          errorMessage = message;
        } else if (message is Map) {
          errorMessage = message.values.join(', ');
        } else {
          errorMessage = 'Registration failed';
        }

        return "Failed: $errorMessage";
      }
    } catch (e) {
      print("ERROR: Register - $e");
      return "An error occurred: $e";
    }
  }

  Future<String> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.toLowerCase().trim(),
          'password': password,
        }),
      );

      print("DEBUG: Login - statusCode = ${response.statusCode}");
      print("DEBUG: Login - body = ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          data is Map &&
          data.containsKey('userId') &&
          data.containsKey('name')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', data['userId'].toString());
        await prefs.setString('userName', data['name'].toString());

        return data['message']?.toString() ?? "Login successful";
      } else {
        // Ambil pesan error dari response
        final message = data['message'];
        String errorMessage;

        if (message == null) {
          errorMessage = 'Invalid credentials';
        } else if (message is String) {
          errorMessage = message;
        } else if (message is Map) {
          errorMessage = message.values.join(', ');
        } else {
          errorMessage = 'Invalid credentials';
        }

        return "Failed: $errorMessage";
      }
    } catch (e) {
      print("ERROR: Login - $e");
      return "An error occurred: $e";
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('userName');
  }
}
