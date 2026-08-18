import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/domain/entities/astrology_system.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';
import 'package:syno_app/presentation/widgets/app_dialogs.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/presentation/utils/error_localization.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeData theme = ref.watch(themeProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('profile.settings.title'.tr(), style: TextStyle(color: theme.primaryTextColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.primaryTextColor),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              _buildSectionTitle(context, 'profile.settings.general'.tr(), theme),
              _buildSettingsTile(
                context,
                icon: Icons.palette_outlined,
                title: 'profile.settings.theme.title'.tr(),
                subtitle: 'profile.settings.theme.subtitle'.tr(),
                onTap: () => context.push('/profile/settings/theme-selection'),
                theme: theme,
              ),
              _buildAstrologySystemTile(context, ref, theme),
              _buildSettingsTile(
                context,
                icon: Icons.analytics_outlined,
                title: 'Analytics',
                subtitle: 'View your match statistics and tips',
                onTap: () => context.push('/analytics'),
                theme: theme,
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSectionTitle(context, 'profile.settings.account'.tr(), theme),
              _buildSettingsTile(
                context,
                icon: Icons.block,
                title: 'profile.settings.blocked_users.title'.tr(),
                subtitle: 'profile.settings.blocked_users.subtitle'.tr(),
                onTap: () => context.push('/profile/settings/blocked-users'),
                theme: theme,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.no_accounts,
                title: 'profile.settings.deactivate.title'.tr(),
                subtitle: 'profile.settings.deactivate.subtitle'.tr(),
                theme: theme,
                isDestructive: true,
                onTap: () => _confirmDeactivation(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: theme.primaryTextColor.withOpacity(0.5),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required AppThemeData theme,
    bool isDestructive = false,
  }) {
    final Color color = isDestructive ? Colors.redAccent : theme.primaryTextColor;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: theme.secondaryTextColor)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    );
  }

  Widget _buildAstrologySystemTile(BuildContext context, WidgetRef ref, AppThemeData theme) {
    final AstrologySystem current = ref.watch(astrologySystemProvider);
    return ListTile(
      leading: Icon(Icons.auto_awesome, color: theme.primaryTextColor),
      title: Text('Astrology System', style: TextStyle(color: theme.primaryTextColor, fontWeight: FontWeight.bold)),
      subtitle: Text(
        '${current.label} — ${current.description}',
        style: TextStyle(color: theme.secondaryTextColor),
      ),
      trailing: DropdownButton<AstrologySystem>(
        value: current,
        dropdownColor: const Color(0xFF2D1B4E),
        style: TextStyle(color: theme.primaryTextColor),
        underline: const SizedBox.shrink(),
        onChanged: (AstrologySystem? newSystem) {
          if (newSystem != null) {
            ref.read(astrologySystemProvider.notifier).setSystem(newSystem);
          }
        },
        items: AstrologySystem.values.map((system) {
          return DropdownMenuItem<AstrologySystem>(
            value: system,
            child: Text('${system.label} (${system.description})'),
          );
        }).toList(),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    );
  }

  Future<void> _confirmDeactivation(BuildContext context, WidgetRef ref) async {
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('profile.settings.deactivate.confirm_title'.tr()),
        content: Text(
          'profile.settings.deactivate.confirm_message'.tr(),
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('profile.settings.cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('profile.settings.deactivate.action'.tr(), style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (didConfirm == true && context.mounted) {
      try {
        await ref.read(currentUserProvider.notifier).deactivateAccount();
      } catch (e) {
        if (context.mounted) AppDialogs.showErrorDialog(context, 'profile.error'.tr(), resolveLocalizedMessage(e.toString(), context: context));
      }
    }
  }
}