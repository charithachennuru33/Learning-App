import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_scope.dart';
import '../../../demo/demo_catalog.dart';
import '../../../router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common.dart';
import '../../../widgets/course_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demo = AppScope.of(context).demo;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: demo,
          builder: (context, _) {
            final resume = demo.continueWatching;
            final trending = DemoCatalog.courses.where((c) => c.trending && c.domainId == 'engineering').toList();
            final newInMedicine = DemoCatalog.courses.where((c) => c.isNew && c.domainId == 'medicine').toList();
            return ListView(
              padding: EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 16, 14),
                  child: Row(children: [
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: BrandHeader(size: 24))),
                    ThemeToggleButton(),
                    SizedBox(width: 4),
                    Tooltip(
                      message: 'Open profile',
                      child: InkWell(
                        customBorder: CircleBorder(),
                        onTap: () => context.go(Routes.profile),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.border,
                          child: Icon(Icons.person_outline_rounded, color: AppColors.muted),
                        ),
                      ),
                    ),
                  ]),
                ),
                if (!demo.isPremium) _PremiumBanner(),
                if (resume != null)
                  _ContinueWatching(course: resume.course, lesson: resume.lesson, progress: resume.progress),
                _DomainChips(),
                _CourseRowSection(title: 'Trending in Engineering', courses: trending, domainId: 'engineering'),
                SizedBox(height: 18),
                _CourseRowSection(title: 'New in Medicine', courses: newInMedicine, domainId: 'medicine'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Material(
        color: AppColors.premiumBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.premiumBorder),
        ),
        child: InkWell(
          key: Key('premiumBanner'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(Routes.paywall),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              LockIcon(size: 18),
              SizedBox(width: 10),
              Expanded(
                  child: Text('Premium locked — unlock every domain',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              Text('Plans', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.premium)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ContinueWatching extends StatelessWidget {
  const _ContinueWatching({required this.course, required this.lesson, required this.progress});

  final Course course;
  final Lesson lesson;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final left = Duration(seconds: (lesson.length.inSeconds * (1 - progress)).round());
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('continueWatching'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(Routes.player(course.id, lesson.number)),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              ArtTile(
                color: AppColors.thumb,
                width: 96,
                height: 66,
                radius: 10,
                child: Center(child: Icon(Icons.play_circle_outline_rounded, size: 30)),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('CONTINUE WATCHING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 0.9, color: AppColors.muted)),
                  SizedBox(height: 6),
                  Text(lesson.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(height: 7),
                  GradientProgress(value: progress),
                  SizedBox(height: 7),
                  Text('${left.inMinutes.clamp(1, 999)} min left · Lesson ${lesson.number} of ${course.lessons.length}',
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DomainChips extends StatelessWidget {
  const _DomainChips();

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, {required bool primary, required VoidCallback onTap}) {
      return Padding(
        padding: EdgeInsets.only(right: 8),
        child: Material(
          color: primary ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
                      color: primary ? Colors.white : AppColors.muted)),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(20, 0, 12, 20),
        children: [
          chip('All domains', primary: true, onTap: () => context.go(Routes.domains)),
          for (final d in DemoCatalog.domains)
            chip(d.name, primary: false, onTap: () => context.push(Routes.domain(d.id))),
        ],
      ),
    );
  }
}

class _CourseRowSection extends StatelessWidget {
  const _CourseRowSection({required this.title, required this.courses, required this.domainId});

  final String title;
  final List<Course> courses;
  final String domainId;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 8, 4),
        child: Row(children: [
          Expanded(child: Text(title, style: AppText.section)),
          TextButton(onPressed: () => context.push(Routes.domain(domainId)), child: Text('See all')),
        ]),
      ),
      SizedBox(
        height: 184,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 20),
          itemCount: courses.length,
          separatorBuilder: (_, _) => SizedBox(width: 12),
          itemBuilder: (_, i) => CourseCard(course: courses[i]),
        ),
      ),
    ]);
  }
}
