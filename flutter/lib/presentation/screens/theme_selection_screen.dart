import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';
import 'package:syno_app/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:syno_app/presentation/providers/theme_update_provider.dart';
import 'package:syno_app/presentation/providers/user_provider.dart';


/// A screen that allows the user to preview and select a new application theme.
///
/// This screen provides a much more user-friendly experience by:
/// 1.  Converting to a `ConsumerStatefulWidget` to manage a local "preview" state.
/// 2.  Instantly updating the screen's appearance (gradient, text colors) as the
///     user taps different themes, providing a dynamic preview.
/// 3.  Introducing an explicit "Save" button (`FloatingActionButton`) to make the
///     act of persisting the theme clear and intentional.
/// 4.  Discarding changes automatically if the user navigates back without saving.
class ThemeSelectionScreen extends ConsumerStatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  ConsumerState<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends ConsumerState<ThemeSelectionScreen> {
  // Holds the currently previewed theme. It's initialized with the app's
  // current theme and updated locally as the user selects different options.
  late AppThemeData _selectedTheme;

  // Manages the loading state for the save operation.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize the local state with the currently active theme from the provider.
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
        // The background gradient now dynamically updates on selection.
        decoration: BoxDecoration(gradient: _selectedTheme.gradient),
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: availableThemes.length,
            itemBuilder: (context, index) {
              final theme = availableThemes[index];
              // The 'isSelected' check is now against the local preview state.
              final isSelected = theme.id == _selectedTheme.id;

              return Card(
                // The card's appearance also reflects the live preview theme.
                color: _selectedTheme.primaryTextColor.withOpacity(0.05),
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(
                    // The border highlights the selected theme using its own accent color.
                    color: isSelected ? theme.accentColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ListTile(
                  // Tapping a theme now updates the local state to trigger a live preview.
                  onTap: () => setState(() => _selectedTheme = theme),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: theme.gradient,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(theme.name, style: TextStyle(color: _selectedTheme.primaryTextColor, fontWeight: FontWeight.bold)),
                  trailing: isSelected ? Icon(Icons.check_circle, color: theme.accentColor) : null,
                ),
              );
            },
          ),
        ),
      ),
      // A FAB provides a clear action to save the chosen theme.
      floatingActionButton: FloatingActionButton.extended(
        // Disable the button while the save operation is in progress.
        onPressed: _isSaving ? null : () async {
          setState(() => _isSaving = true);
          try {
            final initialTheme = ref.read(themeProvider);
            // Only call the update method if the theme has actually changed.
            if (_selectedTheme.id != initialTheme.id) {
              // Use the new dedicated notifier to handle the entire update process.
              // This centralizes the logic and makes the UI cleaner.
              await ref.read(themeUpdateProvider.notifier).updateTheme(_selectedTheme);
              
              // Force a refresh of the user data to apply the new theme globally
              ref.invalidate(currentUserProvider);
            }
            // On success, navigate to the profile screen.
            if (mounted) {
              context.go('/profile');
            }
          } on dio.DioException catch (e) {
            // If the update fails, show an error message to the user.
            if (mounted) {
              // Choose a message based on the error type.
              final message = e.response?.statusCode == 401
                  ? 'profile.settings.theme.save_error_unauthorized'.tr()
                  : 'profile.settings.theme.save_error_generic'.tr();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          } catch (e) {
            // Catch other non-Dio exceptions
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('profile.settings.theme.save_error_generic'.tr()),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          } finally {
            // Ensure the loading state is always reset, even on error.
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