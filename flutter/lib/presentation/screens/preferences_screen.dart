import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/user_preferences.dart';
import 'package:syno_app/presentation/providers/preferences_provider.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/presentation/widgets/weight_slider.dart';
import 'package:syno_app/theme.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  late DiscoverPreferences _prefs;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _prefs = ref.read(preferencesProvider).value ?? const DiscoverPreferences();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await ref.read(preferencesProvider.notifier).updatePreferences(_prefs);
    setState(() => _isSaving = false);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeData theme = ref.watch(themeProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryTextColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Discover Preferences',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: theme.primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.accentColor,
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: theme.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildSection('Basic Filters', Icons.tune, [
                _buildAgeRange(),
                _buildDistanceSlider(),
                _buildGenderFilter(),
                _buildOrientationFilter(),
                _buildLookingFor(),
                _buildSwitch('Verified users only', Icons.verified, _prefs.verifiedOnly,
                    (v) => setState(() => _prefs = _prefs.copyWith(verifiedOnly: v))),
                _buildSwitch('Online recently', Icons.circle, _prefs.onlineRecently,
                    (v) => setState(() => _prefs = _prefs.copyWith(onlineRecently: v))),
              ]),
              const SizedBox(height: 16),
              _buildSection('Astrology Preferences', Icons.auto_awesome, [
                _buildMinCompatibility(),
                _buildPriorityType(),
                _buildWeightSliders(),
                _buildBirthTimeRequirement(),
              ]),
              const SizedBox(height: 16),
              _buildSection('Lifestyle', Icons.favorite_border, [
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
              const SizedBox(height: 16),
              _buildSection('Advanced', Icons.settings, [
                _buildSwitch('Hide already swiped', Icons.visibility_off, _prefs.hideSwiped,
                    (v) => setState(() => _prefs = _prefs.copyWith(hideSwiped: v))),
                _buildSwitch('Hide inactive users', Icons.person_off, _prefs.hideInactive,
                    (v) => setState(() => _prefs = _prefs.copyWith(hideInactive: v))),
                _buildSwitch('Show users traveling nearby', Icons.travel_explore, _prefs.showTraveling,
                    (v) => setState(() => _prefs = _prefs.copyWith(showTraveling: v))),
                _buildSwitch('Global search', Icons.public, _prefs.globalSearch,
                    (v) => setState(() => _prefs = _prefs.copyWith(globalSearch: v))),
                _buildSwitch('Only users with photos', Icons.photo_library, _prefs.photosOnly,
                    (v) => setState(() => _prefs = _prefs.copyWith(photosOnly: v))),
                _buildSwitch('Only complete profiles', Icons.checklist, _prefs.completeProfilesOnly,
                    (v) => setState(() => _prefs = _prefs.copyWith(completeProfilesOnly: v))),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: CosmicColors.cosmicPink, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(children: children),
          ),
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
            Text('Age range', style: TextStyle(color: Colors.white.withOpacity(0.8))),
            Text(
              '${_prefs.minAge} - ${_prefs.maxAge}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        RangeSlider(
          values: RangeValues(_prefs.minAge.toDouble(), _prefs.maxAge.toDouble()),
          min: 18,
          max: 65,
          activeColor: CosmicColors.cosmicPurple,
          inactiveColor: Colors.white.withOpacity(0.15),
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
            Text('Maximum distance', style: TextStyle(color: Colors.white.withOpacity(0.8))),
            Text(
              _prefs.maxDistance >= 500 ? '500+ km' : '${_prefs.maxDistance} km',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: _prefs.maxDistance.toDouble(),
          min: 5,
          max: 500,
          activeColor: CosmicColors.cosmicPurple,
          inactiveColor: Colors.white.withOpacity(0.15),
          onChanged: (double value) {
            setState(() {
              _prefs = _prefs.copyWith(maxDistance: value.toInt());
            });
          },
        ),
      ],
    );
  }

  Widget _buildGenderFilter() {
    final options = ['Male', 'Female', 'Non-binary'];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Text('Show me:', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        ...options.map((g) => FilterChip(
          label: Text(g, style: const TextStyle(fontSize: 13)),
          selected: _prefs.genders.contains(g),
          onSelected: (selected) {
            setState(() {
              final newGenders = List<String>.from(_prefs.genders);
              if (selected) {
                newGenders.add(g);
              } else {
                newGenders.remove(g);
              }
              _prefs = _prefs.copyWith(genders: newGenders);
            });
          },
          selectedColor: CosmicColors.cosmicPurple,
          backgroundColor: Colors.white.withOpacity(0.1),
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
          checkmarkColor: Colors.white,
        )),
      ],
    );
  }

  Widget _buildOrientationFilter() {
    final options = ['Straight', 'Gay', 'Bisexual', 'Pansexual'];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Text('Orientation:', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        ...options.map((o) => FilterChip(
          label: Text(o, style: const TextStyle(fontSize: 13)),
          selected: _prefs.orientations.contains(o),
          onSelected: (selected) {
            setState(() {
              final newOrients = List<String>.from(_prefs.orientations);
              if (selected) {
                newOrients.add(o);
              } else {
                newOrients.remove(o);
              }
              _prefs = _prefs.copyWith(orientations: newOrients);
            });
          },
          selectedColor: CosmicColors.cosmicPink,
          backgroundColor: Colors.white.withOpacity(0.1),
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
          checkmarkColor: Colors.white,
        )),
      ],
    );
  }

  Widget _buildLookingFor() {
    final options = ['Dating', 'Long-term', 'Friendship', 'Networking'];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Text('Looking for:', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        ...options.map((l) => FilterChip(
          label: Text(l, style: const TextStyle(fontSize: 13)),
          selected: _prefs.lookingFor.contains(l),
          onSelected: (selected) {
            setState(() {
              final newLooking = List<String>.from(_prefs.lookingFor);
              if (selected) {
                newLooking.add(l);
              } else {
                newLooking.remove(l);
              }
              _prefs = _prefs.copyWith(lookingFor: newLooking);
            });
          },
          selectedColor: CosmicColors.cosmicBlue,
          backgroundColor: Colors.white.withOpacity(0.1),
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
          checkmarkColor: Colors.white,
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
            Text('Minimum compatibility', style: TextStyle(color: Colors.white.withOpacity(0.8))),
            Text(
              '${_prefs.minCompatibility}%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: _prefs.minCompatibility.toDouble(),
          min: 0,
          max: 95,
          activeColor: CosmicColors.cosmicPink,
          inactiveColor: Colors.white.withOpacity(0.15),
          onChanged: (double value) {
            setState(() {
              _prefs = _prefs.copyWith(minCompatibility: value.toInt());
            });
          },
        ),
      ],
    );
  }

  Widget _buildPriorityType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priority focus', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 8),
        ...DiscoverPreferences.priorityTypes.map((type) {
          final label = DiscoverPreferences.priorityLabels[type] ?? type;
          final isSelected = _prefs.priorityType == type;
          return RadioListTile<String>(
            value: type,
            groupValue: _prefs.priorityType,
            onChanged: (v) {
              if (v != null) {
                setState(() => _prefs = _prefs.copyWith(priorityType: v));
              }
            },
            title: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
            activeColor: CosmicColors.cosmicPurple,
            contentPadding: EdgeInsets.zero,
            dense: true,
          );
        }),
      ],
    );
  }

  Widget _buildWeightSliders() {
    final weightKeys = [
      'romance', 'emotional', 'communication', 'long_term',
      'marriage', 'friendship', 'chemistry', 'spiritual',
    ];

    return Column(
      children: weightKeys.map((key) {
        final label = DiscoverPreferences.priorityLabels[key] ?? key;
        final icon = DiscoverPreferences.weightIcons[key] ?? '•';
        return WeightSlider(
          label: label,
          icon: icon,
          value: _prefs.weights[key] ?? 50,
          onChanged: (v) {
            setState(() {
              final newWeights = Map<String, double>.from(_prefs.weights);
              newWeights[key] = v;
              _prefs = _prefs.copyWith(weights: newWeights);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildBirthTimeRequirement() {
    final options = {
      'exact': 'Exact birth time only',
      'optional': 'Birth time optional',
      'unknown': 'Unknown birth time accepted',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Birth time preference', style: TextStyle(color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 4),
        ...options.entries.map((e) => RadioListTile<String>(
          value: e.key,
          groupValue: _prefs.birthTimeRequirement,
          onChanged: (v) {
            if (v != null) {
              setState(() => _prefs = _prefs.copyWith(birthTimeRequirement: v));
            }
          },
          title: Text(e.value, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
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
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: Icon(icon, color: CosmicColors.cosmicPink, size: 20),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: CosmicColors.cosmicPurple),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dropdownColor: const Color(0xFF2D1B4E),
        style: const TextStyle(color: Colors.white),
        items: [
          const DropdownMenuItem(value: null, child: Text('Any')),
          ...options.map((o) => DropdownMenuItem(
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
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Min height (cm)', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
              const SizedBox(height: 4),
              TextFormField(
                keyboardType: TextInputType.number,
                initialValue: _prefs.minHeight?.toString() ?? '',
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Any',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) {
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
            children: [
              Text('Max height (cm)', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
              const SizedBox(height: 4),
              TextFormField(
                keyboardType: TextInputType.number,
                initialValue: _prefs.maxHeight?.toString() ?? '',
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Any',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) {
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

  Widget _buildSwitch(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      secondary: Icon(icon, color: CosmicColors.cosmicPink, size: 20),
      title: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
      value: value,
      onChanged: onChanged,
      activeColor: CosmicColors.cosmicPurple,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
