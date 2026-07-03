import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;



class Orientations {
  final int id;
  final String name;
  final String translationKey;
  Orientations({required this.id, required this.name, required this.translationKey});
  factory Orientations.fromJson(Map<String, dynamic> json) => Orientations(
        id: json['id'],
        translationKey: 'orientation',
        name: json['name']
      );
}
class StaticDataService {
  final String _baseUrl = 'http://10.0.2.2:8000';


  Future<List<Orientations>> getOrientations() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/orientations/'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Orientations.fromJson(json)).toList();
    }
    throw Exception('Failed to load orientations');
  }

}
final OrientationProvider = Provider((ref) => StaticDataService());
final orientationsProvider = FutureProvider((ref) => ref.watch(OrientationProvider).getOrientations());