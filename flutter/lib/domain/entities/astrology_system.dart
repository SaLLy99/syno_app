import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AstrologySystem {
  western('Western', 'Tropical Zodiac');

  final String label;
  final String description;
  const AstrologySystem(this.label, this.description);
}

class AstrologySystemNotifier extends StateNotifier<AstrologySystem> {
  AstrologySystemNotifier() : super(AstrologySystem.western) {
    _load();
  }

  static const String _key = 'astrology_system';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_key);
    if (stored != null) {
      try {
        state = AstrologySystem.values.firstWhere((e) => e.name == stored);
      } catch (_) {
        state = AstrologySystem.western;
      }
    }
  }

  Future<void> setSystem(AstrologySystem system) async {
    state = system;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, system.name);
  }
}

final astrologySystemProvider = StateNotifierProvider<AstrologySystemNotifier, AstrologySystem>((ref) {
  return AstrologySystemNotifier();
});
