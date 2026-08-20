import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

// Assuming these paths exist in your project
import 'package:syno_app/domain/entities/astrology_system.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/widgets/app_dialogs.dart'; 
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/utils/error_localization.dart';
import 'package:syno_app/presentation/utils/emoji_mappings.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  final bool isReadOnly;
  const ProfileScreen({super.key, this.isReadOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<User?> currentUserAsync = ref.watch(currentUserProvider);
    final AppThemeData theme = ref.watch(themeProvider);

    // Listen for errors in currentUserProvider and show a dialog
    ref.listen<AsyncValue<User?>>(currentUserProvider, (AsyncValue<User?>? previous, AsyncValue<User?> next) {
      if (next.hasError && !next.isLoading && next.error != null) {
        if (context.mounted) {
          AppDialogs.showErrorDialog(context, 'profile.error'.tr(), resolveLocalizedMessage(next.error.toString(), context: context));
        }
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: currentUserAsync.when(
          data: (User? user) {
            if (user == null) {
              return Center(child: Text('chat.no_user'.tr()));
            }

            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: _buildAppBar(context, ref, user, theme, isReadOnly),
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: AppSpacing.paddingLg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildProfileHeader(context, user, ref, theme, isReadOnly),
                        const SizedBox(height: AppSpacing.xl),
                        _buildNameSection(context, user, theme),
                        const SizedBox(height: AppSpacing.xl),
                        _buildBioSection(context, user, theme),
                        const SizedBox(height: AppSpacing.xl),
                        _buildGallerySection(context, user),
                        const SizedBox(height: AppSpacing.xl),
                        _buildCoreValuesSection(context, user, theme),
                        const SizedBox(height: AppSpacing.xl),
                        _buildHobbiesSection(context, user, theme),
                        const SizedBox(height: AppSpacing.xl),
                        _buildBirthInfoSection(context, ref, user, theme),
                        const SizedBox(height: AppSpacing.xl),
                        _buildCareerEducationSection(context, user, theme),
                        const SizedBox(height: AppSpacing.xl),
                        _buildPreferencesSection(context, user, theme),
                        if (!isReadOnly) ...<Widget>[
                          const SizedBox(height: AppSpacing.xl),
                          _buildLogoutButton(context, ref),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (Object error, StackTrace stack) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  // --- Header & AppBar ---

  AppBar _buildAppBar(BuildContext context, WidgetRef ref, User? user, AppThemeData theme, bool isReadOnly) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: isReadOnly 
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: theme.primaryTextColor, size: 20),
              onPressed: () => context.pop(),
            )
          : null,
      title: Row(
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
            'profile.title'.tr(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: theme.primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
      actions: <Widget>[
        if (!isReadOnly)
          IconButton(
            icon: Icon(Icons.settings, color: theme.primaryTextColor),
            onPressed: () => context.go('/profile/settings'),
          )
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context, User user, WidgetRef ref, AppThemeData theme, bool isReadOnly) {
    return Column(
      children: <Widget>[
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: CosmicColors.cosmicPurple, width: 3),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: CosmicColors.cosmicPurple30,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(60),
              child: _ProfileImage(user: user),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${user.name ?? ''}, ${user.age ?? 'N/A'}',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: theme.primaryTextColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        if (!isReadOnly) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _buildActionButtons(context, user),
        ],
      ],
    );
  }

  // --- Content Sections ---

  Widget _buildActionButtons(BuildContext context, User user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _CosmicButton(
              icon: Icons.edit,
              label: 'profile.edit_profile'.tr(),
              onTap: (user.canEditProfile ?? false)
                  ? () => context.go('/profile/edit')
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('profile.edit_limited_message'.tr(
                            namedArgs: <String, String>{
                              'days': user.daysUntilNextEdit.toString() ?? '0'
                            })),
                        backgroundColor: CosmicColors.grey800,
                      ));
                    },
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _CosmicButton(
              icon: Icons.visibility,
              label: 'profile.preview_profile'.tr(),
              isOutlined: true,
              onTap: () => context.push('/profile/preview'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection(BuildContext context, User user, AppThemeData theme) {
    return _SectionWrapper(
      title: 'profile.name'.tr(),
      textColor: theme.primaryTextColor,
      child: Text(
        '${user.name ?? ''} ${user.lastName ?? ''}',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: theme.primaryTextColor.withOpacity(0.9)),
      ),
    );
  }

  Widget _buildBioSection(BuildContext context, User user, AppThemeData theme) {
    return _SectionWrapper(
      title: 'profile.about'.tr(),
      textColor: theme.primaryTextColor,
      child: Text(
        user.bio ?? 'profile.no_bio'.tr(),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: theme.primaryTextColor.withOpacity(0.9), height: 1.5),
      ),
    );
  }

  Widget _buildGallerySection(BuildContext context, User user) {
    final List<Photo> additionalPhotos = user.photos.where((Photo p) => p.isPrimary != true).toList();
    if (additionalPhotos.isEmpty) return const SizedBox.shrink();

    return _SectionWrapper(
      title: 'profile.gallery'.tr(),
      // Gallery doesn't use the text color for its content, but title needs it.
      // Since I can't pass theme easily to _SectionWrapper without refactoring it, 
      // I'll update _SectionWrapper below to accept optional textColor or infer it.
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: additionalPhotos.length,
        itemBuilder: (BuildContext context, int index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _GalleryImage(photoId: additionalPhotos[index].id),
          );
        },
      ),
    );
  }

  Widget _buildCoreValuesSection(BuildContext context, User user, AppThemeData theme) {
    return _SectionWrapper(
      title: 'profile.core_values.title'.tr(),
      textColor: theme.primaryTextColor,
      child: user.coreValues.isEmpty
          ? _PlaceholderText('profile.no_core_values'.tr(), theme.primaryTextColor)
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.coreValues.map((CoreValue item) {
                final String? emoji = EmojiMappings.lookup(item.translationKey, EmojiMappings.coreValues);
                return _TagChip(label: item.translationKey.tr(), emoji: emoji, textColor: theme.primaryTextColor);
              }).toList(),
            ),
    );
  }

  Widget _buildHobbiesSection(BuildContext context, User user, AppThemeData theme) {
    return _SectionWrapper(
      title: 'profile.hobbies_title'.tr(),
      textColor: theme.primaryTextColor,
      child: user.hobbies.isEmpty
          ? _PlaceholderText('profile.no_hobbies'.tr(), theme.primaryTextColor)
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.hobbies.map((Hobby h) {
                final String label = h.translationKey.isNotEmpty && h.translationKey.tr() != h.translationKey
                    ? h.translationKey.tr()
                    : h.name;
                final String? emoji = EmojiMappings.lookup(h.translationKey, EmojiMappings.hobbies);
                return _TagChip(label: label, emoji: emoji, textColor: theme.primaryTextColor);
              }).toList(),
            ),
    );
  }

  Widget _buildCareerEducationSection(BuildContext context, User user, AppThemeData theme) {
    return _SectionWrapper(
      title: 'profile.careerandeducation'.tr(),
      textColor: theme.primaryTextColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildTagsSection(context, Icons.work_outline, 'profile.profession'.tr(), user.professions.map((ProfessionModel p) {
            return p.translationKey.isNotEmpty && p.translationKey.tr() != p.translationKey
                ? p.translationKey.tr() : p.name;
          }).toList(), theme),
          const SizedBox(height: AppSpacing.md),
          Divider(color: theme.primaryTextColor.withOpacity(0.1), height: 1),
          const SizedBox(height: AppSpacing.md),
          _buildTagsSection(context, Icons.school_outlined, 'profile.education'.tr(), user.educations.map((EducationModel e) {
            return e.translationKey.isNotEmpty && e.translationKey.tr() != e.translationKey
                ? e.translationKey.tr() : e.name;
          }).toList(), theme),
        ],
      ),
    );
  }

  Widget _buildBirthInfoSection(BuildContext context, WidgetRef ref, User user, AppThemeData theme) {
    final AstrologySystem system = ref.watch(astrologySystemProvider);
    final Map<String, String>? zodiacData = user.getZodiacSign(system) != null ? _getZodiacData(user.getZodiacSign(system)!) : null;
    return _SectionWrapper(
      title: 'profile.birth_info'.tr(),
      textColor: theme.primaryTextColor,
      child: Column(
        children: <Widget>[
          _InfoRow(
            icon: Icons.cake,
            label: 'register.dob_label'.tr(),
            value: user.birthDate != null ? _formatLocalizedDate(user.birthDate!) : 'N/A',
            textColor: theme.primaryTextColor,
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(icon: Icons.access_time, label: 'register.tob_label'.tr(), value: user.birthTime ?? 'N/A', textColor: theme.primaryTextColor),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.location_on,
            label: 'profile.birth_location'.tr(),
            value: user.location?.localizedDisplayName ?? 'N/A',
            textColor: theme.primaryTextColor,
          ),
          if (zodiacData != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _InfoRow(icon: Icons.auto_awesome, label: 'profile.zodiac_sign'.tr(), value: zodiacData['name']!, textColor: theme.primaryTextColor),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(BuildContext context, User user, AppThemeData theme) {
    return _SectionWrapper(
      title: 'profile.preferences'.tr(),
      textColor: theme.primaryTextColor,
      child: Column(
        children: <Widget>[
          _InfoRow(icon: Icons.person_outline, label: 'profile.sex'.tr(), value: (user.sex?.translationKey.isNotEmpty == true && user.sex!.translationKey.tr() != user.sex!.translationKey) ? user.sex!.translationKey.tr() : (user.sex?.name ?? 'N/A'), textColor: theme.primaryTextColor),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(icon: Icons.favorite_border, label: 'profile.orientation'.tr(), value: (user.orientation?.translationKey.isNotEmpty == true && user.orientation!.translationKey.tr() != user.orientation!.translationKey) ? user.orientation!.translationKey.tr() : (user.orientation?.name ?? 'N/A'), textColor: theme.primaryTextColor),
          const SizedBox(height: AppSpacing.md),
          _buildIntentionsSection(context, user, theme),
        ],
      ),
    );
  }

  Widget _buildIntentionsSection(BuildContext context, User user, AppThemeData theme) {
    List<dynamic> intentions = <dynamic>[];
    intentions = (user.intentions as Iterable).toList();
  
    final List<String> labels = intentions.map((i) {
      try {
        // Handle both Map (json) and Object (entity) access
        if (i is Map) {
          return (i['translation_key'] ?? i['key'] ?? '').toString().tr();
        }
        final dynamic item = i;
        return (item.translationKey ?? item.key ?? '').toString().tr();
      } catch (e) {
        return i.toString();
      }
    }).toList();

    return _buildTagsSection(
      context,
      Icons.explore_outlined,
      'profile.intention'.tr(),
      labels,
      theme,
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.logout, color: CosmicColors.cosmicPink),
        label: Text('profile.logout'.tr(), style: const TextStyle(color: CosmicColors.cosmicPink, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), backgroundColor: Colors.white.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md), side: BorderSide(color: Colors.white.withOpacity(0.2)))),
        onPressed: () async {
          final bool? didConfirm = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              backgroundColor: CosmicColors.grey800,
              title: Text('profile.logout_confirm_title'.tr(), style: const TextStyle(color: Colors.white)),
              content: Text('profile.logout_confirm_subtitle'.tr(), style: const TextStyle(color: Colors.white70)),
              actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context, false), child: Text('profile.cancel'.tr())), TextButton(onPressed: () => Navigator.pop(context, true), child: Text('profile.logout'.tr()))],
            ),
          );
          if (didConfirm == true && context.mounted) {
            await ref.read(authProvider.notifier).logOut();
          }
        },
      ),
    );
  }

  // --- Helper Widgets & Logics ---

  Widget _buildTagsSection(BuildContext context, IconData icon, String label, List<String> items, AppThemeData theme) {
    // Filter out empty strings that might result from failed translation mapping
    final List<String> filteredItems = items.where((String item) => item.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, color: CosmicColors.cosmicPink, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: TextStyle(color: theme.primaryTextColor.withOpacity(0.6), fontSize: 12)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        filteredItems.isEmpty
            ? _PlaceholderText('N/A', theme.primaryTextColor)
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((String item) => _TagChip(label: item, textColor: theme.primaryTextColor)).toList(),
              ),
      ],
    );
  }

  String _formatLocalizedDate(DateTime date) {
    const List<String> monthKeys = <String>[
      'months.january', 'months.february', 'months.march', 'months.april',
      'months.may', 'months.june', 'months.july', 'months.august',
      'months.september', 'months.october', 'months.november', 'months.december',
    ];
    final String monthName = monthKeys[date.month - 1].tr();
    return '$monthName ${date.day}, ${date.year}';
  }

  Map<String, String> _getZodiacData(String sign) {
    final String s = sign.trim().toLowerCase();
    String key = 'zodiac.unknown';
    if (s.contains('aries')) {
      key = 'zodiac.aries';
    } else if (s.contains('taurus')) key = 'zodiac.taurus';
    else if (s.contains('gemini')) key = 'zodiac.gemini';
    else if (s.contains('cancer')) key = 'zodiac.cancer';
    else if (s.contains('leo')) key = 'zodiac.leo';
    else if (s.contains('virgo')) key = 'zodiac.virgo';
    else if (s.contains('libra')) key = 'zodiac.libra';
    else if (s.contains('scorpio')) key = 'zodiac.scorpio';
    else if (s.contains('sagittarius')) key = 'zodiac.sagittarius';
    else if (s.contains('capricorn')) key = 'zodiac.capricorn';
    else if (s.contains('aquarius')) key = 'zodiac.aquarius';
    else if (s.contains('pisces')) key = 'zodiac.pisces';
    
    final Map<String, String> emojis = <String, String>{
      'zodiac.aries': '♈', 'zodiac.taurus': '♉', 'zodiac.gemini': '♊',
      'zodiac.cancer': '♋', 'zodiac.leo': '♌', 'zodiac.virgo': '♍',
      'zodiac.libra': '♎', 'zodiac.scorpio': '♏', 'zodiac.sagittarius': '♐',
      'zodiac.capricorn': '♑', 'zodiac.aquarius': '♒', 'zodiac.pisces': '♓',
      'zodiac.unknown': '✨'
    };

    return <String, String>{'emoji': emojis[key]!, 'name': key.tr()};
  }
}

// --- Sub-Widgets ---

class _SectionWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? textColor;
  const _SectionWrapper({required this.title, required this.child, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: TextStyle(color: textColor ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: <Color>[CosmicColors.cosmicPurple20, CosmicColors.cosmicPink20]),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color? textColor;
  final String? emoji;
  const _TagChip({required this.label, this.textColor, this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (textColor ?? Colors.white).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: textColor ?? Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _PlaceholderText extends StatelessWidget {
  final String text;
  final Color? textColor;
  const _PlaceholderText(this.text, [this.textColor]);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: (textColor ?? Colors.white).withOpacity(0.5), fontStyle: FontStyle.italic));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? textColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: CosmicColors.cosmicPink, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: TextStyle(color: (textColor ?? Colors.white).withOpacity(0.6), fontSize: 12)),
              Text(value, style: TextStyle(color: textColor ?? Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileImage extends StatefulWidget {
  final User user;
  const _ProfileImage({required this.user});

  @override
  State<_ProfileImage> createState() => _ProfileImageState();
}

class _ProfileImageState extends State<_ProfileImage> {
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _token = prefs.getString('auth_token'));
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
    
    final Photo? primaryPhoto = widget.user.photos.cast<Photo?>().firstWhere((Photo? p) => p?.isPrimary == true, orElse: () => null);

    if (primaryPhoto == null) {
      return const ColoredBox(color: CosmicColors.cosmicPurple, child: Icon(Icons.person, size: 60, color: Colors.white));
    }

    return Consumer(builder: (BuildContext context, WidgetRef ref, _) {
      final String backendUrl = ref.watch(backendUrlProvider);
      return Image.network(
        '$backendUrl/api/photos/${primaryPhoto.id}',
        headers: <String, String>{'Authorization': 'Bearer $_token'},
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person, color: Colors.white)),
      );
    });
  }
}

class _CosmicButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isOutlined;

  const _CosmicButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: isOutlined
            ? null
            : const LinearGradient(
                colors: <Color>[CosmicColors.cosmicPurple, CosmicColors.cosmicPink],
              ),
        color: isOutlined ? Colors.white.withOpacity(0.05) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isOutlined
            ? Border.all(color: Colors.white.withOpacity(0.3))
            : null,
        boxShadow: isOutlined
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: CosmicColors.cosmicPink.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryImage extends StatefulWidget {
  final int photoId;
  const _GalleryImage({required this.photoId});

  @override
  State<_GalleryImage> createState() => _GalleryImageState();
}

class _GalleryImageState extends State<_GalleryImage> {
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _token = prefs.getString('auth_token'));
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) return Container(color: Colors.white10);
    
    return Consumer(builder: (BuildContext context, WidgetRef ref, _) {
      final String backendUrl = ref.watch(backendUrlProvider);
      return Image.network(
        '$backendUrl/api/photos/${widget.photoId}',
        headers: <String, String>{'Authorization': 'Bearer $_token'},
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.white10, child: const Icon(Icons.broken_image, color: Colors.white24)),
      );
    });
  }
}