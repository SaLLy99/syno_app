import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/presentation/providers/registration_provider.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/theme.dart'; 
import 'package:go_router/go_router.dart';
import 'package:syno_app/presentation/providers/theme_update_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';

class ThemeSelectionScreen extends ConsumerStatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  ConsumerState<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends ConsumerState<ThemeSelectionScreen> {
  // Holds the currently previewed theme locally before saving.
  late AppThemeData _selectedTheme;

  // Manages the loading state for the save operation.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize local state with the currently active theme from the provider.
    _selectedTheme = ref.read(themeProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Determine a contrasting color for the FAB text based on the accent color's brightness.
    final fabColor = _selectedTheme.accentColor;
    final fabTextColor = fabColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'profile.settings.theme.theme_selection_title'.tr(),
          style: TextStyle(color: _selectedTheme.primaryTextColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _selectedTheme.primaryTextColor),
      ),
      body: Container(
        // The background gradient dynamically updates on selection.
        decoration: BoxDecoration(gradient: _selectedTheme.gradient),
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: availableThemes.length,
            itemBuilder: (context, index) {
              final theme = availableThemes[index];
              final isSelected = theme.id == _selectedTheme.id;

              return Card(
                color: _selectedTheme.primaryTextColor.withOpacity(0.05),
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(
                    color: isSelected ? theme.accentColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ListTile(
                  onTap: () => setState(() => _selectedTheme = theme),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: theme.gradient,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    theme.name, 
                    style: TextStyle(
                      color: _selectedTheme.primaryTextColor, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_circle, color: theme.accentColor) : null,
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : () async {
          setState(() => _isSaving = true);
          try {
            final themeMap = {
              'theme_id': _selectedTheme.id,
              'background_color': '#${_selectedTheme.backgroundColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
              'accent_color': '#${_selectedTheme.accentColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
              'layout': _selectedTheme.layout,
            };

            // Apply the selected theme globally so the app updates immediately.
            ref.read(themeProvider.notifier).setThemeFromProfile(_selectedTheme);

            final currentUserState = ref.read(currentUserProvider);
            final isProfileUpdate = currentUserState is AsyncData && currentUserState.value != null;

            if (isProfileUpdate) {
              final newTheme = AppThemeData.fromJson(themeMap);
              await ref.read(themeUpdateProvider.notifier).updateTheme(newTheme);
              if (mounted) context.pop();
            } else {
              final registrationNotifier = ref.read(registrationProvider.notifier);
              registrationNotifier.updateProfileData(themeMap);
              if (mounted) context.go('/profile-confirmation');
            }
          } on dio.DioException catch (e) {
            if (!mounted) return;
            final message = e.response?.statusCode == 401
                ? 'profile.settings.theme.save_error_unauthorized'.tr()
                : 'profile.settings.theme.save_error_generic'.tr();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('profile.settings.theme.save_error_generic'.tr()),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          } finally {
            if (mounted) {
              setState(() => _isSaving = false);
            }
          }
        },
        label: Text('profile.settings.theme.save_button'.tr()),
        icon: _isSaving
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: fabTextColor, strokeWidth: 2.0),
              )
            : const Icon(Icons.check),
        backgroundColor: fabColor,
        foregroundColor: fabTextColor,
      ),
    );
  }
}