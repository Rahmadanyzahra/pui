import 'dart:convert';
import 'package:http/http.dart' as http;

class PermissionService {
  static const String baseUrl =
      'http://localhost:3000/api'; // Ganti sesuai endpoint Node.js Anda

  static Future<List<dynamic>> fetchPermissions() async {
    final response = await http.get(Uri.parse('$baseUrl/permission'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load permissions');
    }
  }

  static Future<bool> createPermission(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/permission'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return response.statusCode == 201;
  }

  static Future<bool> updatePermission(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/permission/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return response.statusCode == 200;
  }

  static Future<bool> deletePermission(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/permission/$id'));
    return response.statusCode == 200;
  }
}
