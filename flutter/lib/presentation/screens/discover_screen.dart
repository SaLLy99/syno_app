import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/match.dart';
import 'package:syno_app/domain/entities/user_preferences.dart';
import 'package:syno_app/presentation/providers/match_provider.dart';
import 'package:syno_app/presentation/providers/preferences_provider.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/widgets/match_found_dialog.dart';
import 'package:syno_app/presentation/widgets/swipeable_card.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Match>> potentialMatchesAsync = ref.watch(potentialMatchesProvider);
    final AppThemeData theme = ref.watch(themeProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: SizedBox(
                width: 30,
                height: 30,
                child: ClipOval(
                  child: Image.asset(
                    'assets/icons/dreamflow_icon.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Text(
              'discover.title'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: Colors.white.withOpacity(0.8)),
            onPressed: () => _showPreferencesSheet(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: <Color>[
                      const Color(0xFFDB2777).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: potentialMatchesAsync.when(
                data: (List<Match> matches) {
                  if (matches.isEmpty) {
                    return _buildEmptyState(context);
                  }
                  return _buildMatchCards(context, matches);
                },
                loading: () => Center(
                  child: Text(
                    'discover.loading'.tr(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                error: (Object error, StackTrace stack) => Center(
                  child: Text(
                    'discover.error_subtitle'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCards(BuildContext context, List<Match> matches) {
    if (_currentIndex >= matches.length) {
      return _buildEmptyState(context);
    }

    final AsyncValue<Set<int>> likedIdsAsync = ref.watch(likedUserIdsProvider);
    final Set<int> likedIds = likedIdsAsync.value ?? <int>{};

    return Stack(
      children: <Widget>[
        for (int i = _currentIndex; i < (_currentIndex + 2).clamp(0, matches.length); i++)
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md + (i - _currentIndex) * 8,
                right: AppSpacing.md + (i - _currentIndex) * 8,
                top: AppSpacing.md + (i - _currentIndex) * 8,
                bottom: 120 + (i - _currentIndex) * 8,
              ),
              child: SwipeableCard(
                match: matches[i],
                isTopCard: i == _currentIndex,
                likedByUser: likedIds.contains(matches[i].matchedUser.userId),
                onLike: () async {
                  final bool isMutual = await ref.read(matchActionsProvider).saveMatch(
                    matches[i].copyWith(status: MatchStatus.accepted),
                  );
                  setState(() => _currentIndex++);
                  if (isMutual && context.mounted) {
                    MatchFoundDialog.show(
                      context,
                      matchedUser: matches[i].matchedUser,
                      match: matches[i],
                      baseUrl: ref.read(backendUrlProvider),
                    );
                  }
                },
                onPass: () async {
                  await ref.read(matchActionsProvider).passMatch(
                    matches[i].copyWith(status: MatchStatus.declined),
                  );
                  setState(() => _currentIndex++);
                },
                onViewProfile: () {
                  context.push('/match-details', extra: matches[i]);
                },
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: _buildActionButtons(matches[_currentIndex]),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Match match) {
    return Padding(
      padding: AppSpacing.horizontalXl,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _buildActionButton(
            icon: Icons.close,
            color: Colors.red,
            size: 64,
            onPressed: () async {
              await ref.read(matchActionsProvider).passMatch(
                match.copyWith(status: MatchStatus.declined),
              );
              setState(() => _currentIndex++);
            },
          ),
          const SizedBox(width: 48),
          _buildActionButton(
            icon: Icons.favorite,
            color: CosmicColors.cosmicPink,
            size: 72,
            onPressed: () async {
              final bool isMutual = await ref.read(matchActionsProvider).saveMatch(
                match.copyWith(status: MatchStatus.accepted),
              );
              setState(() => _currentIndex++);
              if (isMutual && context.mounted) {
                MatchFoundDialog.show(
                  context,
                  matchedUser: match.matchedUser,
                  match: match,
                  baseUrl: ref.read(backendUrlProvider),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 64,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: size * 0.5),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: const Icon(Icons.favorite_border, size: 64, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'discover.no_matches_title'.tr(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'discover.no_matches_subtitle'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showPreferencesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PreferencesBottomSheet(),
    );
  }
}

class _PreferencesBottomSheet extends ConsumerStatefulWidget {
  const _PreferencesBottomSheet();

  @override
  ConsumerState<_PreferencesBottomSheet> createState() => _PreferencesBottomSheetState();
}

class _PreferencesBottomSheetState extends ConsumerState<_PreferencesBottomSheet> {
  late DiscoverPreferences _prefs;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _prefs = ref.read(preferencesProvider).value ?? const DiscoverPreferences();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A0B2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Discover Preferences',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: CosmicColors.cosmicPurple,
                              ),
                            )
                          : const Text(
                              'Apply',
                              style: TextStyle(
                                color: CosmicColors.cosmicPurple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildQuickSection('Basic Filters', Icons.tune, [
                      _buildAgeRange(),
                      _buildDistanceSlider(),
                      _buildGenderChips(),
                      _buildOrientationChips(),
                      _buildLookingForChips(),
                      _buildSwitchRow('Verified only', _prefs.verifiedOnly,
                          (v) => setState(() => _prefs = _prefs.copyWith(verifiedOnly: v))),
                      _buildSwitchRow('Online recently', _prefs.onlineRecently,
                          (v) => setState(() => _prefs = _prefs.copyWith(onlineRecently: v))),
                    ]),
                    const SizedBox(height: 12),
                    _buildQuickSection('Astrology', Icons.auto_awesome, [
                      _buildMinCompatibility(),
                      _buildPriorityChips(),
                      _buildWeightSliders(),
                      _buildBirthTimeRequirement(),
                    ]),
                    const SizedBox(height: 12),
                    _buildQuickSection('Lifestyle', Icons.favorite_border, [
                      _buildLifestyleDropdown('Wants children', Icons.child_care,
                          ['yes', 'no', 'open', 'undecided'], _prefs.wantsChildren,
                          (v) => setState(() => _prefs = _prefs.copyWith(wantsChildren: v))),
                      _buildLifestyleDropdown('Smoking', Icons.smoking_rooms,
                          ['non_smoker', 'social', 'regular'], _prefs.smoking,
                          (v) => setState(() => _prefs = _prefs.copyWith(smoking: v))),
                      _buildLifestyleDropdown('Drinking', Icons.local_bar,
                          ['non_drinker', 'social', 'regular'], _prefs.drinking,
                          (v) => setState(() => _prefs = _prefs.copyWith(drinking: v))),
                      _buildLifestyleDropdown('Religion', Icons.temple_buddhist,
                          ['christianity', 'islam', 'judaism', 'hinduism', 'buddhism', 'agnostic', 'atheist', 'spiritual', 'other'],
                          _prefs.religion, (v) => setState(() => _prefs = _prefs.copyWith(religion: v))),
                      _buildLifestyleDropdown('Political', Icons.account_balance,
                          ['liberal', 'conservative', 'moderate', 'apolitical', 'other'],
                          _prefs.political, (v) => setState(() => _prefs = _prefs.copyWith(political: v))),
                      _buildHeightRange(),
                    ]),
                    const SizedBox(height: 12),
                    _buildQuickSection('Advanced', Icons.settings, [
                      _buildSwitchRow('Hide swiped', _prefs.hideSwiped,
                          (v) => setState(() => _prefs = _prefs.copyWith(hideSwiped: v))),
                      _buildSwitchRow('Hide inactive users', _prefs.hideInactive,
                          (v) => setState(() => _prefs = _prefs.copyWith(hideInactive: v))),
                      _buildSwitchRow('Show users traveling nearby', _prefs.showTraveling,
                          (v) => setState(() => _prefs = _prefs.copyWith(showTraveling: v))),
                      _buildSwitchRow('Global search', _prefs.globalSearch,
                          (v) => setState(() => _prefs = _prefs.copyWith(globalSearch: v))),
                      _buildSwitchRow('Photos only', _prefs.photosOnly,
                          (v) => setState(() => _prefs = _prefs.copyWith(photosOnly: v))),
                      _buildSwitchRow('Complete profiles', _prefs.completeProfilesOnly,
                          (v) => setState(() => _prefs = _prefs.copyWith(completeProfilesOnly: v))),
                    ]),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await ref.read(preferencesProvider.notifier).updatePreferences(_prefs);
    ref.invalidate(potentialMatchesProvider);
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  Widget _buildQuickSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CosmicColors.cosmicPink, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildAgeRange() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Age range', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
            Text(
              '${_prefs.minAge} - ${_prefs.maxAge}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        RangeSlider(
          values: RangeValues(_prefs.minAge.toDouble(), _prefs.maxAge.toDouble()),
          min: 18,
          max: 65,
          activeColor: CosmicColors.cosmicPurple,
          inactiveColor: Colors.white.withValues(alpha: 0.15),
          onChanged: (RangeValues values) {
            setState(() {
              _prefs = _prefs.copyWith(
                minAge: values.start.toInt(),
                maxAge: values.end.toInt(),
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildDistanceSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Distance', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
            Text(
              _prefs.maxDistance >= 500 ? '500+ km' : '${_prefs.maxDistance} km',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        Slider(
          value: _prefs.maxDistance.toDouble(),
          min: 5,
          max: 500,
          activeColor: CosmicColors.cosmicPurple,
          inactiveColor: Colors.white.withValues(alpha: 0.15),
          onChanged: (double value) {
            setState(() {
              _prefs = _prefs.copyWith(maxDistance: value.toInt());
            });
          },
        ),
      ],
    );
  }

  Widget _buildGenderChips() {
    const List<String> options = <String>['Male', 'Female', 'Non-binary'];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        Text('Show me:', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
        ...options.map((String g) => FilterChip(
          label: Text(g, style: const TextStyle(fontSize: 12)),
          selected: _prefs.genders.contains(g),
          onSelected: (bool selected) {
            setState(() {
              final List<String> newGenders = List<String>.from(_prefs.genders);
              if (selected) {
                newGenders.add(g);
              } else {
                newGenders.remove(g);
              }
              _prefs = _prefs.copyWith(genders: newGenders);
            });
          },
          selectedColor: CosmicColors.cosmicPurple,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          checkmarkColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        )),
      ],
    );
  }

  Widget _buildOrientationChips() {
    const List<String> options = <String>['Straight', 'Gay', 'Bisexual', 'Pansexual'];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        Text('Orientation:', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
        ...options.map((String o) => FilterChip(
          label: Text(o, style: const TextStyle(fontSize: 12)),
          selected: _prefs.orientations.contains(o),
          onSelected: (bool selected) {
            setState(() {
              final List<String> newOrients = List<String>.from(_prefs.orientations);
              if (selected) {
                newOrients.add(o);
              } else {
                newOrients.remove(o);
              }
              _prefs = _prefs.copyWith(orientations: newOrients);
            });
          },
          selectedColor: CosmicColors.cosmicPink,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          checkmarkColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        )),
      ],
    );
  }

  Widget _buildLookingForChips() {
    const List<String> options = <String>['Dating', 'Long-term', 'Friendship', 'Networking'];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        Text('Looking for:', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
        ...options.map((String l) => FilterChip(
          label: Text(l, style: const TextStyle(fontSize: 12)),
          selected: _prefs.lookingFor.contains(l),
          onSelected: (bool selected) {
            setState(() {
              final List<String> newLooking = List<String>.from(_prefs.lookingFor);
              if (selected) {
                newLooking.add(l);
              } else {
                newLooking.remove(l);
              }
              _prefs = _prefs.copyWith(lookingFor: newLooking);
            });
          },
          selectedColor: CosmicColors.cosmicBlue,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          checkmarkColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        )),
      ],
    );
  }

  Widget _buildMinCompatibility() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Min compatibility', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
            Text(
              '${_prefs.minCompatibility}%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        Slider(
          value: _prefs.minCompatibility.toDouble(),
          min: 0,
          max: 95,
          activeColor: CosmicColors.cosmicPink,
          inactiveColor: Colors.white.withValues(alpha: 0.15),
          onChanged: (double value) {
            setState(() {
              _prefs = _prefs.copyWith(minCompatibility: value.toInt());
            });
          },
        ),
      ],
    );
  }

  Widget _buildPriorityChips() {
    final List<String> options = DiscoverPreferences.priorityTypes;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: options.map((String type) {
        final String label = DiscoverPreferences.priorityLabels[type] ?? type;
        final bool isSelected = _prefs.priorityType == type;
        return ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          selected: isSelected,
          onSelected: (bool selected) {
            if (selected) {
              setState(() => _prefs = _prefs.copyWith(priorityType: type));
            }
          },
          selectedColor: CosmicColors.cosmicPurple,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
          padding: const EdgeInsets.symmetric(horizontal: 6),
        );
      }).toList(),
    );
  }

  Widget _buildWeightSliders() {
    const List<String> weightKeys = <String>[
      'romance', 'emotional', 'communication', 'long_term',
      'marriage', 'friendship', 'chemistry', 'spiritual',
    ];

    return Column(
      children: weightKeys.map((String key) {
        final String label = DiscoverPreferences.priorityLabels[key] ?? key;
        final String icon = DiscoverPreferences.weightIcons[key] ?? '•';
        final double value = _prefs.weights[key] ?? 50;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 24,
                child: Text(icon, style: const TextStyle(fontSize: 14)),
              ),
              Expanded(
                flex: 2,
                child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
              ),
              Expanded(
                flex: 3,
                child: Slider(
                  value: value,
                  min: 0,
                  max: 100,
                  activeColor: CosmicColors.cosmicPurple,
                  inactiveColor: Colors.white.withValues(alpha: 0.15),
                  onChanged: (double v) {
                    setState(() {
                      final Map<String, double> newWeights = Map<String, double>.from(_prefs.weights);
                      newWeights[key] = v;
                      _prefs = _prefs.copyWith(weights: newWeights);
                    });
                  },
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${value.toInt()}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBirthTimeRequirement() {
    final Map<String, String> options = <String, String>{
      'exact': 'Exact birth time only',
      'optional': 'Birth time optional',
      'unknown': 'Unknown birth time accepted',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Birth time preference', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
        const SizedBox(height: 4),
        ...options.entries.map((MapEntry<String, String> e) => RadioListTile<String>(
          value: e.key,
          groupValue: _prefs.birthTimeRequirement,
          onChanged: (String? v) {
            if (v != null) {
              setState(() => _prefs = _prefs.copyWith(birthTimeRequirement: v));
            }
          },
          title: Text(e.value, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
          activeColor: CosmicColors.cosmicPurple,
          contentPadding: EdgeInsets.zero,
          dense: true,
        )),
      ],
    );
  }

  Widget _buildLifestyleDropdown(
    String label,
    IconData icon,
    List<String> options,
    String? currentValue,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          prefixIcon: Icon(icon, color: CosmicColors.cosmicPink, size: 20),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: CosmicColors.cosmicPurple),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dropdownColor: const Color(0xFF2D1B4E),
        style: const TextStyle(color: Colors.white),
        items: <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(value: null, child: Text('Any')),
          ...options.map((String o) => DropdownMenuItem<String>(
            value: o,
            child: Text(o.replaceAll('_', ' ').toUpperCase()),
          )),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildHeightRange() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Min height (cm)', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              const SizedBox(height: 4),
              TextFormField(
                keyboardType: TextInputType.number,
                initialValue: _prefs.minHeight?.toString() ?? '',
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Any',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (String v) {
                  setState(() => _prefs = _prefs.copyWith(
                    minHeight: int.tryParse(v),
                  ));
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Max height (cm)', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              const SizedBox(height: 4),
              TextFormField(
                keyboardType: TextInputType.number,
                initialValue: _prefs.maxHeight?.toString() ?? '',
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Any',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (String v) {
                  setState(() => _prefs = _prefs.copyWith(
                    maxHeight: int.tryParse(v),
                  ));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
      value: value,
      onChanged: onChanged,
      activeColor: CosmicColors.cosmicPurple,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
