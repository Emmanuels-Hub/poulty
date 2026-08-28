import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand + semantic colors shared by both themes.
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color primaryGreenDark = Color(0xFF66BB6A);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color criticalRed = Color(0xFFD32F2F);
  static const Color warningOrange = Color(0xFFF57C00);
  static const Color successGreen = Color(0xFF388E3C);
  static const Color infoBlue = Color(0xFF1976D2);

  // Light palette.
  static const Color _lightSurface = Color(0xFFF5F7FA);
  static const Color _lightCard = Colors.white;
  static const Color _lightTextPrimary = Color(0xFF1A1A2E);
  static const Color _lightTextSecondary = Color(0xFF6B7280);

  // Dark palette.
  static const Color _darkSurface = Color(0xFF121417);
  static const Color _darkCard = Color(0xFF1D2126);
  static const Color _darkTextPrimary = Color(0xFFECEFF1);
  static const Color _darkTextSecondary = Color(0xFF9AA5B1);

  /// Muted text color for the current theme.
  static Color secondaryText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _darkTextSecondary
          : _lightTextSecondary;

  /// Primary text color for the current theme.
  static Color primaryText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _darkTextPrimary
          : _lightTextPrimary;

  /// Hairline/grid color for dividers and chart gridlines.
  static Color hairline(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.black.withValues(alpha: 0.08);

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        primary: primaryGreen,
        surface: _lightSurface,
        card: _lightCard,
        textPrimary: _lightTextPrimary,
        textSecondary: _lightTextSecondary,
        appBarBackground: primaryGreen,
        appBarForeground: Colors.white,
      );

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        primary: primaryGreenDark,
        surface: _darkSurface,
        card: _darkCard,
        textPrimary: _darkTextPrimary,
        textSecondary: _darkTextSecondary,
        appBarBackground: _darkCard,
        appBarForeground: _darkTextPrimary,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color surface,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color appBarBackground,
    required Color appBarForeground,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        brightness: brightness,
        primary: primary,
        secondary: accentAmber,
        surface: surface,
        error: criticalRed,
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: appBarForeground,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDark
              ? BorderSide(color: Colors.white.withValues(alpha: 0.06))
              : BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.grey.shade300,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? Colors.black87 : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: isDark ? Colors.black87 : Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return TextStyle(fontSize: 12, color: textSecondary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary);
          }
          return IconThemeData(color: textSecondary);
        }),
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
            bodyColor: textPrimary,
            displayColor: textPrimary,
          ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.grey.shade200,
        thickness: 1,
      ),
    );
  }

  static Color severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return criticalRed;
      case 'warning':
        return warningOrange;
      default:
        return infoBlue;
    }
  }
}
