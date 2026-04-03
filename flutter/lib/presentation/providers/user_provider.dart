import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/data/services/user_service.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:http/http.dart' as http;
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/user_state_notifier.dart'; 

/// Provides an instance of [UserService].
final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.watch(backendUrlProvider));
});


final currentUserProvider =
    StateNotifierProvider<UserStateNotifier, AsyncValue<User?>>(
        (ref) => UserStateNotifier(ref));


final allUsersProvider = FutureProvider<List<User>>((ref) async {
  final url = Uri.parse('${ref.watch(backendUrlProvider)}/users/');
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final List<dynamic> usersJson = json.decode(response.body);
    return usersJson.map((json) => User.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load users');
  }
});

