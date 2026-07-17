import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:syno_app/data/services/user_service.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:dio/dio.dart' as dio;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/user_state_notifier.dart'; 

/// Provides an instance of [UserService].
final Provider<UserService> userServiceProvider = Provider<UserService>((Ref ref) {
  return UserService(ref.watch(backendUrlProvider));
});


final StateNotifierProvider<UserStateNotifier, AsyncValue<User?>> currentUserProvider =
    StateNotifierProvider<UserStateNotifier, AsyncValue<User?>>(
        (Ref ref) => UserStateNotifier(ref));


final FutureProvider<List<User>> allUsersProvider = FutureProvider<List<User>>((Ref ref) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');
  if (token == null || token.isEmpty) return <User>[];

  final String backendUrl = ref.watch(backendUrlProvider);
  final String url = '$backendUrl/api/discover';

  try {
    final dio.Response response = await dio.Dio().get(
      url,
      options: dio.Options(headers: <String, dynamic>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }),
    );

    if (response.statusCode == 200) {
      final List<dynamic> usersJson = response.data as List<dynamic>;
      final List<User> users = usersJson
          .map((dynamic json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
      debugPrint('[allUsersProvider] Loaded ${users.length} profiles from /api/discover');
      return users;
    } else {
      debugPrint('[allUsersProvider] Failed: ${response.statusCode}');
      return <User>[];
    }
  } catch (e) {
    debugPrint('[allUsersProvider] Error: $e');
    return <User>[];
  }
});
