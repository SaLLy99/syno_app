import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/profile_options.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/screens/register_screen2.dart';
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';
import 'package:syno_app/presentation/widgets/selectable_option_card.dart';
import 'package:syno_app/presentation/utils/emoji_mappings.dart';

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
    final AsyncValue<List<Intention>> intentionsAsync =
        ref.watch(intentionsProvider);

    return OnboardingScaffold(
      title: 'register.intentions_title'.tr(),
      progress: 6 / 10,
      onContinue: _onNext,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('register.intentions_subtitle'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            Expanded(
              child: intentionsAsync.when(
                data: (List<Intention> intentions) {
                  // Sort: selected first
                  final List<Intention> sorted = List<Intention>.from(intentions)
                    ..sort((Intention a, Intention b) {
                      final bool aSel = _selectedIds.contains(a.id);
                      final bool bSel = _selectedIds.contains(b.id);
                      if (aSel && !bSel) return -1;
                      if (!aSel && bSel) return 1;
                      return 0;
                    });

                  return GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: sorted.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Intention intention = sorted[index];
                      final bool isSelected =
                          _selectedIds.contains(intention.id);
                      final String? emoji = EmojiMappings.lookup(
                          intention.translationKey, EmojiMappings.intentions);

                      return SelectableOptionCard(
                        selected: isSelected,
                        label: intention.translationKey.tr(),
                        emoji: emoji,
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
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object err, _) => Text('Error: $err'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
