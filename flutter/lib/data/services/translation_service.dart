import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Provides local text translation using the easy_localization package.
class TranslationService {
  /// Translates a given text string.
  ///
  /// This function uses the `tr()` extension method from `easy_localization`
  /// to find a translation for the given [text] key in the current locale.
  ///
  /// [context] The build context to access localization.
  /// [text] The translation key.
  Future<String> translateText(
    BuildContext context,
    String text,
  ) async {
    if (context.mounted) {
      final String translatedText = text.tr();
      // Check if a translation was found. If not, .tr() returns the key itself.
      if (translatedText != text) {
        return translatedText;
      } else if (kDebugMode) {
        // Log missing keys in debug mode to make them easier to find.
        print('Missing translation key: "$text" for language: "${context.locale.languageCode}"');
      }
    }
    // Fallback to the original text (the key) if no translation is found.
    return text;
  }
}