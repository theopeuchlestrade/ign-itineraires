import 'package:flutter/material.dart';

class CompanyPalette {
  // DSFR Colors - Système de Design de l'État
  static const primary = Color(0xFF000091); // Bleu Marianne
  static const secondary = Color(0xFFE1000F); // Rouge Marianne
  static const accent = Color(0xFF6A6A6A); // Gris G500

  // Text colors
  static const lightText = Color(0xFF000000); // Noir pour le mode clair
  static const darkText = Color(0xFFFFFFFF); // Blanc pour le mode sombre

  // Surface colors
  static const lightSurface = Color(0xFFFFFFFF); // Fond blanc
  static const darkSurface = Color(0xFF1E1E1E); // Fond sombre
  static const darkSurfaceRaised = Color(0xFF2D2D2D); // Surface élevée sombre

  // Background colors (solid, no gradients per DSFR)
  static const lightBackground = Color(0xFFFFFFFF); // Fond blanc
  static const darkBackground = Color(0xFF121212); // Fond sombre

  // Card colors (solid colors)
  static const lightCard = Color(0xFF000091); // Bleu Marianne pour les cartes
  static const darkCard = Color(
    0xFF1A1A5C,
  ); // Bleu foncé pour les cartes sombres

  // Button colors (solid colors)
  static const lightButton = Color(
    0xFF000091,
  ); // Bleu Marianne pour les boutons
  static const darkButton = Color(
    0xFFE1000F,
  ); // Rouge Marianne pour les boutons sombres

  // Utility methods
  static Color background(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;

  static Color card(Brightness brightness) =>
      brightness == Brightness.dark ? darkCard : lightCard;

  static Color button(Brightness brightness) =>
      brightness == Brightness.dark ? darkButton : lightButton;
}

ThemeData buildCompanyTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final textColor = isDark ? CompanyPalette.darkText : CompanyPalette.lightText;
  final surface = isDark
      ? CompanyPalette.darkSurfaceRaised
      : CompanyPalette.lightSurface;
  final mutedText = textColor.withValues(alpha: isDark ? 0.72 : 0.60);

  // DSFR Color Scheme
  final scheme = ColorScheme.fromSeed(
    seedColor: CompanyPalette.primary,
    brightness: brightness,
    primary: CompanyPalette.primary, // Bleu Marianne #000091
    secondary: CompanyPalette.secondary, // Rouge Marianne #E1000F
    tertiary: CompanyPalette.accent, // Gris G500 #6A6A6A
    surface: surface,
    onSurface: textColor,
    onSurfaceVariant: mutedText,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
    error: CompanyPalette.secondary, // Rouge Marianne pour les erreurs
    onError: Colors.white,
    surfaceContainerLowest: isDark
        ? CompanyPalette.darkSurface
        : CompanyPalette.lightSurface,
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
        ? const Color(0xFF1A1A5C)
        : const Color(0xFFE3F2FD),
    secondaryContainer: isDark
        ? const Color(0xFF7C0000)
        : const Color(0xFFFFEBEE),
  ).copyWith();
  final baseTextTheme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Marianne',
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
        ? CompanyPalette.darkBackground
        : CompanyPalette.lightBackground,
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
        borderSide: const BorderSide(color: CompanyPalette.primary, width: 1.6),
      ),
      prefixIconColor: CompanyPalette.primary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Marianne',
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

class CompanyBackground extends StatelessWidget {
  const CompanyBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(color: CompanyPalette.background(brightness)),
      child: Stack(
        children: [
          // Removed glow effects for DSFR compliance - using solid colors
          child,
        ],
      ),
    );
  }
}

class CompanyLogoMark extends StatelessWidget {
  const CompanyLogoMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CompanyPalette.card(brightness),
        borderRadius: BorderRadius.circular(size * 0.30),
        boxShadow: [
          BoxShadow(
            color: CompanyPalette.primary.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(Icons.route_rounded, color: Colors.white, size: size * 0.60),
    );
  }
}

class CompanyGradientButton extends StatelessWidget {
  const CompanyGradientButton({
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
            ? CompanyPalette.button(brightness)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: CompanyPalette.primary.withValues(alpha: 0.20),
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

class _Glow extends StatelessWidget {
  const _Glow({required this.color, this.size = 180});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.01)],
          ),
        ),
      ),
    );
  }
}
