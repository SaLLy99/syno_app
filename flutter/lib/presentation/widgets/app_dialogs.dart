import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:syno_app/theme.dart';

class DialogAction {
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  DialogAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });
}

class AppDialogs {
  static Future<void> showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: CosmicColors.grey800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          title: Text(
            title,
            style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          content: Text(
            message,
            style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'dialog.ok'.tr(),
                style: const TextStyle(
                  color: CosmicColors.cosmicPink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    required List<DialogAction> actions,
    VoidCallback? onDismiss,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: CosmicColors.grey800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          title: Text(
            title,
            style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          content: Text(
            content,
            style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          actions: actions.map((action) {
            return TextButton(
              onPressed: action.onPressed,
              child: Text(
                action.label,
                style: TextStyle(
                  color: action.isDestructive ? Colors.redAccent : CosmicColors.cosmicPink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        );
      },
    ).then((value) {
      if (value == null && onDismiss != null) {
        onDismiss();
      }
      return value;
    });
  }

  static Future<void> showSuccessDialog(
    BuildContext context,
    String title,
    String message, {
    required VoidCallback onDismiss,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: CosmicColors.grey800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          title: Text(
            title,
            style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          content: Text(
            message,
            style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDismiss();
              },
              child: Text(
                'dialog.ok'.tr(),
                style: const TextStyle(
                  color: CosmicColors.cosmicPink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}