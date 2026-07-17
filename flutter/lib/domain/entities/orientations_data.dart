import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;



class Orientations {
  final int id;
  final String name;
  final String translationKey;
  Orientations({required this.id, required this.name, required this.translationKey});
  factory Orientations.fromJson(Map<String, dynamic> json) => Orientations(
        id: json['id'],
        name: json['name'],
        translationKey: json['translation_key'] as String? ?? json['translationKey'] as String? ?? '',
      );
}
class StaticDataService {
  final String _baseUrl = 'http://10.0.2.2:8000';


  Future<List<Orientations>> getOrientations() async {
    final http.Response response = await http.get(Uri.parse('$_baseUrl/api/orientations/'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Orientations.fromJson(json)).toList();
    }
    throw Exception('Failed to load orientations');
  }

}
final Provider<StaticDataService> OrientationProvider = Provider((Ref ref) => StaticDataService());
final FutureProvider<List<Orientations>> orientationsProvider = FutureProvider((Ref ref) => ref.watch(OrientationProvider).getOrientations());