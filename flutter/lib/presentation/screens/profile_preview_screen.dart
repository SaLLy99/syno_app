import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/domain/entities/user.dart';
import 'package:syno_app/presentation/providers/auth_providers.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/theme.dart';

class ProfilePreviewScreen extends ConsumerWidget {
  const ProfilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeData theme = ref.watch(themeProvider);
    final AsyncValue<User?> userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.primaryTextColor),
          onPressed: () => context.pop(),
        ),
        title: Text('profile.preview_profile'.tr(), style: TextStyle(color: theme.primaryTextColor)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (_, __) => Center(child: Text('profile.error'.tr(), style: TextStyle(color: theme.primaryTextColor))),
          data: (User? user) {
            if (user == null) {
              return Center(child: Text('chat.no_user'.tr(), style: TextStyle(color: theme.primaryTextColor)));
            }

            final String? zodiac = user.zodiacSign != null ? _getZodiacName(user.zodiacSign!) : null;
            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: Colors.white.withOpacity(0.16)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _PreviewAvatar(user: user),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          user.name ?? '—',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: theme.primaryTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            if (user.age != null)
                              _InfoPill(label: 'profile.age'.tr(), value: user.age.toString()),
                            if (user.age != null && zodiac != null) const SizedBox(width: AppSpacing.sm),
                            if (zodiac != null) _InfoPill(label: 'profile.zodiac_sign'.tr(), value: zodiac),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          user.bio ?? 'profile.no_bio'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.secondaryTextColor, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _getZodiacName(String sign) {
    final String normalized = sign.trim().toLowerCase();
    if (normalized.contains('aries')) return 'zodiac.aries'.tr();
    if (normalized.contains('taurus')) return 'zodiac.taurus'.tr();
    if (normalized.contains('gemini')) return 'zodiac.gemini'.tr();
    if (normalized.contains('cancer')) return 'zodiac.cancer'.tr();
    if (normalized.contains('leo')) return 'zodiac.leo'.tr();
    if (normalized.contains('virgo')) return 'zodiac.virgo'.tr();
    if (normalized.contains('libra')) return 'zodiac.libra'.tr();
    if (normalized.contains('scorpio')) return 'zodiac.scorpio'.tr();
    if (normalized.contains('sagittarius')) return 'zodiac.sagittarius'.tr();
    if (normalized.contains('capricorn')) return 'zodiac.capricorn'.tr();
    if (normalized.contains('aquarius')) return 'zodiac.aquarius'.tr();
    if (normalized.contains('pisces')) return 'zodiac.pisces'.tr();
    return null;
  }
}

class _PreviewAvatar extends StatefulWidget {
  final User user;
  const _PreviewAvatar({required this.user});

  @override
  State<_PreviewAvatar> createState() => _PreviewAvatarState();
}

class _PreviewAvatarState extends State<_PreviewAvatar> {
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
    final ThemeData theme = Theme.of(context);
    final Photo? primaryPhoto = widget.user.photos.cast<Photo?>().firstWhere((Photo? p) => p?.isPrimary == true, orElse: () => null);

    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: CosmicColors.cosmicPurple, width: 3),
      ),
      child: ClipOval(
        child: _token == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : (primaryPhoto == null
                ? Container(color: CosmicColors.cosmicPurple, child: const Icon(Icons.person, size: 72, color: Colors.white))
                : Consumer(builder: (BuildContext context, WidgetRef ref, _) {
                    final String backendUrl = ref.watch(backendUrlProvider);
                    return Image.network(
                      '$backendUrl/api/photos/${primaryPhoto.id}',
                      headers: <String, String>{'Authorization': 'Bearer $_token'},
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: CosmicColors.cosmicPurple, child: const Icon(Icons.person, size: 72, color: Colors.white)),
                    );
                  })),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  const _InfoPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('$label: ', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
