import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/hobbies_data.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart'
    show ProfileData, hobbiesProvider, registrationProvider;
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';
import 'package:syno_app/presentation/widgets/selectable_option_card.dart';

class RegisterHobbiesScreen extends ConsumerStatefulWidget {
  const RegisterHobbiesScreen({super.key});

  @override
  ConsumerState<RegisterHobbiesScreen> createState() =>
      _RegisterHobbiesScreenState();
}

class _RegisterHobbiesScreenState extends ConsumerState<RegisterHobbiesScreen> {
  final Set<int> _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    final ProfileData regState = ref.read(registrationProvider).profileData;
    _selectedIds.addAll(regState.hobbyIds);
    }

  void _onNext() {
    ref.read(registrationProvider.notifier).updateProfileData(<String, dynamic>{
      'hobby_ids': _selectedIds.toList(),
    });
    context.push('/register-career');
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Hobby>> hobbiesAsync = ref.watch(hobbiesProvider);

    return OnboardingScaffold(
      title: 'register.hobbies_title'.tr(),
      progress: 7 / 9,
      onContinue: _onNext,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('register.hobbies_subtitle'.tr(),
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            hobbiesAsync.when(
              data: (List<Hobby> hobbies) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: hobbies.map((Hobby hobby) {
                  final bool isSelected = _selectedIds.contains(hobby.id);
                  final String label = hobby.translationKey.isNotEmpty && hobby.translationKey.tr() != hobby.translationKey
                      ? hobby.translationKey.tr() : hobby.name;
                  return SelectableOptionCard(
                    selected: isSelected,
                    label: label,
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
              error: (Object err, _) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
