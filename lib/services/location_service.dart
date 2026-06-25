import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  static const String baseUrl =
      'http://localhost:3000/api'; // Ganti sesuai endpoint Node.js Anda

  static Future<List<dynamic>> fetchLocations() async {
    final response = await http.get(Uri.parse('$baseUrl/location'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load locations');
    }
  }

  static Future<bool> createLocation(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/location'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return response.statusCode == 201;
  }

  static Future<bool> updateLocation(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/location/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return response.statusCode == 200;
  }

  static Future<bool> deleteLocation(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/location/$id'));
    return response.statusCode == 200;
  }
}
