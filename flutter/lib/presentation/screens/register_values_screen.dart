import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/screens/register_screen2.dart'; // For coreValuesProvider
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';
import 'package:syno_app/presentation/widgets/selectable_option_card.dart';

class RegisterValuesScreen extends ConsumerStatefulWidget {
  const RegisterValuesScreen({super.key});

  @override
  ConsumerState<RegisterValuesScreen> createState() =>
      _RegisterValuesScreenState();
}

class _RegisterValuesScreenState extends ConsumerState<RegisterValuesScreen> {
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    final regState = ref.read(registrationProvider).profileData;
    if (regState.coreValueIds != null) {
      _selectedIds.addAll(regState.coreValueIds!);
    }
  }

  void _onNext() {
    ref.read(registrationProvider.notifier).updateProfileData({
      'core_value_ids': _selectedIds.toList(),
    });
    context.push('/register-hobbies');
  }

  @override
  Widget build(BuildContext context) {
    final coreValuesAsync = ref.watch(coreValuesProvider);

    return OnboardingScaffold(
      title: 'register.core_values_title'.tr(),
      progress: 6 / 9,
      onContinue: _onNext,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('register.core_values_subtitle'.tr(),
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            coreValuesAsync.when(
              data: (values) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: values.map((value) {
                  final isSelected = _selectedIds.contains(value.id);
                  return SelectableOptionCard(
                    selected: isSelected,
                    label: value.translationKey.tr(),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(value.id);
                        } else if (_selectedIds.length < 5) {
                          _selectedIds.add(value.id);
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
