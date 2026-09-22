import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_scope.dart';
import '../../../demo/demo_catalog.dart';
import '../../../demo/demo_state.dart';
import '../../../router.dart';
import '../../../theme/app_colors.dart';
import '../../../util/format.dart';
import '../../../widgets/common.dart';

/// Lesson player. In the demo there is no video stream: playback is simulated so the controls,
/// progress saving and "up next" flow can be tried end to end.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.courseId, required this.lessonNumber});

  final String courseId;
  final int lessonNumber;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const _speeds = [1.0, 1.25, 1.5, 2.0, 0.75];
  static const _qualities = ['Auto', '1080p', '720p', '360p'];

  late final Course course = DemoCatalog.course(widget.courseId);
  late final Lesson lesson = course.lessons[widget.lessonNumber - 1];
  late DemoState _demo;
  Timer? _ticker;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _controlsVisible = true;
  int _speedIndex = 1; // 1.25× as in the reference
  String _quality = 'Auto';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _demo = AppScope.of(context).demo;
    if (!_started) {
      _started = true;
      final saved = _demo.progressOf(course.id, lesson.number);
      _position = saved >= 1 ? Duration.zero : lesson.length * saved;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Listeners can't rebuild while the tree is being torn down, so save after this frame.
    if (_position > Duration.zero) {
      final demo = _demo, courseId = course.id, number = lesson.number, fraction = _fraction;
      Future.microtask(() => demo.saveProgress(courseId, number, fraction));
    }
    super.dispose();
  }

  double get _fraction => lesson.length.inMilliseconds == 0 ? 0 : _position.inMilliseconds / lesson.length.inMilliseconds;

  void _saveProgress() {
    if (_position > Duration.zero) _demo.saveProgress(course.id, lesson.number, _fraction);
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _ticker?.cancel();
    if (_playing) {
      _ticker = Timer.periodic(Duration(milliseconds: 250), (_) {
        final step = Duration(milliseconds: (250 * _speeds[_speedIndex]).round());
        setState(() {
          _position += step;
          if (_position >= lesson.length) {
            _position = lesson.length;
            _playing = false;
            _ticker?.cancel();
            _saveProgress();
          }
        });
      });
    } else {
      _saveProgress();
    }
  }

  void _seek(Duration to) {
    setState(() => _position = Duration(milliseconds: to.inMilliseconds.clamp(0, lesson.length.inMilliseconds)));
  }

  Future<void> _pickQuality() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text('Video quality', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          for (final q in _qualities)
            ListTile(
              title: Text(q),
              trailing: q == _quality ? Icon(Icons.check_rounded, color: AppColors.cyan) : null,
              onTap: () => Navigator.pop(context, q),
            ),
          SizedBox(height: 8),
        ]),
      ),
    );
    if (picked != null) setState(() => _quality = picked);
  }

  @override
  Widget build(BuildContext context) {
    final upNext = course.lessons.skip(lesson.number).take(3).toList();
    return Scaffold(
      body: ListenableBuilder(
        listenable: _demo,
        builder: (context, _) => ListView(
          padding: EdgeInsets.zero,
          children: [
            _video(context),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('LESSON ${Fmt.twoDigits(lesson.number)} · ${course.title.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.muted)),
                SizedBox(height: 8),
                Text(lesson.title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.2)),
              ]),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                _ActionChip(
                  icon: _demo.isDownloaded(course.id, lesson.number)
                      ? Icons.download_done_rounded
                      : Icons.download_rounded,
                  label: _demo.isDownloaded(course.id, lesson.number) ? 'Saved offline' : 'Save offline',
                  onTap: () {
                    final had = _demo.isDownloaded(course.id, lesson.number);
                    _demo.toggleDownload(course.id, lesson.number);
                    showDemoSnack(context, had ? 'Removed from downloads' : 'Saved for offline viewing (demo)');
                  },
                ),
                _ActionChip(
                  icon: _demo.isBookmarked(course.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  label: _demo.isBookmarked(course.id) ? 'Bookmarked' : 'Bookmark',
                  onTap: () => _demo.toggleBookmark(course.id),
                ),
              ]),
            ),
            if (upNext.isNotEmpty) SectionLabel('UP NEXT'),
            for (final next in upNext) _UpNextRow(course: course, lesson: next, demo: _demo),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.note,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.verified_user_outlined, size: 18, color: AppColors.success),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Encrypted stream · screen recording blocked',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _video(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return GestureDetector(
      onTap: () => setState(() => _controlsVisible = !_controlsVisible),
      child: Container(
        color: Colors.black,
        height: 220 + top,
        padding: EdgeInsets.only(top: top),
        child: Stack(children: [
          // Stand-in for the video frame.
          Center(
            child: Opacity(
              opacity: 0.14,
              child: Icon(DemoCatalog.domain(course.domainId).icon, size: 120, color: AppColors.cyan),
            ),
          ),
          AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: Duration(milliseconds: 200),
            child: IgnorePointer(ignoring: !_controlsVisible, child: _controls(context)),
          ),
        ]),
      ),
    );
  }

  Widget _controls(BuildContext context) {
    const iconColor = Color(0xFFF4F3EF); // controls sit on the black video in both themes
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(children: [
          IconButton(
            tooltip: 'Close player',
            onPressed: () => context.pop(),
            icon: Icon(Icons.close_rounded, color: iconColor),
          ),
          Spacer(),
          TextButton(
            key: Key('speedButton'),
            onPressed: () => setState(() => _speedIndex = (_speedIndex + 1) % _speeds.length),
            style: TextButton.styleFrom(foregroundColor: iconColor),
            child: Text('${_speeds[_speedIndex]}×', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'Video quality ($_quality)',
            onPressed: _pickQuality,
            icon: Icon(Icons.tune_rounded, color: iconColor, size: 20),
          ),
        ]),
      ),
      Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            tooltip: 'Back 10 seconds',
            iconSize: 30,
            onPressed: () => _seek(_position - Duration(seconds: 10)),
            icon: Icon(Icons.replay_10_rounded, color: iconColor),
          ),
          SizedBox(width: 28),
          Material(
            color: Color(0x29F4F3EF),
            shape: CircleBorder(),
            child: IconButton(
              key: Key('playPause'),
              tooltip: _playing ? 'Pause' : 'Play',
              iconSize: 34,
              padding: EdgeInsets.all(12),
              onPressed: _togglePlay,
              icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: iconColor),
            ),
          ),
          SizedBox(width: 28),
          IconButton(
            tooltip: 'Forward 10 seconds',
            iconSize: 30,
            onPressed: () => _seek(_position + Duration(seconds: 10)),
            icon: Icon(Icons.forward_10_rounded, color: iconColor),
          ),
        ]),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(6, 0, 6, 4),
        child: Column(children: [
          Slider(
            value: _fraction.clamp(0, 1),
            onChanged: (v) => _seek(lesson.length * v),
            onChangeEnd: (_) => _saveProgress(),
            semanticFormatterCallback: (v) => '${Fmt.clock(lesson.length * v)} of ${Fmt.clock(lesson.length)}',
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(Fmt.clock(_position), style: TextStyle(fontSize: 11, color: Color(0xFFD8D6D0))),
              Text(Fmt.clock(lesson.length), style: TextStyle(fontSize: 11, color: Color(0xFFD8D6D0))),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18),
            SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({required this.course, required this.lesson, required this.demo});

  final Course course;
  final Lesson lesson;
  final DemoState demo;

  @override
  Widget build(BuildContext context) {
    final canWatch = demo.canWatch(course, lesson);
    return InkWell(
      onTap: () => canWatch
          ? context.pushReplacement(Routes.player(course.id, lesson.number))
          : context.push(Routes.paywall),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          ArtTile(
            color: AppColors.thumb,
            width: 68,
            height: 46,
            radius: 9,
            child: Center(
              child: canWatch
                  ? Icon(Icons.play_arrow_rounded, size: 22, color: AppColors.text)
                  : LockIcon(size: 17),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lesson.title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: canWatch ? AppColors.text : AppColors.muted)),
              SizedBox(height: 3),
              Text('${Fmt.clock(lesson.length)}${canWatch ? '' : ' · premium'}',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
