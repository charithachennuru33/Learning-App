import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common.dart';

enum AdminSection { videos, categories, pricing, coupons }

/// Admin layout from the reference: 224px sidebar on wide screens (tablet / Flutter Web),
/// collapsing to a drawer on phones.
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.section,
    required this.title,
    required this.subtitle,
    required this.body,
    this.action,
  });

  static const wideBreakpoint = 900.0;

  final AdminSection section;
  final String title;
  final String subtitle;
  final Widget body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final header = Container(
      padding: EdgeInsets.fromLTRB(wide ? 32 : 20, wide ? 28 : 8, wide ? 32 : 20, 20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.title.copyWith(fontSize: wide ? 27 : 23)),
            SizedBox(height: 7),
            Text(subtitle, style: AppText.bodyMuted),
          ]),
        ),
        if (action != null) ...[SizedBox(width: 16), action!],
        if (wide) ...[SizedBox(width: 8), ThemeToggleButton()],
      ]),
    );
    final content = Column(children: [
      header,
      Expanded(child: body),
    ]);

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(children: [
            SizedBox(width: 224, child: _Sidebar(section: section)),
            Expanded(child: content),
          ]),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          ThemeToggleButton(),
          TextButton(onPressed: () => context.go(Routes.home), child: Text('Open the app')),
        ],
      ),
      drawer: Drawer(backgroundColor: AppColors.nav, child: SafeArea(child: _Sidebar(section: section))),
      body: content,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.section});

  final AdminSection section;

  @override
  Widget build(BuildContext context) {
    Widget item(AdminSection s, IconData icon, String label, String route) {
      final selected = s == section;
      return InkWell(
        onTap: () {
          if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) Navigator.pop(context);
          if (route != GoRouterState.of(context).matchedLocation) context.pushReplacement(route);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceRaised : null,
            border: Border(left: BorderSide(color: selected ? AppColors.cyan : Colors.transparent, width: 2)),
          ),
          child: Row(children: [
            Icon(icon, size: 19, color: selected ? AppColors.text : AppColors.muted),
            SizedBox(width: 11),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.text : AppColors.muted)),
          ]),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.nav,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(22, 0, 22, 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BrandLogo(height: 34, markOnly: true),
            SizedBox(height: 10),
            Text('Ram Intellect LLP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 3),
            Text('ADMIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.3,
                color: AppColors.muted)),
          ]),
        ),
        item(AdminSection.videos, Icons.upload_rounded, 'Videos', Routes.adminUpload),
        item(AdminSection.categories, Icons.grid_view_outlined, 'Categories', Routes.adminUpload),
        item(AdminSection.pricing, Icons.show_chart_rounded, 'Pricing', Routes.adminPricing),
        item(AdminSection.coupons, Icons.confirmation_number_outlined, 'Coupons', Routes.adminPricing),
        Spacer(),
        InkWell(
          onTap: () => context.go(Routes.home),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Text('Open the app', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ),
        ),
      ]),
    );
  }
}

/// Uppercase field label used in admin forms.
class AdminLabel extends StatelessWidget {
  const AdminLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: AppColors.muted)),
      );
}

/// Info / warning strip used at the top or bottom of admin pages.
class AdminNote extends StatelessWidget {
  const AdminNote({super.key, required this.text, this.warning = false});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: warning ? AppColors.premiumBg : AppColors.note,
        border: Border.all(color: warning ? AppColors.premiumBorder : AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(warning ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: 18, color: warning ? AppColors.premium : AppColors.muted),
        SizedBox(width: 11),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, height: 1.5, color: warning ? AppColors.premiumNote : AppColors.muted)),
        ),
      ]),
    );
  }
}
