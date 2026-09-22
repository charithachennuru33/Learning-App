import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_scope.dart';
import '../../../demo/demo_catalog.dart';
import '../../../demo/demo_state.dart';
import '../../../router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../util/format.dart';
import '../../../widgets/common.dart';

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context) {
    final demo = AppScope.of(context).demo;
    final course = DemoCatalog.course(courseId);
    final domain = DemoCatalog.domain(course.domainId);

    return ListenableBuilder(
      listenable: demo,
      builder: (context, _) {
        final showUnlockBar = demo.isLocked(course) && course.lockedCount > 0;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(child: _Banner(course: course, domain: domain, demo: demo)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Tag(domain.name.toUpperCase(), color: domain.accent),
                        Text('${course.lessons.length} lessons · ${Fmt.length(course.totalLength)}',
                            style: AppText.small),
                        if (course.freeCourse) Tag('FREE', color: AppColors.success),
                      ]),
                      SizedBox(height: 10),
                      Text(course.title, style: AppText.title),
                      SizedBox(height: 8),
                      Text('${course.instructor} · updated ${Fmt.monthYear(course.updated)}',
                          style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelPadding: EdgeInsets.only(right: 22),
                      indicatorColor: AppColors.cyan,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: AppColors.border,
                      labelColor: AppColors.text,
                      unselectedLabelColor: AppColors.muted,
                      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      tabs: [Tab(text: 'Lessons'), Tab(text: 'About'), Tab(text: 'Notes')],
                    ),
                  ),
                ),
              ],
              body: TabBarView(children: [
                _LessonList(course: course, demo: demo),
                ListView(padding: EdgeInsets.all(20), children: [
                  Text(course.about, style: AppText.body),
                  SizedBox(height: 18),
                  Text('Instructor: ${course.instructor}', style: AppText.bodyMuted),
                ]),
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Your notes for this course appear here.',
                        textAlign: TextAlign.center, style: AppText.bodyMuted),
                  ),
                ),
              ]),
            ),
            bottomNavigationBar: showUnlockBar ? _UnlockBar(course: course, demo: demo) : null,
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.course, required this.domain, required this.demo});

  final Course course;
  final Domain domain;
  final DemoState demo;

  @override
  Widget build(BuildContext context) {
    final saved = demo.isBookmarked(course.id);
    Widget roundButton({required String tooltip, required IconData icon, required VoidCallback onTap}) =>
        Material(
          color: Color(0x8C14151A),
          shape: CircleBorder(),
          child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon, color: Colors.white)),
        );

    return ArtTile(
      color: course.banner,
      icon: domain.icon,
      height: 196 + MediaQuery.paddingOf(context).top,
      radius: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            roundButton(tooltip: 'Back', icon: Icons.arrow_back_rounded, onTap: () => context.pop()),
            Spacer(),
            roundButton(
              tooltip: saved ? 'Remove from saved' : 'Save course',
              icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              onTap: () {
                demo.toggleBookmark(course.id);
                showDemoSnack(context, saved ? 'Removed from saved courses' : 'Saved to My learning');
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _LessonList extends StatelessWidget {
  const _LessonList({required this.course, required this.demo});

  final Course course;
  final DemoState demo;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: course.lessons.length,
      itemBuilder: (context, i) {
        final lesson = course.lessons[i];
        final canWatch = demo.canWatch(course, lesson);
        final progress = demo.progressOf(course.id, lesson.number);
        final meta = [
          Fmt.clock(lesson.length),
          if (progress >= 1)
            'watched'
          else if (progress > 0)
            '${(progress * 100).round()}% watched'
          else if (lesson.free && !course.freeCourse)
            'free preview',
          if (demo.isDownloaded(course.id, lesson.number)) 'saved offline',
        ].join(' · ');

        return InkWell(
          key: Key('lesson-${lesson.number}'),
          onTap: () => canWatch
              ? context.push(Routes.player(course.id, lesson.number))
              : context.push(Routes.paywall),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
            child: Row(children: [
              SizedBox(
                width: 26,
                child: Text(Fmt.twoDigits(lesson.number),
                    style: TextStyle(fontSize: 15, color: AppColors.muted)),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lesson.title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: canWatch ? AppColors.text : AppColors.muted)),
                  if (progress > 0 && progress < 1) ...[
                    SizedBox(height: 5),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 190),
                      child: GradientProgress(value: progress, height: 3),
                    ),
                  ],
                  SizedBox(height: 4),
                  Text(meta, style: AppText.small),
                ]),
              ),
              SizedBox(width: 12),
              if (canWatch)
                Icon(progress >= 1 ? Icons.check_circle_outline_rounded : Icons.play_circle_outline_rounded,
                    size: 26, color: progress >= 1 ? AppColors.success : AppColors.cyan)
              else
                LockIcon(size: 20),
            ]),
          ),
        );
      },
    );
  }
}

class _UnlockBar extends StatelessWidget {
  const _UnlockBar({required this.course, required this.demo});

  final Course course;
  final DemoState demo;

  @override
  Widget build(BuildContext context) {
    final cheapest = demo.cheapestPlan;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.nav,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${course.lockedCount} lessons locked',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('From ${Fmt.price(cheapest?.price)} for ${cheapest?.days ?? 30} days', style: AppText.small),
              ]),
            ),
            FilledButton(
              key: Key('unlockAll'),
              style: FilledButton.styleFrom(minimumSize: Size(0, 48), padding: EdgeInsets.symmetric(horizontal: 24)),
              onPressed: () => context.push(Routes.paywall),
              child: Text('Unlock all', style: TextStyle(fontSize: 15)),
            ),
          ]),
        ),
      ),
    );
  }
}
