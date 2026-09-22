import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../demo/demo_catalog.dart';
import '../../../demo/demo_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common.dart';
import '../widgets/admin_shell.dart';

/// Admin — upload a lesson. The file picker and pipeline are simulated in the demo.
class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  late DemoState _demo;
  bool _pipelineStarted = false;

  String _domainId = 'engineering';
  String _courseId = 'signals';
  final _title = TextEditingController();
  bool _freePreview = false;
  String? _titleError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _demo = AppScope.of(context).demo;
    if (!_pipelineStarted) {
      _pipelineStarted = true;
      _demo.startPipeline();
    }
  }

  @override
  void dispose() {
    _demo.stopPipeline();
    _title.dispose();
    super.dispose();
  }

  void _chooseFile() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give the lesson a title first');
      return;
    }
    setState(() => _titleError = null);
    _demo.queueUpload(title);
    _title.clear();
    showDemoSnack(context, 'Demo: “$title” added to the queue as a 1.6 GB file');
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AdminShell.wideBreakpoint;
    final courses = DemoCatalog.coursesIn(_domainId);
    if (!courses.any((c) => c.id == _courseId) && courses.isNotEmpty) _courseId = courses.first.id;

    final form = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminLabel('DOMAIN'),
      DropdownButtonFormField<String>(
        initialValue: _domainId,
        dropdownColor: AppColors.surface,
        items: [for (final d in DemoCatalog.domains) DropdownMenuItem(value: d.id, child: Text(d.name))],
        onChanged: (v) => setState(() => _domainId = v!),
      ),
      SizedBox(height: 18),
      AdminLabel('COURSE'),
      DropdownButtonFormField<String>(
        key: ValueKey(_domainId),
        initialValue: courses.isEmpty ? null : _courseId,
        isExpanded: true,
        dropdownColor: AppColors.surface,
        hint: Text('No courses yet'),
        items: [
          for (final c in courses)
            DropdownMenuItem(value: c.id, child: Text(c.title, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => _courseId = v!),
      ),
      SizedBox(height: 18),
      AdminLabel('LESSON TITLE'),
      TextField(
        key: Key('lessonTitle'),
        controller: _title,
        decoration: InputDecoration(hintText: 'Convolution, the intuition first', errorText: _titleError),
      ),
      SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _freePreview,
        onChanged: (v) => setState(() => _freePreview = v),
        title: Text('Free preview lesson', style: TextStyle(fontSize: 14)),
      ),
      SizedBox(height: 8),
      _DropZone(onChoose: _chooseFile),
    ]);

    final queue = ListenableBuilder(
      listenable: _demo,
      builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdminLabel('PIPELINE QUEUE'),
        for (final job in _demo.jobs) _JobCard(job: job, onRetry: () => _demo.retry(job), now: _demo.now),
        SizedBox(height: 4),
        AdminNote(
            text: 'A failed job must be visible here. Silence is how a missing lesson reaches a paying user.'),
      ]),
    );

    return AdminShell(
      section: AdminSection.videos,
      title: 'Upload a lesson',
      subtitle: 'Pick the course first, so the transcode job always has a home.',
      action: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: BorderSide(color: AppColors.border),
          backgroundColor: AppColors.surface,
          minimumSize: Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => showDemoSnack(context, 'Creating courses arrives with the catalog service.'),
        child: Text('New course'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 20, vertical: 26),
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 452, child: form),
                SizedBox(width: 28),
                Expanded(child: queue),
              ])
            : Column(children: [form, SizedBox(height: 28), queue]),
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorder(),
      child: Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(color: AppColors.note, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(Icons.upload_file_rounded, size: 30, color: AppColors.muted),
          SizedBox(height: 12),
          Text('Drop an MP4 or MOV here', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Up to 8 GB · 1080p source recommended', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          SizedBox(height: 16),
          FilledButton(
            key: Key('chooseFile'),
            style: FilledButton.styleFrom(minimumSize: Size(0, 42), padding: EdgeInsets.symmetric(horizontal: 20)),
            onPressed: onChoose,
            child: Text('Choose file', style: TextStyle(fontSize: 14)),
          ),
        ]),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.dashed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(16)));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // colour follows the theme
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onRetry, required this.now});

  final UploadJob job;
  final VoidCallback onRetry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (job.status) {
      JobStatus.uploading => ('UPLOADING ${(job.progress * 100).round()}%', AppColors.cyan),
      JobStatus.transcoding => ('TRANSCODING', AppColors.premium),
      JobStatus.ready => ('READY', AppColors.success),
      JobStatus.failed => ('FAILED', AppColors.danger),
    };

    final Widget detail = switch (job.status) {
      JobStatus.uploading => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GradientProgress(value: job.progress, height: 5),
          SizedBox(height: 10),
          Text(
            '${(job.sizeGb * job.progress).toStringAsFixed(1)} GB of ${job.sizeGb.toStringAsFixed(1)} GB · '
            '${((1 - job.progress) * 8).ceil()} min left',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ]),
      JobStatus.transcoding => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(3)),
            child: LinearProgressIndicator(
                minHeight: 5, color: AppColors.premium, backgroundColor: AppColors.premiumBorder),
          ),
          SizedBox(height: 10),
          Text('360p, 720p, 1080p · AES-128 · no percentage available',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      JobStatus.ready => Text(
          '${job.length == null ? '' : '${job.length!.inMinutes}:${(job.length!.inSeconds % 60).toString().padLeft(2, '0')} · '}'
          'ready ${_ago(now, job.readyAt!)}',
          style: TextStyle(fontSize: 12, color: AppColors.muted)),
      JobStatus.failed => Text(job.error ?? 'Failed', style: TextStyle(fontSize: 12, color: AppColors.dangerText)),
    };

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(job.lessonTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              if (job.status != JobStatus.failed)
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ]),
            SizedBox(height: 10),
            detail,
          ]),
        ),
        if (job.status == JobStatus.failed) ...[
          SizedBox(width: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.dangerBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onRetry,
            child: Text('Retry'),
          ),
        ],
      ]),
    );
  }

  static String _ago(DateTime now, DateTime then) {
    final minutes = now.difference(then).inMinutes;
    return minutes < 1 ? 'just now' : '$minutes min ago';
  }
}
