import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/data/services/preferences_service.dart';
import 'package:syno_app/domain/entities/user_preferences.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';

final Provider<PreferencesService> preferencesServiceProvider =
    Provider<PreferencesService>((Ref ref) => PreferencesService());

final StateNotifierProvider<PreferencesNotifier, AsyncValue<DiscoverPreferences>>
    preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, AsyncValue<DiscoverPreferences>>(
  (Ref ref) => PreferencesNotifier(ref),
);

class PreferencesNotifier extends StateNotifier<AsyncValue<DiscoverPreferences>> {
  final Ref ref;

  PreferencesNotifier(this.ref) : super(const AsyncValue<DiscoverPreferences>.loading()) {
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    state = const AsyncValue<DiscoverPreferences>.loading();
    try {
      final SharedPreferences storage = await SharedPreferences.getInstance();
      final String? token = storage.getString('auth_token');
      final backendUrl = ref.read(backendUrlProvider);
      final service = ref.read(preferencesServiceProvider);
      final prefs = await service.getPreferences(token, backendUrl);
      state = AsyncValue<DiscoverPreferences>.data(prefs);
    } catch (e, st) {
      state = AsyncValue<DiscoverPreferences>.error(e, st);
    }
  }

  Future<void> updatePreferences(DiscoverPreferences newPrefs) async {
    try {
      final SharedPreferences storage = await SharedPreferences.getInstance();
      final String? token = storage.getString('auth_token');
      final backendUrl = ref.read(backendUrlProvider);
      final service = ref.read(preferencesServiceProvider);
      final updated = await service.updatePreferences(
        newPrefs,
        token,
        backendUrl,
      );
      state = AsyncValue<DiscoverPreferences>.data(updated);
    } catch (e, st) {
      state = AsyncValue<DiscoverPreferences>.error(e, st);
    }
  }

  Future<void> updateWeight(String key, double value) async {
    final current = state.value ?? const DiscoverPreferences();
    final newWeights = Map<String, double>.from(current.weights);
    newWeights[key] = value;
    await updatePreferences(current.copyWith(weights: newWeights));
  }
}
