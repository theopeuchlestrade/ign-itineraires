import 'package:flutter/material.dart';

class AppPalette {
  static const primary = Color(0xFF255F85);
  static const secondary = Color(0xFFB24C63);
  static const accent = Color(0xFF5B6B7A);

  // Text colors
  static const lightText = Color(0xFF000000); // Noir pour le mode clair
  static const darkText = Color(0xFFFFFFFF); // Blanc pour le mode sombre

  // Surface colors
  static const lightSurface = Color(0xFFFFFFFF); // Fond blanc
  static const darkSurface = Color(0xFF1E1E1E); // Fond sombre
  static const darkSurfaceRaised = Color(0xFF2D2D2D); // Surface élevée sombre

  // Background colors
  static const lightBackground = Color(0xFFFFFFFF); // Fond blanc
  static const darkBackground = Color(0xFF121212); // Fond sombre

  // Card colors (solid colors)
  static const lightCard = primary;
  static const darkCard = Color(0xFF72B5E3);

  // Button colors (solid colors)
  static const lightButton = primary;
  static const darkButton = Color(0xFFE2899E);

  // Utility methods
  static Color background(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;

  static Color card(Brightness brightness) =>
      brightness == Brightness.dark ? darkCard : lightCard;

  static Color button(Brightness brightness) =>
      brightness == Brightness.dark ? darkButton : lightButton;
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final textColor = isDark ? AppPalette.darkText : AppPalette.lightText;
  final surface = isDark
      ? AppPalette.darkSurfaceRaised
      : AppPalette.lightSurface;
  final mutedText = textColor.withValues(alpha: isDark ? 0.72 : 0.60);

  final scheme = ColorScheme.fromSeed(
    seedColor: AppPalette.primary,
    brightness: brightness,
    primary: isDark ? const Color(0xFF9ACBEB) : AppPalette.primary,
    secondary: isDark ? const Color(0xFFFFB1C2) : AppPalette.secondary,
    tertiary: AppPalette.accent,
    surface: surface,
    onSurface: textColor,
    onSurfaceVariant: mutedText,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
    error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
    onError: Colors.white,
    surfaceContainerLowest: isDark
        ? AppPalette.darkSurface
        : AppPalette.lightSurface,
    surfaceContainerLow: isDark
        ? const Color(0xFF2D2D2D)
        : const Color(0xFFF5F5F5),
    surfaceContainerHigh: isDark
        ? const Color(0xFF3D3D3D)
        : const Color(0xFFEEEEEE),
    surfaceContainerHighest: isDark
        ? const Color(0xFF4D4D4D)
        : const Color(0xFFE0E0E0),
    outline: isDark ? const Color(0xFF6A6A6A) : const Color(0xFF6A6A6A),
    outlineVariant: isDark ? const Color(0xFF4A4A4A) : const Color(0xFFB0B0B0),
    primaryContainer: isDark
        ? const Color(0xFF174E71)
        : const Color(0xFFCBE6F8),
    secondaryContainer: isDark
        ? const Color(0xFF7C0000)
        : const Color(0xFFFFEBEE),
  ).copyWith();
  final baseTextTheme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Manrope',
  ).textTheme.apply(bodyColor: textColor, displayColor: textColor);
  final textTheme = baseTextTheme.copyWith(
    headlineSmall: baseTextTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
    titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.4),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(
      color: mutedText,
      height: 1.4,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: isDark
        ? AppPalette.darkBackground
        : AppPalette.lightBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: surface.withValues(alpha: isDark ? 0.92 : 0.90),
      surfaceTintColor: surface,
      foregroundColor: textColor,
      elevation: 0,
      scrolledUnderElevation: 2,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.primary, width: 1.6),
      ),
      prefixIconColor: AppPalette.primary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: textColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerColor: scheme.outlineVariant,
  );
}

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(color: AppPalette.background(brightness)),
      child: child,
    );
  }
}

class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppPalette.card(brightness),
        borderRadius: BorderRadius.circular(size * 0.30),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(Icons.route_rounded, color: Colors.white, size: size * 0.60),
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.loading,
    required this.label,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled
            ? AppPalette.button(brightness)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppPalette.primary.withValues(alpha: 0.20),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant,
          shadowColor: Colors.transparent,
        ),
        icon: loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.route_rounded),
        label: Text(label),
      ),
    );
  }
}
