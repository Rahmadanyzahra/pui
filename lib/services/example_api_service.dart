import 'dart:convert';
import 'package:http/http.dart' as http;

class ExampleApiService {
  static const String baseUrl =
      'http://localhost:3000/api'; // Ganti sesuai endpoint Node.js Anda

  // Contoh GET
  static Future<List<dynamic>> fetchItems() async {
    final response = await http.get(Uri.parse('$baseUrl/items'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load items');
    }
  }

  // Contoh POST
  static Future<bool> createItem(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/items'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return response.statusCode == 201;
  }

  // Contoh PUT
  static Future<bool> updateItem(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/items/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return response.statusCode == 200;
  }

  // Contoh DELETE
  static Future<bool> deleteItem(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/items/$id'));
    return response.statusCode == 200;
  }
}
