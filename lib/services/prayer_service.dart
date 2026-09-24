import 'dart:convert';
import 'package:http/http.dart' as http;

class PrayerService {
  static const String baseUrl = 'https://ezan-vakitleri.herokuapp.com';

  static Future<List<dynamic>> getCities() async {
    final response = await http.get(Uri.parse('$baseUrl/cities'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Şehirler yüklenemedi');
    }
  }

  static Future<Map<String, dynamic>> getPrayerTimes(String city) async {
    final response = await http.get(Uri.parse('$baseUrl/times?city=$city'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Vakitler yüklenemedi');
    }
  }
}
