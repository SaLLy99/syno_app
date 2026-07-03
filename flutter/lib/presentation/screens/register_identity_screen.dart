import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/orientations_data.dart';
import 'package:syno_app/domain/entities/sexes_data.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';
import 'package:syno_app/presentation/widgets/selectable_option_card.dart';
import 'package:syno_app/theme.dart'; // For CosmicColors

// These providers are assumed to exist based on RegisterScreen2 context
final sexesProvider = FutureProvider<List<Sex>>((ref) async {
  // Mock data or actual service call
  return [
    Sex(id: 1, name: 'Male', translationKey: 'sex.male'),
    Sex(id: 2, name: 'Female', translationKey: 'sex.female'),
    Sex(id: 3, name: 'Non-binary', translationKey: 'sex.non_binary'),
  ];
});

final orientationsProvider = FutureProvider<List<Orientations>>((ref) async {
  // Mock data or actual service call
  return [
    Orientations(
        id: 1, name: 'Straight', translationKey: 'orientation.straight'),
    Orientations(id: 2, name: 'Gay', translationKey: 'orientation.gay'),
    Orientations(id: 3, name: 'Lesbian', translationKey: 'orientation.lesbian'),
    Orientations(
        id: 4, name: 'Bisexual', translationKey: 'orientation.bisexual'),
    Orientations(
        id: 5, name: 'Pansexual', translationKey: 'orientation.pansexual'),
  ];
});

class RegisterIdentityScreen extends ConsumerStatefulWidget {
  const RegisterIdentityScreen({super.key});

  @override
  ConsumerState<RegisterIdentityScreen> createState() =>
      _RegisterIdentityScreenState();
}

class _RegisterIdentityScreenState
    extends ConsumerState<RegisterIdentityScreen> {
  int? _selectedGenderId;
  int? _selectedOrientationId;

  @override
  void initState() {
    super.initState();
    final regState = ref.read(registrationProvider).profileData;
    _selectedGenderId = regState.sexId;
    _selectedOrientationId = regState.orientationId;
  }

  void _onNext() {
    if (_selectedGenderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('register.errors.gender_required'.tr())),
      );
      return;
    }

    if (_selectedOrientationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('register.errors.orientation_required'.tr())),
      );
      return;
    }

    ref.read(registrationProvider.notifier).updateProfileData({
      'sex_id': _selectedGenderId,
      'orientation_id': _selectedOrientationId,
    });
    context.push('/register-birth'); // Corrected navigation
  }

  @override
  Widget build(BuildContext context) {
    final sexesAsync = ref.watch(sexesProvider);
    final orientationsAsync = ref.watch(orientationsProvider);

    return OnboardingScaffold(
      title: 'register.identity_title'.tr(),
      progress: 3 / 9,
      onContinue: _onNext,
      canContinue: _selectedGenderId != null && _selectedOrientationId != null,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'register.identity_subtitle'.tr(),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 32),
            Text('register.gender_label'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            sexesAsync.when(
              data: (sexes) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: sexes.map((sex) {
                  final isSelected = _selectedGenderId == sex.id;
                  return SelectableOptionCard(
                    selected: isSelected,
                    label: sex.translationKey.tr(),
                    onTap: () => setState(() => _selectedGenderId = sex.id),
                  );
                }).toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error: $err'),
            ),
            const SizedBox(height: 28),
            Text('register.orientation_label'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            orientationsAsync.when(
              data: (orientations) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: orientations.map((orientation) {
                  final isSelected = _selectedOrientationId == orientation.id;
                  return SelectableOptionCard(
                    selected: isSelected,
                    label: orientation.translationKey.tr(),
                    onTap: () =>
                        setState(() => _selectedOrientationId = orientation.id),
                  );
                }).toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
