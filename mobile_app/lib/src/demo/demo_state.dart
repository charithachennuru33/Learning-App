import 'dart:async';

import 'package:flutter/foundation.dart';

import 'demo_catalog.dart';

/// In-memory app state for the demo screens: subscription, watch progress, bookmarks, downloads, and the
/// admin data (plans, coupons, upload queue). Nothing leaves the device.
class DemoState extends ChangeNotifier {
  DemoState({DateTime Function()? clock}) : _now = clock ?? DateTime.now {
    reset();
  }

  final DateTime Function() _now;
  DateTime get now => _now();

  // --- Learner ---------------------------------------------------------------------------------------------

  String learnerName = 'Demo Learner';

  Plan? _activePlan;
  DateTime? _subscribedOn;
  Plan? get activePlan => _activePlan;
  bool get isPremium => _activePlan != null;
  DateTime? get renewsOn => _subscribedOn?.add(Duration(days: _activePlan!.days));
  int get daysLeft => isPremium ? renewsOn!.difference(now).inDays.clamp(0, 100000) : 0;
  double get planUsed => isPremium ? 1 - daysLeft / _activePlan!.days : 0;

  final Map<String, double> _progress = {}; // "course/lesson" -> 0..1
  final Set<String> _bookmarks = {}; // course ids
  final Set<String> _downloads = {}; // "course/lesson"
  String? _lastCourseId;
  int? _lastLesson;

  static String _key(String courseId, int lesson) => '$courseId/$lesson';

  /// Clears the learner's data (sign-out). Admin data survives.
  void reset() {
    _activePlan = null;
    _subscribedOn = null;
    _progress
      ..clear()
      ..addAll({_key('probability', 6): 0.62, _key('signals', 2): 0.45, _key('signals', 1): 1.0});
    _bookmarks
      ..clear()
      ..addAll({'signals', 'dsa', 'cardiac'});
    _downloads.clear();
    _lastCourseId = 'probability';
    _lastLesson = 6;
    notifyListeners();
  }

  bool canWatch(Course course, Lesson lesson) => course.isFree(lesson) || isPremium;
  bool isLocked(Course course) => !course.freeCourse && !isPremium;

  double progressOf(String courseId, int lesson) => _progress[_key(courseId, lesson)] ?? 0;

  void saveProgress(String courseId, int lesson, double fraction) {
    _progress[_key(courseId, lesson)] = fraction.clamp(0, 1);
    _lastCourseId = courseId;
    _lastLesson = lesson;
    notifyListeners();
  }

  /// The lesson to resume on Home, if any.
  ({Course course, Lesson lesson, double progress})? get continueWatching {
    if (_lastCourseId == null) return null;
    final course = DemoCatalog.course(_lastCourseId!);
    final lesson = course.lessons[_lastLesson! - 1];
    return (course: course, lesson: lesson, progress: progressOf(course.id, lesson.number));
  }

  /// Courses with any progress, most complete first.
  List<({Course course, double progress})> get inProgress {
    final result = <({Course course, double progress})>[];
    for (final course in DemoCatalog.courses) {
      final watched = course.lessons.fold<double>(0, (sum, l) => sum + progressOf(course.id, l.number));
      if (watched > 0) result.add((course: course, progress: watched / course.lessons.length));
    }
    result.sort((a, b) => b.progress.compareTo(a.progress));
    return result;
  }

  bool isBookmarked(String courseId) => _bookmarks.contains(courseId);
  List<Course> get bookmarkedCourses => DemoCatalog.courses.where((c) => _bookmarks.contains(c.id)).toList();

  void toggleBookmark(String courseId) {
    _bookmarks.contains(courseId) ? _bookmarks.remove(courseId) : _bookmarks.add(courseId);
    notifyListeners();
  }

  bool isDownloaded(String courseId, int lesson) => _downloads.contains(_key(courseId, lesson));
  int get downloadCount => _downloads.length;

  /// Rough size: ~250 MB per 1080p lesson.
  double get downloadsGb => _downloads.length * 0.25;

  void toggleDownload(String courseId, int lesson) {
    final key = _key(courseId, lesson);
    _downloads.contains(key) ? _downloads.remove(key) : _downloads.add(key);
    notifyListeners();
  }

  /// Demo purchase: no payment is taken.
  void subscribe(Plan plan, {Coupon? coupon}) {
    _activePlan = plan;
    _subscribedOn = now;
    if (coupon != null) coupon.used++;
    notifyListeners();
  }

  void cancelSubscription() {
    _activePlan = null;
    _subscribedOn = null;
    notifyListeners();
  }

  // --- Admin: pricing & coupons ------------------------------------------------------------------------------

  final List<Plan> plans = DemoCatalog.seedPlans();
  final List<Coupon> coupons = DemoCatalog.seedCoupons();

  List<Plan> get visiblePlans => plans.where((p) => p.visible && (p.price ?? 1) > 0).toList();

  Plan? get cheapestPlan => visiblePlans.isEmpty ? null : visiblePlans.first;

  void updatePlan(Plan plan, {int? price, bool clearPrice = false, bool? visible}) {
    if (clearPrice) plan.price = null;
    if (price != null) plan.price = price;
    if (visible != null) plan.visible = visible;
    notifyListeners();
  }

  void addPlan(Plan plan) {
    plans.add(plan);
    notifyListeners();
  }

  /// Case-insensitive lookup of a usable coupon.
  Coupon? findCoupon(String code) {
    final wanted = code.trim().toUpperCase();
    for (final c in coupons) {
      if (c.code == wanted) return c;
    }
    return null;
  }

  /// Returns an error message, or null when the coupon was created.
  String? addCoupon({required String code, required String value, required String maxUses}) {
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{3,20}$').hasMatch(normalized)) return 'Use 3–20 letters or digits';
    if (findCoupon(normalized) != null) return 'That code already exists';
    final percent = int.tryParse(value.trim().replaceAll('%', ''));
    if (percent == null || percent < 1 || percent > 100) return 'Value must be a percentage from 1 to 100';
    final max = int.tryParse(maxUses.trim());
    if (max == null || max < 1) return 'Max uses must be a positive number';
    coupons.insert(0, Coupon(code: normalized, percentOff: percent, maxUses: max,
        expires: now.add(const Duration(days: 30))));
    notifyListeners();
    return null;
  }

  // --- Admin: upload pipeline (simulated) ---------------------------------------------------------------------

  final List<UploadJob> jobs = DemoCatalog.seedJobs();
  Timer? _pipeline;
  int _watchers = 0;

  /// Start/stop the simulated upload + transcode progress while the upload screen is visible.
  void startPipeline() {
    _watchers++;
    _pipeline ??= Timer.periodic(const Duration(milliseconds: 400), (_) => _tick());
  }

  void stopPipeline() {
    _watchers = (_watchers - 1).clamp(0, 1 << 20);
    if (_watchers == 0) {
      _pipeline?.cancel();
      _pipeline = null;
    }
  }

  final Map<UploadJob, int> _transcodeTicks = {};

  void _tick() {
    var changed = false;
    for (final job in jobs) {
      switch (job.status) {
        case JobStatus.uploading:
          job.progress = (job.progress + 0.02).clamp(0, 1);
          if (job.progress >= 1) job.status = JobStatus.transcoding;
          changed = true;
        case JobStatus.transcoding:
          final ticks = (_transcodeTicks[job] ?? 0) + 1;
          _transcodeTicks[job] = ticks;
          if (ticks >= 20) {
            job.status = JobStatus.ready;
            job.readyAt = now;
            job.length ??= Duration(minutes: 12 + jobs.indexOf(job) % 9, seconds: 20);
            _transcodeTicks.remove(job);
            changed = true;
          }
        case JobStatus.ready:
        case JobStatus.failed:
          break;
      }
    }
    if (changed) notifyListeners();
  }

  void queueUpload(String lessonTitle) {
    jobs.insert(0, UploadJob(lessonTitle: lessonTitle, status: JobStatus.uploading, sizeGb: 1.6));
    notifyListeners();
  }

  void retry(UploadJob job) {
    job
      ..status = JobStatus.transcoding
      ..error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pipeline?.cancel();
    super.dispose();
  }
}
