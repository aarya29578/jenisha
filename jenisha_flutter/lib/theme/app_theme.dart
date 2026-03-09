import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized theme configuration for the entire app
/// All screens MUST use Theme.of(context) instead of hardcoded colors
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // ============================================================
  // CORE BRAND COLORS (extracted from Home screen)
  // ============================================================

  /// Primary Blue - Used for AppBar, primary buttons, active navigation
  static const Color primaryBlue = Color(0xFF1E40AF);

  /// Accent Green - Used for success states, CTAs
  static const Color accentGreen = Color(0xFF10B981);

  /// Success Green - Used for approved/success status indicators
  static const Color successGreen = Color(0xFF4CAF50);

  /// Warning Orange - Used for pending/warning status indicators
  static const Color warningOrange = Color(0xFFFF9800);

  /// Error Red - Used for rejected/error states
  static const Color errorRed = Color(0xFFDC2626);

  // ============================================================
  // BACKGROUND COLORS
  // ============================================================

  /// Scaffold Background - Main screen background
  static const Color backgroundGray = Color(0xFFF5F7FA);

  /// Card Background - Cards, forms, containers
  static const Color cardBackground = Color(0xFFFAFAFA);

  /// Pure White - For elevated cards and inputs
  static const Color pureWhite = Colors.white;

  // ============================================================
  // TEXT COLORS
  // ============================================================

  /// Primary text color - Headers, main content
  static const Color textPrimary = Color(0xFF333333);

  /// Secondary text color - Subheadings, descriptions
  static const Color textSecondary = Color(0xFF666666);

  /// Tertiary text color - Hints, disabled text
  static const Color textTertiary = Color(0xFF888888);

  /// Muted text - Very subtle text
  static const Color textMuted = Color(0xFF9CA3AF);

  // ============================================================
  // UI ELEMENT COLORS
  // ============================================================

  /// Border color for inputs and containers
  static const Color borderColor = Color(0xFFE5E7EB);

  /// Divider color
  static const Color dividerColor = Color(0xFFE5E7EB);

  /// Shadow color for cards
  static const Color shadowColor = Color(0x1A000000);

  // ============================================================
  // LEGACY ALIASES (for backwards compatibility)
  // ============================================================

  /// Alias for primaryBlue
  static const Color primaryColor = primaryBlue;

  /// Alias for textPrimary
  static const Color primaryTextColor = textPrimary;

  // ============================================================
  // BORDER RADIUS (16px everywhere for consistency)
  // ============================================================

  /// Standard border radius for cards
  static const double radiusCard = 16.0;

  /// Border radius for buttons
  static const double radiusButton = 12.0;

  /// Border radius for inputs
  static const double radiusInput = 12.0;

  /// Small border radius
  static const double radiusSmall = 8.0;

  // ============================================================
  // ELEVATION
  // ============================================================

  /// Card elevation
  static const double elevationCard = 4.0;

  /// Button elevation
  static const double elevationButton = 2.0;

  // ============================================================
  // SPACING
  // ============================================================

  /// Standard padding
  static const double paddingStandard = 16.0;

  /// Small padding
  static const double paddingSmall = 8.0;

  /// Large padding
  static const double paddingLarge = 24.0;

  // ============================================================
  // LIGHT THEME (Main theme for the app)
  // ============================================================

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryBlue,

      // ============================================================
      // COLOR SCHEME
      // ============================================================
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
      ).copyWith(
        primary: primaryBlue,
        secondary: accentGreen,
        error: errorRed,
        surface: pureWhite,
        surfaceContainerHighest: cardBackground,
      ),

      scaffoldBackgroundColor: backgroundGray,
      cardColor: pureWhite,
      dividerColor: dividerColor,

      // ============================================================
      // APP BAR THEME (Matches Home screen exactly)
      // ============================================================
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: pureWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: pureWhite,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: pureWhite,
        ),
      ),

      // ============================================================
      // CARD THEME (16px radius, subtle shadow)
      // ============================================================
      cardTheme: const CardThemeData(
        color: pureWhite,
        elevation: elevationCard,
        shadowColor: shadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusCard)),
        ),
        margin: EdgeInsets.zero,
      ),

      // ============================================================
      // ELEVATED BUTTON THEME (Blue background, white text)
      // ============================================================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: pureWhite,
          elevation: elevationButton,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 20,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ============================================================
      // OUTLINED BUTTON THEME
      // ============================================================
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 20,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ============================================================
      // TEXT BUTTON THEME
      // ============================================================
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ============================================================
      // INPUT DECORATION THEME (White background, 12px radius)
      // ============================================================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pureWhite,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14.0,
          horizontal: 16.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        hintStyle: const TextStyle(
          color: textTertiary,
          fontSize: 14,
        ),
      ),

      // ============================================================
      // BOTTOM NAVIGATION BAR THEME
      // ============================================================
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryBlue,
        unselectedItemColor: textTertiary,
        backgroundColor: pureWhite,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),

      // ============================================================
      // TEXT THEME (Google Fonts Inter)
      // ============================================================
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).copyWith(
        // Display styles
        displayLarge: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displaySmall: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),

        // Headline styles
        headlineLarge: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),

        // Title styles
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),

        // Body styles
        bodyLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textSecondary,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textTertiary,
        ),

        // Label styles
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelMedium: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
        labelSmall: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textTertiary,
        ),
      ),

      // ============================================================
      // ICON THEME
      // ============================================================
      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 24,
      ),

      // ============================================================
      // DIVIDER THEME
      // ============================================================
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      // ============================================================
      // CUSTOM THEME EXTENSIONS
      // ============================================================
      extensions: <ThemeExtension<dynamic>>[
        CustomColors(
          success: successGreen,
          warning: warningOrange,
          error: errorRed,
          cardBackground: cardBackground,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textTertiary: textTertiary,
          textMuted: textMuted,
          borderColor: borderColor,
          shadowColor: shadowColor,
        ),
      ],
    );
  }
}

/// Custom color extension for additional theme colors
class CustomColors extends ThemeExtension<CustomColors> {
  final Color success;
  final Color warning;
  final Color error;
  final Color cardBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;
  final Color borderColor;
  final Color shadowColor;

  const CustomColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.borderColor,
    required this.shadowColor,
  });

  @override
  CustomColors copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? cardBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textMuted,
    Color? borderColor,
    Color? shadowColor,
  }) {
    return CustomColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      cardBackground: cardBackground ?? this.cardBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textMuted: textMuted ?? this.textMuted,
      borderColor: borderColor ?? this.borderColor,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}
