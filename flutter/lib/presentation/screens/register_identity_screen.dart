import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/orientations_data.dart';
import 'package:syno_app/domain/entities/sexes_data.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';
import 'package:syno_app/presentation/widgets/selectable_option_card.dart';
import 'package:syno_app/presentation/utils/emoji_mappings.dart';

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
  bool _showMoreGenders = false;
  bool _showMoreOrientations = false;

  // Main gender options (shown first)
  static const List<String> _mainGenderKeys = <String>[
    'Male',
    'Female',
  ];

  // Main orientation options (shown first)
  static const List<String> _mainOrientationKeys = <String>[
    'Straight',
    'Gay',
    'Lesbian',
    'Bisexual',
    'Pansexual',
  ];

  @override
  void initState() {
    super.initState();
    final ProfileData regState = ref.read(registrationProvider).profileData;
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
    ref.read(registrationProvider.notifier).updateProfileData(<String, dynamic>{
      'sex_id': _selectedGenderId,
      'orientation_id': _selectedOrientationId,
    });
    context.push('/register-birth');
  }

  bool _isMainGender(Sex sex) => _mainGenderKeys.contains(sex.name);
  bool _isMainOrientation(Orientations o) =>
      _mainOrientationKeys.contains(o.name);

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Sex>> sexesAsync = ref.watch(sexesProvider);
    final AsyncValue<List<Orientations>> orientationsAsync =
        ref.watch(orientationsProvider);

    return OnboardingScaffold(
      title: 'register.identity_title'.tr(),
      progress: 4 / 10,
      onContinue: _onNext,
      canContinue: _selectedGenderId != null && _selectedOrientationId != null,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'register.identity_subtitle'.tr(),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // ── I AM (Gender) ──
            Text('register.gender_label'.tr(),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            sexesAsync.when(
              data: (List<Sex> sexes) {
                // Check if selected gender is in the "other" list
                final Sex? selected =
                    sexes.where((s) => s.id == _selectedGenderId).firstOrNull;
                final bool selectedIsOther =
                    selected != null && !_isMainGender(selected);

                // Main 3 buttons: Male, Female, Other
                final List<Sex> mainOptions =
                    sexes.where((s) => _isMainGender(s)).toList();
                final List<Sex> otherOptions =
                    sexes.where((s) => !_isMainGender(s)).toList();

                // "Other" is selected or expanded
                final bool otherActive =
                    _showMoreGenders || selectedIsOther;

                return Column(
                  children: <Widget>[
                    // Main buttons row
                    Row(
                      children: <Widget>[
                        for (final Sex s in mainOptions) ...<Widget>[
                          Expanded(
                            child: _MainOptionButton(
                              emoji: EmojiMappings.lookup(
                                      s.translationKey, EmojiMappings.sexes) ??
                                  '',
                              label: s.translationKey.tr(),
                              selected: _selectedGenderId == s.id,
                              onTap: () =>
                                  setState(() => _selectedGenderId = s.id),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // "Other" button
                        Expanded(
                          child: _MainOptionButton(
                            emoji: otherActive ? '✨' : '🌈',
                            label: 'Other',
                            selected: otherActive,
                            onTap: () => setState(() {
                              _showMoreGenders = !_showMoreGenders;
                            }),
                          ),
                        ),
                      ],
                    ),

                    // Expanded other options
                    if (otherActive) ...<Widget>[
                      const SizedBox(height: 12),
                      GridView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: otherOptions.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Sex sex = otherOptions[index];
                          final bool isSel = _selectedGenderId == sex.id;
                          final String? emoji = EmojiMappings.lookup(
                              sex.translationKey, EmojiMappings.sexes);
                          return SelectableOptionCard(
                            selected: isSel,
                            label: sex.translationKey.tr(),
                            emoji: emoji,
                            onTap: () =>
                                setState(() => _selectedGenderId = sex.id),
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (Object err, _) => Text('Error: $err'),
            ),
            const SizedBox(height: 24),

            // ── LOOKING FOR (Orientation) ──
            Text('register.orientation_label'.tr(),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            orientationsAsync.when(
              data: (List<Orientations> orientations) {
                // Check if selected is in the hidden list
                final Orientations? selected = orientations
                    .where((o) => o.id == _selectedOrientationId)
                    .firstOrNull;
                final bool selectedIsHidden =
                    selected != null && !_isMainOrientation(selected);

                final List<Orientations> mainOpts =
                    orientations.where((o) => _isMainOrientation(o)).toList();
                final List<Orientations> moreOpts =
                    orientations.where((o) => !_isMainOrientation(o)).toList();

                final bool moreActive =
                    _showMoreOrientations || selectedIsHidden;

                return Column(
                  children: <Widget>[
                    // Main options (2-col grid)
                    GridView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: mainOpts.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Orientations o = mainOpts[index];
                        final bool isSel = _selectedOrientationId == o.id;
                        final String? emoji = EmojiMappings.lookup(
                            o.translationKey, EmojiMappings.orientations);
                        return SelectableOptionCard(
                          selected: isSel,
                          label: o.translationKey.tr(),
                          emoji: emoji,
                          onTap: () => setState(
                              () => _selectedOrientationId = o.id),
                        );
                      },
                    ),

                    // Show more / Show less
                    if (moreOpts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => setState(
                            () => _showMoreOrientations = !_showMoreOrientations),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              moreActive
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              moreActive
                                  ? 'Show less'
                                  : 'Show ${moreOpts.length} more options',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Expanded more options
                    if (moreActive) ...<Widget>[
                      const SizedBox(height: 12),
                      GridView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: moreOpts.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Orientations o = moreOpts[index];
                          final bool isSel = _selectedOrientationId == o.id;
                          final String? emoji = EmojiMappings.lookup(
                              o.translationKey, EmojiMappings.orientations);
                          return SelectableOptionCard(
                            selected: isSel,
                            label: o.translationKey.tr(),
                            emoji: emoji,
                            onTap: () => setState(
                                () => _selectedOrientationId = o.id),
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (Object err, _) => Text('Error: $err'),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

/// Big tappable button for the main gender options (Male / Female / Other).
class _MainOptionButton extends StatelessWidget {
  const _MainOptionButton({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
