import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../demo/demo_backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The transparent logo; [markOnly] drops the "RAM INTELLECT" wordmark for small spaces.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 120, this.markOnly = false});

  final double height;
  final bool markOnly;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      markOnly ? 'assets/branding/logo_mark_transparent.png' : 'assets/branding/logo_transparent.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Ram Intellect',
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Logo mark + "Ram Intellect" wordmark in text, used in headers.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BrandLogo(height: size * 1.25, markOnly: true),
      SizedBox(width: size * 0.4),
      Flexible(
        child: Text('Ram Intellect',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: AppColors.text)),
      ),
    ]);
  }
}

/// Thin rounded progress bar in the logo blue→cyan gradient.
class GradientProgress extends StatelessWidget {
  const GradientProgress({super.key, required this.value, this.height = 4, this.background, this.color});

  final double value;
  final double height;
  final Color? background;

  /// Solid colour instead of the gradient (e.g. gold for Premium).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return Semantics(
      value: '${(value * 100).round()}%',
      child: Container(
        height: height,
        decoration: BoxDecoration(color: background ?? AppColors.border, borderRadius: radius),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0, 1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: color == null ? AppColors.progressGradient : null,
              color: color,
              borderRadius: radius,
            ),
            child: SizedBox(height: height),
          ),
        ),
      ),
    );
  }
}

class LockIcon extends StatelessWidget {
  const LockIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.lock_outline_rounded, size: size, color: AppColors.premium, semanticLabel: 'Premium');
}

/// Small rounded tag like "FREE", "ENGINEERING", "ACTIVE".
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color, this.background});

  final String text;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background ?? AppColors.surface, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: color ?? AppColors.muted)),
    );
  }
}

/// Placeholder artwork for course thumbnails and banners until real images exist.
class ArtTile extends StatelessWidget {
  const ArtTile({
    super.key,
    required this.color,
    this.height = 96,
    this.width,
    this.icon,
    this.radius = 12,
    this.child,
  });

  final Color color;
  final double height;
  final double? width;
  final IconData? icon;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final base = AppColors.art(color);
    final dark = AppColors.palette.isDark;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(base, Colors.white, dark ? 0.08 : 0.3)!, base],
        ),
      ),
      child: Stack(children: [
        if (icon != null)
          Positioned(
            right: -6,
            bottom: -8,
            child: Icon(icon,
                size: height * 0.72,
                color: (dark ? Colors.white : Colors.black).withValues(alpha: dark ? 0.07 : 0.06)),
          ),
        if (child != null) Positioned.fill(child: child!),
      ]),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 10)});

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(padding: padding, child: Text(text, style: AppText.label));
}

/// Sun/moon button that switches between the light (default) and dark themes.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppScope.of(context).theme;
    return ValueListenableBuilder(
      valueListenable: theme,
      builder: (context, _, _) => IconButton(
        key: const Key('themeToggle'),
        tooltip: theme.isDark ? 'Switch to light theme' : 'Switch to dark theme',
        onPressed: theme.toggle,
        icon: Icon(theme.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: AppColors.muted),
      ),
    );
  }
}

/// Back arrow + title header used by the reference's secondary screens, with the theme switch on the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.onBack, this.trailing = const ThemeToggleButton()});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(onBack == null ? 20 : 8, 14, 12, 12),
      child: Row(children: [
        if (onBack != null)
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.text),
          ),
        if (onBack != null) SizedBox(width: 2),
        Expanded(child: Text(title, style: AppText.heading, overflow: TextOverflow.ellipsis)),
        ?trailing,
      ]),
    );
  }
}

/// Tappable list row with icon, label, optional value and chevron (Profile screen).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.color,
    this.iconColor,
    this.chevron = true,
    this.divider = true,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Color? color;
  final Color? iconColor;
  final bool chevron;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          border: divider ? Border(bottom: BorderSide(color: AppColors.divider)) : null,
        ),
        child: Row(children: [
          Icon(icon, size: 21, color: iconColor ?? AppColors.muted),
          SizedBox(width: 14),
          Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color ?? AppColors.text))),
          if (value != null) Text(value!, style: TextStyle(fontSize: 13, color: AppColors.muted)),
          if (chevron) ...[
            SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.disabled),
          ],
        ]),
      ),
    );
  }
}

/// Explains demo mode so testers know which code to enter.
class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('demoNotice'),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.demoBg,
        border: Border.all(color: AppColors.demoBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.science_outlined, color: AppColors.demoIcon, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Demo mode: no SMS is sent. Use code ${DemoBackend.demoOtp}.',
            style: TextStyle(color: AppColors.demoText, fontSize: 13),
          ),
        ),
      ]),
    );
  }
}

void showDemoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
