import 'package:flutter/material.dart';

class CompanyPalette {
  static const primary = Color(0xFF6B4DF5);
  static const secondary = Color(0xFF4FD3F3);
  static const accent = Color(0xFF8C7BFF);
  static const lightText = Color(0xFF0F172A);
  static const darkText = Color(0xFFE2E8F0);
  static const lightSurface = Color(0xFFF6F7FF);
  static const darkSurface = Color(0xFF0B0F1A);
  static const darkSurfaceRaised = Color(0xFF141B2D);

  static const lightBackgroundGradient = LinearGradient(
    colors: [Color(0xFFF6F7FF), Color(0xFFE8ECFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkBackgroundGradient = LinearGradient(
    colors: [Color(0xFF0B0F1A), Color(0xFF111827)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const lightCardGradient = LinearGradient(
    colors: [Color(0xFF7D5BFF), Color(0xFF4F7CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkCardGradient = LinearGradient(
    colors: [Color(0xFF2C2A6F), Color(0xFF21437E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const lightButtonGradient = LinearGradient(
    colors: [Color(0xFF5D5FEF), Color(0xFF4FD3F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkButtonGradient = LinearGradient(
    colors: [Color(0xFF5D5FEF), Color(0xFF2FA7C9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient backgroundGradient(Brightness brightness) =>
      brightness == Brightness.dark
      ? darkBackgroundGradient
      : lightBackgroundGradient;

  static LinearGradient cardGradient(Brightness brightness) =>
      brightness == Brightness.dark ? darkCardGradient : lightCardGradient;

  static LinearGradient buttonGradient(Brightness brightness) =>
      brightness == Brightness.dark ? darkButtonGradient : lightButtonGradient;
}

ThemeData buildCompanyTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final textColor = isDark ? CompanyPalette.darkText : CompanyPalette.lightText;
  final surface = isDark ? CompanyPalette.darkSurfaceRaised : Colors.white;
  final mutedText = textColor.withValues(alpha: isDark ? 0.72 : 0.70);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: CompanyPalette.primary,
        brightness: brightness,
      ).copyWith(
        primary: CompanyPalette.primary,
        secondary: CompanyPalette.secondary,
        tertiary: CompanyPalette.accent,
        surface: surface,
        surfaceContainerLowest: isDark
            ? CompanyPalette.darkSurface
            : CompanyPalette.lightSurface,
        surfaceContainerLow: isDark
            ? const Color(0xFF101726)
            : const Color(0xFFFBFBFF),
        surfaceContainerHigh: isDark
            ? const Color(0xFF182236)
            : const Color(0xFFEFF2FF),
        surfaceContainerHighest: isDark
            ? const Color(0xFF202A40)
            : const Color(0xFFE5EBFB),
        onSurface: textColor,
        onSurfaceVariant: mutedText,
        onPrimary: Colors.white,
        outline: isDark ? const Color(0xFF45506A) : const Color(0xFFD3DAEE),
        outlineVariant: isDark
            ? const Color(0xFF303A50)
            : const Color(0xFFE3E8F7),
        primaryContainer: isDark
            ? const Color(0xFF241F52)
            : const Color(0xFFE8E3FF),
        secondaryContainer: isDark
            ? const Color(0xFF123446)
            : const Color(0xFFDDF9FF),
        error: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
        errorContainer: isDark
            ? const Color(0xFF4B1E22)
            : const Color(0xFFFEE2E2),
      );
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
        ? CompanyPalette.darkSurface
        : CompanyPalette.lightSurface,
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

class CompanyBackground extends StatelessWidget {
  const CompanyBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: CompanyPalette.backgroundGradient(brightness),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -50,
            child: _Glow(
              color: CompanyPalette.primary.withValues(
                alpha: brightness == Brightness.dark ? 0.20 : 0.14,
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -70,
            child: _Glow(
              size: 220,
              color: CompanyPalette.secondary.withValues(
                alpha: brightness == Brightness.dark ? 0.22 : 0.18,
              ),
            ),
          ),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: CompanyPalette.cardGradient(Theme.of(context).brightness),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled
            ? CompanyPalette.buttonGradient(Theme.of(context).brightness)
            : null,
        color: enabled
            ? null
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
