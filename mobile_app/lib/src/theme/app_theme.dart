import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Text styles from the reference. System fonts: Roboto on Android, San Francisco on iOS.
/// Getters, because the colours follow the active theme.
abstract final class AppText {
  static TextStyle get display => TextStyle(
      fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.1, color: AppColors.text);
  static TextStyle get title => TextStyle(
      fontSize: 25, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.15, color: AppColors.text);
  static TextStyle get heading => TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text);
  static TextStyle get section => TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text);
  static TextStyle get body => TextStyle(fontSize: 14, height: 1.5, color: AppColors.text);
  static TextStyle get bodyMuted => TextStyle(fontSize: 14, height: 1.5, color: AppColors.muted);
  static TextStyle get itemTitle => TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text);
  static TextStyle get small => TextStyle(fontSize: 12, color: AppColors.muted);
  static TextStyle get tiny => TextStyle(fontSize: 11, color: AppColors.muted, height: 1.5);

  /// Upper-case section labels, e.g. "CONTINUE WATCHING".
  static TextStyle get label =>
      TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted);
}

ThemeData buildAppTheme(AppPalette p) {
  final scheme = ColorScheme(
    brightness: p.brightness,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: p.cyan,
    onSecondary: p.isDark ? p.ink : Colors.white,
    tertiary: AppColors.purple,
    onTertiary: Colors.white,
    surface: p.ink,
    onSurface: p.text,
    surfaceContainerHighest: p.surface,
    outline: p.border,
    error: p.danger,
    onError: Colors.white,
  );

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  final overlay = p.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.ink,
    canvasColor: p.ink,
    dividerColor: p.divider,
    appBarTheme: AppBarTheme(
      backgroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.text,
      elevation: 0,
      systemOverlayStyle: overlay,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.text),
    ),
    textTheme: const TextTheme().apply(bodyColor: p.text, displayColor: p.text),
    iconTheme: IconThemeData(color: p.text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      hintStyle: TextStyle(color: p.muted),
      labelStyle: TextStyle(color: p.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(p.border),
      enabledBorder: border(p.border),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(p.danger),
      focusedErrorBorder: border(p.danger, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: p.border,
        disabledForegroundColor: p.muted,
        minimumSize: const Size.fromHeight(54),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.cyan,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : p.faint),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : p.border),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.isDark ? p.surfaceRaised : const Color(0xFF24262E),
      contentTextStyle: TextStyle(color: p.isDark ? p.text : Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.isDark ? p.surface : Colors.white),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.isDark ? p.surface : Colors.white),
    drawerTheme: DrawerThemeData(backgroundColor: p.nav),
    // The player's video area is always black, so its slider is styled for a dark background.
    sliderTheme: const SliderThemeData(
      activeTrackColor: Color(0xFF00E5FF),
      inactiveTrackColor: Color(0x38F4F3EF),
      thumbColor: Color(0xFF00E5FF),
      trackHeight: 4,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.cyan),
  );
}
