import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_scope.dart';
import '../../../demo/demo_catalog.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common.dart';
import '../../../widgets/course_card.dart';

/// Courses in one domain (reached from the domain grid, Home chips and "See all").
class DomainScreen extends StatelessWidget {
  const DomainScreen({super.key, required this.domainId});

  final String domainId;

  @override
  Widget build(BuildContext context) {
    final domain = DemoCatalog.domain(domainId);
    final courses = DemoCatalog.coursesIn(domainId);
    AppScope.of(context); // rebuild when scope changes
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader(title: domain.name, onBack: () => context.pop()),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: domain.tint, borderRadius: BorderRadius.circular(12)),
                  child: Icon(domain.icon, color: domain.accent),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text('${domain.streams} streams · ${domain.courseCount} courses in the catalogue',
                      style: AppText.bodyMuted),
                ),
              ]),
            ),
            SectionLabel('${courses.length} ${courses.length == 1 ? 'COURSE' : 'COURSES'} IN THIS DEMO'),
            if (courses.isEmpty)
              Padding(
                padding: EdgeInsets.all(32),
                child: Text('Courses for this domain are coming soon.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
              ),
            for (final c in courses) CourseRow(course: c),
          ],
        ),
      ),
    );
  }
}
