import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/screens/register_screen2.dart';
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';
import 'package:syno_app/presentation/widgets/selectable_option_card.dart';
import 'package:syno_app/presentation/utils/emoji_mappings.dart';
import 'package:syno_app/theme.dart';

class RegisterValuesScreen extends ConsumerStatefulWidget {
  const RegisterValuesScreen({super.key});

  @override
  ConsumerState<RegisterValuesScreen> createState() =>
      _RegisterValuesScreenState();
}

class _RegisterValuesScreenState extends ConsumerState<RegisterValuesScreen> {
  final Set<int> _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    final ProfileData regState = ref.read(registrationProvider).profileData;
    _selectedIds.addAll(regState.coreValueIds);
  }

  void _onNext() {
    ref.read(registrationProvider.notifier).updateProfileData(<String, dynamic>{
      'core_value_ids': _selectedIds.toList(),
    });
    context.push('/register-hobbies');
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CoreValue>> coreValuesAsync =
        ref.watch(coreValuesProvider);

    return OnboardingScaffold(
      title: 'register.core_values_title'.tr(),
      progress: 6 / 9,
      onContinue: _onNext,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('register.core_values_subtitle'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            _buildSelectionCounter(),
            const SizedBox(height: 16),
            Expanded(
              child: coreValuesAsync.when(
                data: (List<CoreValue> values) {
                  // Sort: selected first, then unselected
                  final List<CoreValue> sorted = List<CoreValue>.from(values)
                    ..sort((CoreValue a, CoreValue b) {
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
                      final CoreValue value = sorted[index];
                      final bool isSelected = _selectedIds.contains(value.id);
                      final String? emoji = EmojiMappings.lookup(
                          value.translationKey, EmojiMappings.coreValues);

                      return SelectableOptionCard(
                        selected: isSelected,
                        label: value.translationKey.tr(),
                        emoji: emoji,
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

  Widget _buildSelectionCounter() {
    final int count = _selectedIds.length;
    const int max = 5;
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: count > 0
                ? CosmicColors.cosmicPink.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: count > 0
                  ? CosmicColors.cosmicPink.withOpacity(0.5)
                  : Colors.white.withOpacity(0.2),
            ),
          ),
          child: Text(
            '$count / $max selected',
            style: TextStyle(
              color: count > 0 ? CosmicColors.cosmicPink : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
