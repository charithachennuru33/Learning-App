import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_scope.dart';
import '../demo/demo_catalog.dart';
import '../router.dart';
import '../theme/app_colors.dart';
import '../util/format.dart';
import 'common.dart';

/// 152px-wide course tile for the horizontal rows on Home.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, this.width = 152});

  final Course course;
  final double width;

  @override
  Widget build(BuildContext context) {
    final demo = AppScope.of(context).demo;
    final domain = DemoCatalog.domain(course.domainId);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(Routes.course(course.id)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ArtTile(
            color: course.banner,
            icon: domain.icon,
            child: Stack(children: [
              if (course.freeCourse)
                Positioned(
                    top: 8, left: 8, child: Tag('FREE', color: AppColors.success, background: AppColors.surface)),
              if (demo.isLocked(course)) Positioned(top: 8, right: 8, child: LockIcon(size: 16)),
            ]),
          ),
          SizedBox(height: 8),
          Text(course.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
          SizedBox(height: 4),
          Text('${course.lessons.length} lessons · ${Fmt.length(course.totalLength)}',
              style: TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

/// Full-width row version used in lists (domain, search results, My learning).
class CourseRow extends StatelessWidget {
  const CourseRow({super.key, required this.course, this.progress});

  final Course course;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final demo = AppScope.of(context).demo;
    final domain = DemoCatalog.domain(course.domainId);
    return InkWell(
      onTap: () => context.push(Routes.course(course.id)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          ArtTile(color: course.banner, icon: domain.icon, width: 96, height: 64, radius: 10),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(course.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.25)),
              SizedBox(height: 5),
              if (progress != null) ...[
                GradientProgress(value: progress!, height: 3),
                SizedBox(height: 5),
                Text('${(progress! * 100).round()}% complete',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ] else
                Text('${domain.name} · ${course.lessons.length} lessons · ${Fmt.length(course.totalLength)}',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          SizedBox(width: 8),
          if (course.freeCourse)
            Tag('FREE', color: AppColors.success)
          else if (demo.isLocked(course))
            LockIcon(size: 16),
        ]),
      ),
    );
  }
}
