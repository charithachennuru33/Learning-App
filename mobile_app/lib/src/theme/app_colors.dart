import 'package:flutter/material.dart';

/// One full set of design tokens. [light] is the default; [dark] follows the screen reference
/// (ram-intellect-app-screens.html) with its orange accent replaced by the Ram Intellect logo blue/cyan.
/// Gold is reserved for Premium in both.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.ink,
    required this.surface,
    required this.surfaceRaised,
    required this.nav,
    required this.border,
    required this.divider,
    required this.thumb,
    required this.note,
    required this.dashed,
    required this.text,
    required this.muted,
    required this.faint,
    required this.disabled,
    required this.cyan,
    required this.selectedBg,
    required this.premium,
    required this.premiumBg,
    required this.premiumBorder,
    required this.premiumText,
    required this.premiumNote,
    required this.success,
    required this.successBg,
    required this.danger,
    required this.dangerText,
    required this.dangerBorder,
    required this.destructive,
    required this.demoBg,
    required this.demoBorder,
    required this.demoText,
    required this.demoIcon,
  });

  final Brightness brightness;
  final Color ink, surface, surfaceRaised, nav, border, divider, thumb, note, dashed;
  final Color text, muted, faint, disabled;
  final Color cyan, selectedBg;
  final Color premium, premiumBg, premiumBorder, premiumText, premiumNote;
  final Color success, successBg, danger, dangerText, dangerBorder, destructive;
  final Color demoBg, demoBorder, demoText, demoIcon;

  bool get isDark => brightness == Brightness.dark;

  static const light = AppPalette(
    brightness: Brightness.light,
    ink: Color(0xFFFFFFFF),
    surface: Color(0xFFF3F5F9),
    surfaceRaised: Color(0xFFEAEDF3),
    nav: Color(0xFFFFFFFF),
    border: Color(0xFFE1E5EC),
    divider: Color(0xFFEDF0F4),
    thumb: Color(0xFFE6EAF2),
    note: Color(0xFFF7F8FA),
    dashed: Color(0xFFC6CBD5),
    text: Color(0xFF14151A),
    muted: Color(0xFF5E6370),
    faint: Color(0xFF8A8F99),
    disabled: Color(0xFFB5BAC4),
    cyan: Color(0xFF0284C7), // sky-600: readable on white
    selectedBg: Color(0xFFEAF0FF),
    premium: Color(0xFFB7791F),
    premiumBg: Color(0xFFFFF7E8),
    premiumBorder: Color(0xFFF1D9A6),
    premiumText: Color(0xFF8A6116),
    premiumNote: Color(0xFF7A5A1E),
    success: Color(0xFF1E8A4C),
    successBg: Color(0xFFE6F5EC),
    danger: Color(0xFFC0392B),
    dangerText: Color(0xFFB03A2E),
    dangerBorder: Color(0xFFF0C4C0),
    destructive: Color(0xFFB03A2E),
    demoBg: Color(0xFFF4EFFF),
    demoBorder: Color(0xFFDDD0FB),
    demoText: Color(0xFF4B2E9A),
    demoIcon: Color(0xFF6D4AD6),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    ink: Color(0xFF14151A),
    surface: Color(0xFF1E2027),
    surfaceRaised: Color(0xFF22242B),
    nav: Color(0xFF191A20),
    border: Color(0xFF2A2D36),
    divider: Color(0xFF22242B),
    thumb: Color(0xFF33373F),
    note: Color(0xFF1B1C22),
    dashed: Color(0xFF3A3D47),
    text: Color(0xFFF4F3EF),
    muted: Color(0xFFA8A79F),
    faint: Color(0xFF7D7C76),
    disabled: Color(0xFF4A4D57),
    cyan: Color(0xFF00E5FF),
    selectedBg: Color(0xFF151E38),
    premium: Color(0xFFF0B429),
    premiumBg: Color(0xFF241F14),
    premiumBorder: Color(0xFF4A3C1C),
    premiumText: Color(0xFFC9B892),
    premiumNote: Color(0xFFD9C69C),
    success: Color(0xFF7FCB9B),
    successBg: Color(0xFF1B2A20),
    danger: Color(0xFFE39A9A),
    dangerText: Color(0xFFC98B8B),
    dangerBorder: Color(0xFF5A3A3A),
    destructive: Color(0xFFB57070),
    demoBg: Color(0xFF1F1934),
    demoBorder: Color(0xFF3B2F66),
    demoText: Color(0xFFD9CFFB),
    demoIcon: Color(0xFFB9A5F5),
  );
}

/// The active palette, read by every screen. Switch with [ThemeController]; the app then rebuilds.
abstract final class AppColors {
  static AppPalette _p = AppPalette.light;
  static AppPalette get palette => _p;
  static void use(AppPalette palette) => _p = palette;

  // Brand colours from the logo, the same in both themes.
  static const primary = Color(0xFF2F6BFF);
  static const purple = Color(0xFF7C3AED);
  static const logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A4DFF), Color(0xFF00E5FF), purple],
    stops: [0.0, 0.55, 1.0],
  );
  static LinearGradient get progressGradient => LinearGradient(colors: [primary, _p.cyan]);

  static Color get ink => _p.ink;
  static Color get surface => _p.surface;
  static Color get surfaceRaised => _p.surfaceRaised;
  static Color get nav => _p.nav;
  static Color get border => _p.border;
  static Color get divider => _p.divider;
  static Color get thumb => _p.thumb;
  static Color get note => _p.note;
  static Color get dashed => _p.dashed;
  static Color get text => _p.text;
  static Color get muted => _p.muted;
  static Color get faint => _p.faint;
  static Color get disabled => _p.disabled;
  static Color get cyan => _p.cyan;
  static Color get selectedBg => _p.selectedBg;
  static Color get premium => _p.premium;
  static Color get premiumBg => _p.premiumBg;
  static Color get premiumBorder => _p.premiumBorder;
  static Color get premiumText => _p.premiumText;
  static Color get premiumNote => _p.premiumNote;
  static Color get success => _p.success;
  static Color get successBg => _p.successBg;
  static Color get danger => _p.danger;
  static Color get dangerText => _p.dangerText;
  static Color get dangerBorder => _p.dangerBorder;
  static Color get destructive => _p.destructive;
  static Color get demoBg => _p.demoBg;
  static Color get demoBorder => _p.demoBorder;
  static Color get demoText => _p.demoText;
  static Color get demoIcon => _p.demoIcon;

  /// Course/domain artwork is defined as dark tints; in light mode it becomes the matching pastel.
  static Color art(Color darkTint) => _p.isDark ? darkTint : Color.lerp(darkTint, Colors.white, 0.8)!;

  /// Domain accent colours are pale; in light mode they are darkened to stay readable.
  static Color accent(Color paleAccent) => _p.isDark ? paleAccent : Color.lerp(paleAccent, Colors.black, 0.45)!;
}

/// Light by default; the sun/moon button at the top of the screens switches it.
class ThemeController extends ValueNotifier<Brightness> {
  ThemeController([super.initial = Brightness.light]) {
    AppColors.use(_paletteFor(value));
  }

  bool get isDark => value == Brightness.dark;

  void toggle() => set(isDark ? Brightness.light : Brightness.dark);

  void set(Brightness brightness) {
    AppColors.use(_paletteFor(brightness));
    value = brightness;
  }

  static AppPalette _paletteFor(Brightness b) => b == Brightness.dark ? AppPalette.dark : AppPalette.light;
}
