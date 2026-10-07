import 'package:flutter/material.dart';

/// Palette « Rose Lotus & Blush » reprise de la version web.
class LagoColors {
  static const pink = Color(0xFFE85D75);
  static const pinkDark = Color(0xFFD81B60);
  static const pinkSoft = Color(0xFFF48FB1);
  static const blush = Color(0xFFF8BBD0);
  static const pinkLight = Color(0xFFFBEBEE);
  static const gold = Color(0xFFD4A373);
  static const goldDeep = Color(0xFFB78103);
  static const teal = Color(0xFF4DB6AC);
  static const purple = Color(0xFFBA68C8);
  static const green = Color(0xFF66BB6A);
  static const orange = Color(0xFFFFA726);
  static const danger = Color(0xFFC62828);

  static const bgLight = Color(0xFFFFF5F7);
  static const bgDark = Color(0xFF1F141D);
  static const cardDark = Color(0xFF2B1B27);
  static const textDark = Color(0xFF3A2E39);
  static const textMuted = Color(0xFF7D6B79);

  static const primaryGradient = LinearGradient(
    colors: [Color(0xFFF48FB1), Color(0xFFE85D75), Color(0xFFD81B60)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const lotusGradient = LinearGradient(
    colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0), Color(0xFFF48FB1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const adminGradient = LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFD4A373)]);

  static LinearGradient background(bool dark) => dark
      ? const LinearGradient(
          colors: [Color(0xFF1F141D), Color(0xFF2A1B27), Color(0xFF1F141D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight)
      : const LinearGradient(
          colors: [Color(0xFFFFF5F7), Color(0xFFFCECF0), Color(0xFFFDF2F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);
}

class LagoTheme {
  static const serif = 'Cormorant';
  static const sans = 'Jakarta';

  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: LagoColors.pink,
      brightness: brightness,
      primary: LagoColors.pink,
      surface: dark ? LagoColors.cardDark : Colors.white,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: sans, brightness: brightness);
    final textColor = dark ? const Color(0xFFF8E9F0) : LagoColors.textDark;

    return base.copyWith(
      scaffoldBackgroundColor: dark ? LagoColors.bgDark : LagoColors.bgLight,
      textTheme: base.textTheme.apply(bodyColor: textColor, displayColor: textColor).copyWith(
            headlineMedium: TextStyle(fontFamily: serif, fontWeight: FontWeight.w700, fontSize: 30, color: textColor),
            headlineSmall: TextStyle(fontFamily: serif, fontWeight: FontWeight.w700, fontSize: 24, color: textColor),
            titleLarge: TextStyle(fontFamily: serif, fontWeight: FontWeight.w700, fontSize: 22, color: textColor),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? LagoColors.bgDark : Colors.white.withValues(alpha: 0.9),
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: dark ? LagoColors.cardDark : Colors.white.withValues(alpha: 0.92),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: LagoColors.pinkSoft.withValues(alpha: dark ? 0.2 : 0.3)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF3A2433) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: LagoColors.blush)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: LagoColors.pinkSoft.withValues(alpha: 0.4))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: LagoColors.pink, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LagoColors.pink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: const TextStyle(fontFamily: sans, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LagoColors.pink,
          side: BorderSide(color: LagoColors.pinkSoft.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          textStyle: const TextStyle(fontFamily: sans, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: LagoColors.pink,
        backgroundColor: dark ? const Color(0xFF3A2433) : LagoColors.pinkLight,
        side: BorderSide(color: LagoColors.pinkSoft.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: TextStyle(fontFamily: sans, color: textColor, fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xF21F141D) : Colors.white.withValues(alpha: 0.96),
        indicatorColor: LagoColors.pink.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: sans, fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: LagoColors.pink,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF3E2233) : LagoColors.textDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? LagoColors.pink : null),
      ),
    );
  }
}
