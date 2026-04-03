import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class Hobby {
  final int id;
  final String name;
  Hobby({required this.id, required this.name});
  factory Hobby.fromJson(Map<String, dynamic> json) => Hobby(id: json['id'], name: json['name']);
}

class StaticDataService {
  final String _baseUrl = 'http://10.0.2.2:8000';

  Future<List<Hobby>> getHobbies() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/hobbies/'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Hobby.fromJson(json)).toList();
    }
    throw Exception('Failed to load hobbies');
  }
}

final hobbiesDataServiceProvider = Provider((ref) => StaticDataService());
final hobbiesProvider = FutureProvider((ref) => ref.watch(hobbiesDataServiceProvider).getHobbies());