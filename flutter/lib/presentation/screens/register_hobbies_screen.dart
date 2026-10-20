import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/hobbies_data.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart'
    show ProfileData, hobbiesProvider, registrationProvider;
import 'package:syno_app/presentation/widgets/onboarding_scaffold.dart';
import 'package:syno_app/presentation/widgets/selectable_option_card.dart';
import 'package:syno_app/presentation/utils/emoji_mappings.dart';
import 'package:syno_app/presentation/utils/hobby_categories.dart';
import 'package:syno_app/theme.dart';

class RegisterHobbiesScreen extends ConsumerStatefulWidget {
  const RegisterHobbiesScreen({super.key});

  @override
  ConsumerState<RegisterHobbiesScreen> createState() =>
      _RegisterHobbiesScreenState();
}

class _RegisterHobbiesScreenState extends ConsumerState<RegisterHobbiesScreen> {
  final Set<int> _selectedIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedCategory = 'popular';
  bool _showAllInCategory = false;

  static const int _initialVisibleCount = 12;

  @override
  void initState() {
    super.initState();
    final ProfileData regState = ref.read(registrationProvider).profileData;
    _selectedIds.addAll(regState.hobbyIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onNext() {
    ref.read(registrationProvider.notifier).updateProfileData(<String, dynamic>{
      'hobby_ids': _selectedIds.toList(),
    });
    context.push('/register-career');
  }

  List<Hobby> _filterHobbies(List<Hobby> hobbies) {
    List<Hobby> result = hobbies;

    // Apply category filter
    if (_selectedCategory != 'popular' && _searchQuery.isEmpty) {
      result = HobbyCategories.filterByCategory<Hobby>(
        result,
        _selectedCategory,
        (Hobby h) => h.translationKey,
      );
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((Hobby h) {
        final String label = h.translationKey.isNotEmpty &&
                h.translationKey.tr() != h.translationKey
            ? h.translationKey.tr()
            : h.name;
        return label.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Hobby>> hobbiesAsync = ref.watch(hobbiesProvider);

    return OnboardingScaffold(
      title: 'register.hobbies_title'.tr(),
      progress: 8 / 10,
      onContinue: _onNext,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('register.hobbies_subtitle'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            _buildSelectionCounter(),
            const SizedBox(height: 12),
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildCategoryChips(),
            const SizedBox(height: 12),
            Expanded(
              child: hobbiesAsync.when(
                data: (List<Hobby> hobbies) {
                  final List<Hobby> filtered = _filterHobbies(hobbies);

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No hobbies found',
                          style: TextStyle(color: Colors.white54)),
                    );
                  }

                  // In search mode, show all results. In category mode, show limited
                  final bool shouldLimit = _searchQuery.isEmpty &&
                      !_showAllInCategory &&
                      filtered.length > _initialVisibleCount;
                  final int itemCount =
                      shouldLimit ? _initialVisibleCount : filtered.length;

                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: <Widget>[
                      // Selected items section
                      if (_selectedIds.isNotEmpty && _searchQuery.isEmpty) ...<Widget>[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Your picks',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildSelectedPreview(hobbies),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Text(
                              _selectedCategory == 'popular'
                                  ? 'Browse all'
                                  : HobbyCategories.categoryLabels[_selectedCategory] ?? '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      // Main grid
                      SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            final Hobby hobby = filtered[index];
                            return _buildHobbyCard(hobby);
                          },
                          childCount: itemCount,
                        ),
                      ),
                      // Show more button
                      if (shouldLimit)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Center(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _showAllInCategory = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color:
                                            Colors.white.withOpacity(0.15)),
                                  ),
                                  child: Text(
                                    'Show all ${filtered.length}',
                                    style: TextStyle(
                                      color: CosmicColors.cosmicPink,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Bottom padding
                      const SliverToBoxAdapter(
                          child: SizedBox(height: 80)),
                    ],
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

  Widget _buildHobbyCard(Hobby hobby) {
    final bool isSelected = _selectedIds.contains(hobby.id);
    final String label = hobby.translationKey.isNotEmpty &&
            hobby.translationKey.tr() != hobby.translationKey
        ? hobby.translationKey.tr()
        : hobby.name;
    final String? emoji =
        EmojiMappings.lookup(hobby.translationKey, EmojiMappings.hobbies);

    return SelectableOptionCard(
      selected: isSelected,
      label: label,
      emoji: emoji,
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
  }

  Widget _buildSelectedPreview(List<Hobby> hobbies) {
    final List<Hobby> selected =
        hobbies.where((Hobby h) => _selectedIds.contains(h.id)).toList();
    if (selected.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: selected.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final Hobby hobby = selected[index];
          final String label = hobby.translationKey.isNotEmpty &&
                  hobby.translationKey.tr() != hobby.translationKey
              ? hobby.translationKey.tr()
              : hobby.name;
          final String? emoji = EmojiMappings.lookup(
              hobby.translationKey, EmojiMappings.hobbies);

          return GestureDetector(
            onTap: () => setState(() => _selectedIds.remove(hobby.id)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CosmicColors.cosmicPink.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: CosmicColors.cosmicPink.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (emoji != null) ...[
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                  ],
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Icon(Icons.close,
                      size: 14, color: Colors.white.withOpacity(0.7)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionCounter() {
    final int count = _selectedIds.length;
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
            '$count selected',
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

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: HobbyCategories.categoryLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String key = HobbyCategories.categoryLabels.keys.elementAt(index);
          final String label = HobbyCategories.categoryLabels[key]!;
          final bool isSelected = _selectedCategory == key;

          return GestureDetector(
            onTap: () => setState(() {
              _selectedCategory = key;
              _showAllInCategory = false;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? CosmicColors.cosmicPink.withOpacity(0.2)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? CosmicColors.cosmicPink.withOpacity(0.6)
                      : Colors.white.withOpacity(0.12),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF11121A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (String value) => setState(() {
          _searchQuery = value;
          if (value.isNotEmpty) _selectedCategory = 'popular';
        }),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search hobbies...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
          prefixIcon: Icon(Icons.search,
              color: Colors.white.withOpacity(0.35), size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear,
                      color: Colors.white.withOpacity(0.35), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }
}
