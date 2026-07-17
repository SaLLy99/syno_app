import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CosmicColors {
  static const Color cosmicPurple = Color(0xFF8B5CF6);
  static const Color cosmicPink = Color(0xFFEC4899);
  static const Color cosmicBlue = Color(0xFF3B82F6); // hsl(217 91% 60%)
  static const Color deepSpace = Color(0xFF0F0A1F);
  static const Color starlight = Color(0xFFF8F7FF);
  static const Color nebulaPurple = Color(0xFF7C3AED);
  static const Color grey800 = Color(0xFF1F1B24);
  static const Color sunsetOrange = Color(0xFFF97316);

  // Common colors with specific opacities for const contexts
  static const Color cosmicPurple20 = Color(0x338B5CF6); // 0.2 alpha
  static const Color cosmicPink20 = Color(0x33EC4899);   // 0.2 alpha
  static const Color cosmicPurple30 = Color(0x4D8B5CF6); // 0.3 alpha
  static const Color cosmicPink30 = Color(0x4DEC4899);   // 0.3 alpha
  static const Color cosmicPurple50 = Color(0x808B5CF6); // 0.5 alpha
  static const Color black20 = Color(0x33000000);       // 0.2 alpha
  static const Color black30 = Color(0x4D000000);       // 0.3 alpha
  static const Color cosmicPink50 = Color(0x80EC4899);   // 0.5 alpha
  static const Color starlight70 = Color(0xB3F8F7FF);    // 0.7 alpha

  // New colors derived from Tailwind HSL values for better consistency
  static const Color deepSpaceBackgroundStart = Color(0xFF1A0B2E); // hsl(264 61% 11%)
  static const Color deepSpaceBackgroundEnd = Color(0xFF130B20);   // hsl(260 53% 8%)
  static const Color muted = Color(0xFF312640); // hsl(264 30% 20%)
  static const Color mutedForeground = Color(0xFFBDB3CC); // hsl(250 30% 70%)
  static const Color borderColor = Color(0xFF402066); // hsl(263 50% 25%)
  static const Color inputColor = Color(0xFF331A52); // hsl(263 50% 20%)
  
  static const LinearGradient cosmicGradient = LinearGradient(
    colors: <Color>[cosmicPurple, cosmicPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient deepSpaceGradient = LinearGradient(
    colors: <Color>[
      Color(0xFF4C1D95), // purple-950
      Color(0xFF581C87), // purple-900
      Color(0xFF0F172A), // slate-950
    ],
    stops: <double>[0.0, 0.4, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppSpacing {
  // Spacing values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Edge insets shortcuts
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Horizontal padding
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // Vertical padding
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

/// Border radius constants for consistent rounded corners
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

// =============================================================================
// TEXT STYLE EXTENSIONS
// =============================================================================

/// Extension to add text style utilities to BuildContext
/// Access via context.textStyles
extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

/// Helper methods for common text style modifications
extension TextStyleExtensions on TextStyle {
  /// Make text bold
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);

  /// Make text semi-bold
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);

  /// Make text medium weight
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);

  /// Make text normal weight
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);

  /// Make text light
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  /// Add custom color
  TextStyle withColor(Color color) => copyWith(color: color);

  /// Add custom size
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// =============================================================================
// COLORS
// =============================================================================

class LightModeColors {
  static const Color lightPrimary = Color(0xFF8B5CF6);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFF3E8FF);
  static const Color lightOnPrimaryContainer = Color(0xFF3B0764);
  static const Color lightSecondary = Color(0xFFEC4899);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightTertiary = Color(0xFF3B82F6);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightError = Color(0xFFDC2626);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFFEE2E2);
  static const Color lightOnErrorContainer = Color(0xFF7F1D1D);
  static const Color lightSurface = Color(0xFFFAF9FC);
  static const Color lightOnSurface = Color(0xFF1F1B24);
  static const Color lightBackground = Color(0xFFF8F7FF);
  static const Color lightSurfaceVariant = Color(0xFFF3E8FF);
  static const Color lightOnSurfaceVariant = Color(0xFF6B5B73);
  static const Color lightOutline = Color(0xFFD1C4E9);
  static const Color lightShadow = Color(0xFF000000);
  static const Color lightInversePrimary = Color(0xFFD8B4FE);
}

class DarkModeColors {
  static const Color darkPrimary = Color(0xFFA78BFA);
  static const Color darkOnPrimary = Color(0xFF3B0764);
  static const Color darkPrimaryContainer = Color(0xFF6D28D9);
  static const Color darkOnPrimaryContainer = Color(0xFFF3E8FF);
  static const Color darkSecondary = Color(0xFFF472B6);
  static const Color darkOnSecondary = Color(0xFF831843);
  static const Color darkTertiary = Color(0xFF60A5FA);
  static const Color darkOnTertiary = Color(0xFF1E3A8A);
  static const Color darkError = Color(0xFFFCA5A5);
  static const Color darkOnError = Color(0xFF7F1D1D);
  static const Color darkErrorContainer = Color(0xFF991B1B);
  static const Color darkOnErrorContainer = Color(0xFFFEE2E2);
  static const Color darkSurface = Color(0xFF1A0B2E);
  static const Color darkOnSurface = Color(0xFFF8F7FF);
  static const Color darkSurfaceVariant = Color(0xFF2D1B4E);
  static const Color darkOnSurfaceVariant = Color(0xFFD1C4E9);
  static const Color darkOutline = Color(0xFF6D28D9);
  static const Color darkShadow = Color(0xFF000000);
  static const Color darkInversePrimary = Color(0xFF8B5CF6);
}

/// Font size constants
class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

// =============================================================================
// THEMES
// =============================================================================

/// Light theme with modern, neutral aesthetic
ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: LightModeColors.lightPrimary,
    onPrimary: LightModeColors.lightOnPrimary,
    primaryContainer: LightModeColors.lightPrimaryContainer,
    onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
    secondary: LightModeColors.lightSecondary,
    onSecondary: LightModeColors.lightOnSecondary,
    tertiary: LightModeColors.lightTertiary,
    onTertiary: LightModeColors.lightOnTertiary,
    error: LightModeColors.lightError,
    onError: LightModeColors.lightOnError,
    errorContainer: LightModeColors.lightErrorContainer,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    surface: LightModeColors.lightSurface,
    onSurface: LightModeColors.lightOnSurface,
    surfaceContainerHighest: LightModeColors.lightSurfaceVariant,
    onSurfaceVariant: LightModeColors.lightOnSurfaceVariant,
    outline: LightModeColors.lightOutline,
    shadow: LightModeColors.lightShadow,
    inversePrimary: LightModeColors.lightInversePrimary,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: LightModeColors.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: LightModeColors.lightOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: LightModeColors.lightOutline.withOpacity(0.2),
        width: 1,
      ),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.light),
);

/// Dark theme with good contrast and readability
ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.dark(
    primary: DarkModeColors.darkPrimary,
    onPrimary: DarkModeColors.darkOnPrimary,
    primaryContainer: DarkModeColors.darkPrimaryContainer,
    onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
    secondary: DarkModeColors.darkSecondary,
    onSecondary: DarkModeColors.darkOnSecondary,
    tertiary: DarkModeColors.darkTertiary,
    onTertiary: DarkModeColors.darkOnTertiary,
    error: DarkModeColors.darkError,
    onError: DarkModeColors.darkOnError,
    errorContainer: DarkModeColors.darkErrorContainer,
    onErrorContainer: DarkModeColors.darkOnErrorContainer,
    surface: DarkModeColors.darkSurface,
    onSurface: DarkModeColors.darkOnSurface,
    surfaceContainerHighest: DarkModeColors.darkSurfaceVariant,
    onSurfaceVariant: DarkModeColors.darkOnSurfaceVariant,
    outline: DarkModeColors.darkOutline,
    shadow: DarkModeColors.darkShadow,
    inversePrimary: DarkModeColors.darkInversePrimary,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DarkModeColors.darkSurface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: DarkModeColors.darkOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: DarkModeColors.darkOutline.withOpacity(0.2),
        width: 1,
      ),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.dark),
);

TextTheme _buildTextTheme(Brightness brightness) {
  return TextTheme(
    displayLarge: GoogleFonts.outfit(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
    ),
    displayMedium: GoogleFonts.outfit(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w400,
    ),
    displaySmall: GoogleFonts.outfit(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w400,
    ),
    headlineLarge: GoogleFonts.outfit(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    headlineMedium: GoogleFonts.outfit(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: GoogleFonts.outfit(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: GoogleFonts.outfit(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.outfit(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: GoogleFonts.outfit(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: GoogleFonts.outfit(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: GoogleFonts.outfit(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.outfit(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    bodyLarge: GoogleFonts.outfit(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
    ),
    bodyMedium: GoogleFonts.outfit(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
    ),
    bodySmall: GoogleFonts.outfit(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    ),
  );
}
