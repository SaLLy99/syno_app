import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

String normalizeErrorMessage(String message) {
  final String trimmed = message.trim();
  if (trimmed.startsWith('Exception:')) {
    return trimmed.replaceFirst('Exception:', '').trim();
  }
  return trimmed;
}

String resolveLocalizedMessage(String message, {BuildContext? context}) {
  final String normalized = normalizeErrorMessage(message);
  final bool isTranslatableKey = normalized.startsWith('otp.') ||
      normalized.startsWith('dialog.') ||
      normalized.startsWith('register.') ||
      normalized.startsWith('profile.') ||
      normalized.startsWith('login.');

  if (isTranslatableKey && context != null) {
    return normalized.tr(context: context);
  }

  return normalized;
}
