import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:syno_app/domain/entities/app_mode.dart';

const String _kModeStorageKey = 'app_mode';

class AppModeNotifier extends StateNotifier<AppMode> {
  final Ref ref;
  
  AppModeNotifier(this.ref) : super(AppMode.dating) {
    _loadMode();
  }

  Future<void> _loadMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? savedMode = prefs.getString(_kModeStorageKey);
    if (savedMode != null) {
      state = AppModeExtension.fromString(savedMode);
    }
  }

  Future<void> switchMode(AppMode newMode) async {
    if (state == newMode) return;
    
    state = newMode;
    
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModeStorageKey, newMode.value);

    // Sync with backend
    try {
      final String? backendUrl = prefs.getString('backend_url');
      final String? token = prefs.getString('access_token');
      if (backendUrl != null && token != null) {
        final Dio dio = Dio(BaseOptions(baseUrl: backendUrl));
        await dio.post(
          '/api/mode/switch',
          data: {'mode': newMode.value},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }
    } catch (e) {
      debugPrint('[AppMode] Failed to sync mode with backend: $e');
    }
  }
}

final appModeProvider = StateNotifierProvider<AppModeNotifier, AppMode>((Ref ref) {
  return AppModeNotifier(ref);
});
