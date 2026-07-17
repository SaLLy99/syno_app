import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/profile_options.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/screens/register_screen2.dart'; // For intentionsProvider
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';
import 'package:syno_app/presentation/widgets/selectable_option_card.dart';

class RegisterIntentionsScreen extends ConsumerStatefulWidget {
  const RegisterIntentionsScreen({super.key});

  @override
  ConsumerState<RegisterIntentionsScreen> createState() =>
      _RegisterIntentionsScreenState();
}

class _RegisterIntentionsScreenState
    extends ConsumerState<RegisterIntentionsScreen> {
  final Set<int> _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    final ProfileData regState = ref.read(registrationProvider).profileData;
    _selectedIds.addAll(regState.intentionIds);
    }

  void _onNext() {
    ref.read(registrationProvider.notifier).updateProfileData(<String, dynamic>{
      'intention_ids': _selectedIds.toList(),
    });
    context.push('/register-values');
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Intention>> intentionsAsync = ref.watch(intentionsProvider);

    return OnboardingScaffold(
      title: 'register.intentions_title'.tr(),
      progress: 5 / 9,
      onContinue: _onNext,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('register.intentions_subtitle'.tr(),
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            intentionsAsync.when(
              data: (List<Intention> intentions) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: intentions.map((Intention intention) {
                  final bool isSelected = _selectedIds.contains(intention.id);
                  return SelectableOptionCard(
                    selected: isSelected,
                    label: intention.translationKey.tr(),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(intention.id);
                        } else {
                          _selectedIds.add(intention.id);
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
