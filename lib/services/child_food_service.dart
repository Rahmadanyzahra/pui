import 'dart:convert';
import 'package:http/http.dart' as http;

class ChildFoodService {
  static const String baseUrl =
      'http://localhost:3000/api'; // Ganti sesuai endpoint Node.js Anda

  static Future<List<dynamic>> fetchFoods() async {
    final response = await http.get(Uri.parse('$baseUrl/child-food'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load child foods');
    }
  }

  static Future<bool> createFood(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/child-food'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return response.statusCode == 201;
  }

  static Future<bool> updateFood(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/child-food/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return response.statusCode == 200;
  }

  static Future<bool> deleteFood(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/child-food/$id'));
    return response.statusCode == 200;
  }
}
