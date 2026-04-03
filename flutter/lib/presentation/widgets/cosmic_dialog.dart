import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

/// A themed dialog that matches the app's cosmic aesthetic.
class CosmicDialog extends StatelessWidget {
  final String title;
  final String message;
  final AppThemeData theme;
  final IconData? icon;
  final String? buttonText;
  final String? cancelText;
  final VoidCallback? onButtonPressed;
  final VoidCallback? onCancelPressed;

  const CosmicDialog({
    super.key,
    required this.title,
    required this.message,
    required this.theme,
    this.icon,
    this.buttonText,
    this.cancelText,
    this.onButtonPressed,
    this.onCancelPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.85),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.accentColor.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      title: Row(
        children: [
          Icon(icon ?? Icons.info_outline, color: theme.accentColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: theme.primaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          color: theme.primaryTextColor.withOpacity(0.9),
          fontSize: 16,
          height: 1.4,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (cancelText != null)
                TextButton(
                  onPressed: onCancelPressed ?? () => Navigator.pop(context),
                  child: Text(
                    cancelText!,
                    style: TextStyle(color: theme.primaryTextColor.withOpacity(0.6), fontSize: 16),
                  ),
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onButtonPressed ?? () => Navigator.pop(context),
                child: Text(
                  buttonText ?? 'dialog.close'.tr(),
                  style: TextStyle(
                    color: theme.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows a themed cosmic error dialog with a single "Close" button.
void showCosmicErrorDialog(BuildContext context, String title, String message, AppThemeData theme) {
  showDialog(
    context: context,
    useRootNavigator: true, // Ensure the dialog appears over the root navigator
    barrierDismissible: false, // User must tap the button to dismiss
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (context) => CosmicDialog(
      title: title,
      message: message,
      theme: theme,
    ),
  );
}

/// Shows a themed cosmic confirmation dialog (e.g., "Are you sure you want to block?").
void showCosmicConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
  required VoidCallback onConfirm,
  required AppThemeData theme,
}) {
  showDialog(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (context) => CosmicDialog(
      title: title,
      message: message,
      theme: theme,
      buttonText: confirmText,
      cancelText: 'dialog.cancel'.tr(),
      onButtonPressed: () {
        Navigator.pop(context);
        onConfirm();
      },
    ),
  );
}

/// Specialized helper for the "User Not Found" error.
void showUserNotFoundDialog(BuildContext context, AppThemeData theme) {
  showDialog(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (context) => CosmicDialog(
      title: 'dialog.user_not_found'.tr(),
      message: 'profile.settings.blocked_users.error_not_found'.tr(),
      theme: theme,
      icon: Icons.person_search,
    ),
  );
}