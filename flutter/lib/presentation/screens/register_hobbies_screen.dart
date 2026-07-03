import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/hobbies_data.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart'
    show hobbiesProvider, registrationProvider;
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';
import 'package:syno_app/presentation/widgets/selectable_option_card.dart';

class RegisterHobbiesScreen extends ConsumerStatefulWidget {
  const RegisterHobbiesScreen({super.key});

  @override
  ConsumerState<RegisterHobbiesScreen> createState() =>
      _RegisterHobbiesScreenState();
}

class _RegisterHobbiesScreenState extends ConsumerState<RegisterHobbiesScreen> {
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    final regState = ref.read(registrationProvider).profileData;
    if (regState.hobbyIds != null) {
      _selectedIds.addAll(regState.hobbyIds!);
    }
  }

  void _onNext() {
    ref.read(registrationProvider.notifier).updateProfileData({
      'hobby_ids': _selectedIds.toList(),
    });
    context.push('/register-career');
  }

  @override
  Widget build(BuildContext context) {
    final hobbiesAsync = ref.watch(hobbiesProvider);

    return OnboardingScaffold(
      title: 'register.hobbies_title'.tr(),
      progress: 7 / 9,
      onContinue: _onNext,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('register.hobbies_subtitle'.tr(),
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            hobbiesAsync.when(
              data: (hobbies) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: hobbies.map((hobby) {
                  final isSelected = _selectedIds.contains(hobby.id);
                  return SelectableOptionCard(
                    selected: isSelected,
                    label: hobby.name,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(hobby.id);
                        } else {
                          _selectedIds.add(hobby.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
