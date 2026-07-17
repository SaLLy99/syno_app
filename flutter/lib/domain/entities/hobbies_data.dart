import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class Hobby {
  final int id;
  final String name;
  final String translationKey;
  Hobby({required this.id, required this.name, required this.translationKey});
  factory Hobby.fromJson(Map<String, dynamic> json) => Hobby(
        id: json['id'],
        name: json['name'],
        translationKey: json['translation_key'] as String? ?? json['translationKey'] as String? ?? '',
      );
}

class StaticDataService {
  final String _baseUrl = 'http://10.0.2.2:8000';

  Future<List<Hobby>> getHobbies() async {
    final http.Response response = await http.get(Uri.parse('$_baseUrl/api/hobbies/'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Hobby.fromJson(json)).toList();
    }
    throw Exception('Failed to load hobbies');
  }
}

final Provider<StaticDataService> hobbiesDataServiceProvider = Provider((Ref ref) => StaticDataService());
final FutureProvider<List<Hobby>> hobbiesProvider = FutureProvider((Ref ref) => ref.watch(hobbiesDataServiceProvider).getHobbies());