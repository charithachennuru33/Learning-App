import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_scope.dart';
import '../../../router.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common.dart';
import '../../../widgets/course_card.dart';

/// "My learning" tab: courses in progress and saved courses.
class MyLearningScreen extends StatelessWidget {
  const MyLearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demo = AppScope.of(context).demo;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: demo,
          builder: (context, _) {
            final inProgress = demo.inProgress;
            final saved = demo.bookmarkedCourses;
            return ListView(
              padding: EdgeInsets.only(bottom: 24),
              children: [
                ScreenHeader(title: 'My learning'),
                SectionLabel('IN PROGRESS'),
                if (inProgress.isEmpty)
                  _Empty(
                    text: 'Start a lesson and it shows up here.',
                    action: 'Browse domains',
                    onTap: () => context.go(Routes.domains),
                  ),
                for (final item in inProgress) CourseRow(course: item.course, progress: item.progress),
                SectionLabel('SAVED', padding: EdgeInsets.fromLTRB(20, 24, 20, 10)),
                if (saved.isEmpty) _Empty(text: 'Tap the bookmark on a course to save it for later.'),
                for (final course in saved) CourseRow(course: course),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.action, this.onTap});

  final String text;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(children: [
        Expanded(child: Text(text, style: AppText.bodyMuted)),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ]),
    );
  }
}
