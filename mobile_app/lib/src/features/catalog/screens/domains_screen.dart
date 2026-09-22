import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../demo/demo_catalog.dart';
import '../../../router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common.dart';
import '../../../widgets/course_card.dart';

class DomainsScreen extends StatefulWidget {
  const DomainsScreen({super.key});

  @override
  State<DomainsScreen> createState() => _DomainsScreenState();
}

class _DomainsScreenState extends State<DomainsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final domains = q.isEmpty ? DemoCatalog.domains : DemoCatalog.domains.where((d) => d.name.toLowerCase().contains(q)).toList();
    final courses = q.isEmpty
        ? <Course>[]
        : DemoCatalog.courses.where((c) => c.title.toLowerCase().contains(q)).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: ScreenHeader(title: 'All domains')),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: TextField(
                key: Key('domainSearch'),
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search a domain or course',
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionLabel(q.isEmpty
                ? '${DemoCatalog.domains.length} DOMAINS · ${DemoCatalog.totalCourses} COURSES'
                : '${domains.length} DOMAINS · ${courses.length} COURSES MATCH'),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                // Grows with the system text size so labels never overflow.
                mainAxisExtent: 92 + 30 * MediaQuery.textScalerOf(context).scale(1),
              ),
              delegate: SliverChildListDelegate([
                for (final d in domains) _DomainCard(domain: d),
                if (q.isEmpty) _MoreDomainsCard(),
              ]),
            ),
          ),
          if (courses.isNotEmpty) ...[
            SliverToBoxAdapter(
                child: SectionLabel('COURSES', padding: EdgeInsets.fromLTRB(20, 24, 20, 4))),
            SliverList.list(children: [for (final c in courses) CourseRow(course: c)]),
          ],
          if (q.isNotEmpty && domains.isEmpty && courses.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nothing matches that search yet.', textAlign: TextAlign.center, style: AppText.bodyMuted),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]),
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.domain});

  final Domain domain;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Routes.domain(domain.id)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: domain.tint, borderRadius: BorderRadius.circular(11)),
              child: Icon(domain.icon, size: 20, color: domain.accent),
            ),
            Spacer(),
            Text(domain.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('${domain.streams} streams · ${domain.courseCount} courses',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
      ),
    );
  }
}

class _MoreDomainsCard extends StatelessWidget {
  const _MoreDomainsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(11)),
          child: Icon(Icons.add_rounded, size: 20, color: AppColors.muted),
        ),
        Spacer(),
        Text('More domains',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        SizedBox(height: 4),
        Text('Added from the admin panel',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ]),
    );
  }
}
