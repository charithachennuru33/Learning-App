import 'package:flutter/material.dart';

/// Demo content for the screens. Replace with API data once the catalog service exists.

class Domain {
  const Domain({
    required this.id,
    required this.name,
    required this.icon,
    required this.tint,
    required this.accent,
    required this.streams,
    required this.courseCount,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color tint; // icon tile background
  final Color accent; // icon + tag colour
  final int streams;
  final int courseCount; // catalogue-wide figure shown on the card
}

class Lesson {
  const Lesson({required this.number, required this.title, required this.length, this.free = false});

  final int number;
  final String title;
  final Duration length;
  final bool free;
}

class Course {
  const Course({
    required this.id,
    required this.domainId,
    required this.title,
    required this.instructor,
    required this.updated,
    required this.banner,
    required this.lessons,
    required this.about,
    this.freeCourse = false,
    this.trending = false,
    this.isNew = false,
  });

  final String id;
  final String domainId;
  final String title;
  final String instructor;
  final DateTime updated;
  final Color banner;
  final List<Lesson> lessons;
  final String about;

  /// Every lesson is free (shown with a FREE badge).
  final bool freeCourse;
  final bool trending;
  final bool isNew;

  Duration get totalLength => lessons.fold(Duration.zero, (sum, l) => sum + l.length);
  bool isFree(Lesson lesson) => freeCourse || lesson.free;
  int get lockedCount => freeCourse ? 0 : lessons.where((l) => !l.free).length;
}

class Plan {
  Plan({
    required this.id,
    required this.name,
    required this.days,
    required this.subtitle,
    required this.storeProductId,
    this.price,
    this.visible = true,
  });

  final String id;
  String name;
  int days;
  String subtitle;
  String storeProductId;

  /// Rupees. Null until pricing is decided; shown as ₹[PRICE].
  int? price;
  bool visible;
}

class Coupon {
  Coupon({
    required this.code,
    required this.maxUses,
    required this.expires,
    this.percentOff,
    this.flatOff,
    this.used = 0,
  });

  final String code;
  final int? percentOff;

  /// Rupees off; null while unset (shown as ₹[FLAT] off).
  final int? flatOff;
  final int maxUses;
  int used;
  final DateTime expires;

  bool get spent => used >= maxUses;
  bool isExpired(DateTime now) => now.isAfter(expires);
  bool isUsable(DateTime now) => !spent && !isExpired(now);
  String get discountLabel =>
      percentOff != null ? '$percentOff%' : (flatOff == null ? '₹[FLAT] off' : '₹$flatOff off');
}

enum JobStatus { uploading, transcoding, ready, failed }

class UploadJob {
  UploadJob({
    required this.lessonTitle,
    required this.status,
    this.progress = 0,
    this.sizeGb = 1.0,
    this.error,
    this.readyAt,
    this.length,
  });

  final String lessonTitle;
  JobStatus status;
  double progress; // 0..1, uploading only
  double sizeGb;
  String? error;
  DateTime? readyAt;
  Duration? length;
}

// ---------------------------------------------------------------------------------------------------------

abstract final class DemoCatalog {
  static const domains = <Domain>[
    Domain(id: 'engineering', name: 'Engineering', icon: Icons.engineering_outlined,
        tint: Color(0xFF2F3A3D), accent: Color(0xFF8FC7CE), streams: 6, courseCount: 92),
    Domain(id: 'medicine', name: 'Medicine', icon: Icons.medical_services_outlined,
        tint: Color(0xFF34383F), accent: Color(0xFFE39A9A), streams: 4, courseCount: 61),
    Domain(id: 'finance', name: 'Finance', icon: Icons.show_chart,
        tint: Color(0xFF33372C), accent: Color(0xFFBCCB8F), streams: 3, courseCount: 45),
    Domain(id: 'law', name: 'Law', icon: Icons.gavel_outlined,
        tint: Color(0xFF3A3340), accent: Color(0xFFC3A8D6), streams: 2, courseCount: 28),
    Domain(id: 'civil', name: 'Civil services', icon: Icons.account_balance_outlined,
        tint: Color(0xFF2C3540), accent: Color(0xFF93B6D6), streams: 5, courseCount: 74),
    Domain(id: 'management', name: 'Management', icon: Icons.work_outline,
        tint: Color(0xFF3C3630), accent: Color(0xFFD8B98F), streams: 3, courseCount: 40),
    Domain(id: 'design', name: 'Design', icon: Icons.hexagon_outlined,
        tint: Color(0xFF2E3A33), accent: Color(0xFF9BCFAD), streams: 2, courseCount: 19),
  ];

  static int get totalCourses => domains.fold(0, (sum, d) => sum + d.courseCount);

  static Domain domain(String id) => domains.firstWhere((d) => d.id == id);

  static final courses = <Course>[
    Course(
      id: 'signals',
      domainId: 'engineering',
      title: 'Signals & Systems from scratch',
      instructor: 'Dr. [INSTRUCTOR NAME]',
      updated: DateTime(2026, 8),
      banner: const Color(0xFF2F3A3D),
      trending: true,
      about: 'Build intuition for signals, convolution and transforms before the maths. Every idea is '
          'shown on a real signal first, then formalised. Suits second-year ECE/EEE students and GATE aspirants.',
      lessons: _lessons([
        ('What a signal actually is', 680, true),
        ('Continuous vs discrete time', 845, true),
        ('Convolution, the intuition first', 1120, false),
        ('Fourier series, term by term', 1335, false),
        ('The Laplace transform', 1190, false),
        ('Sampling and aliasing', 990, false),
      ], total: 24, avgSeconds: 890),
    ),
    Course(
      id: 'dsa',
      domainId: 'engineering',
      title: 'Data structures, interview grade',
      instructor: '[INSTRUCTOR NAME]',
      updated: DateTime(2026, 7),
      banner: const Color(0xFF3A3340),
      trending: true,
      about: 'Arrays to graphs, taught the way interviewers ask about them: pattern first, then code, then '
          'complexity. Includes 60 worked problems.',
      lessons: _lessons([
        ('Big-O without the fear', 760, true),
        ('Arrays and two pointers', 980, false),
        ('Hash maps in practice', 1040, false),
      ], total: 31, avgSeconds: 1015),
    ),
    Course(
      id: 'probability',
      domainId: 'engineering',
      title: 'Probability, made practical',
      instructor: '[INSTRUCTOR NAME]',
      updated: DateTime(2026, 6),
      banner: const Color(0xFF2C3540),
      freeCourse: true,
      trending: true,
      about: 'A free course on the probability every engineer uses: counting, conditional probability, '
          'Bayes and distributions, with everyday examples.',
      lessons: _lessons([
        ('Counting without tears', 720, true),
        ('Sample spaces and events', 810, true),
        ('Conditional probability', 900, true),
        ('Independence, properly', 780, true),
        ('The law of total probability', 840, true),
        ("Bayes' theorem in practice", 1935, true),
      ], total: 18, avgSeconds: 850, allFree: true),
    ),
    Course(
      id: 'cardiac',
      domainId: 'medicine',
      title: 'Cardiac physiology basics',
      instructor: 'Dr. [INSTRUCTOR NAME]',
      updated: DateTime(2026, 9),
      banner: const Color(0xFF34383F),
      freeCourse: true,
      isNew: true,
      about: 'The heart as a pump and an electrical system: the cardiac cycle, ECG basics and pressure-volume '
          'loops, for first-year MBBS.',
      lessons: _lessons([
        ('The cardiac cycle in one diagram', 900, true),
        ('Reading an ECG, lead by lead', 1080, true),
      ], total: 12, avgSeconds: 925, allFree: true),
    ),
    Course(
      id: 'pharma',
      domainId: 'medicine',
      title: 'Pharmacology, unit one',
      instructor: 'Dr. [INSTRUCTOR NAME]',
      updated: DateTime(2026, 9),
      banner: const Color(0xFF3C3630),
      isNew: true,
      about: 'Pharmacokinetics and pharmacodynamics with clinical cases: absorption, distribution, '
          'metabolism, excretion, and dose-response.',
      lessons: _lessons([
        ('How drugs move through the body', 1020, true),
        ('Half-life and dosing intervals', 1100, false),
      ], total: 19, avgSeconds: 1040),
    ),
    Course(
      id: 'markets',
      domainId: 'finance',
      title: 'Markets and valuation',
      instructor: '[INSTRUCTOR NAME]',
      updated: DateTime(2026, 5),
      banner: const Color(0xFF33372C),
      trending: true,
      about: 'How markets price companies: DCF, multiples, and reading an annual report.',
      lessons: _lessons([('Why prices move', 840, true)], total: 16, avgSeconds: 960),
    ),
    Course(
      id: 'constitution',
      domainId: 'civil',
      title: 'Indian polity for prelims',
      instructor: '[INSTRUCTOR NAME]',
      updated: DateTime(2026, 8),
      banner: const Color(0xFF2C3540),
      isNew: true,
      about: 'The Constitution article by article, with previous-year prelims questions after every unit.',
      lessons: _lessons([('The Preamble, word by word', 900, true)], total: 22, avgSeconds: 1000),
    ),
    Course(
      id: 'contracts',
      domainId: 'law',
      title: 'Contract law essentials',
      instructor: '[INSTRUCTOR NAME]',
      updated: DateTime(2026, 4),
      banner: const Color(0xFF3A3340),
      about: 'Offer, acceptance, consideration and remedies under the Indian Contract Act, with landmark cases.',
      lessons: _lessons([('What makes a contract', 780, true)], total: 14, avgSeconds: 900),
    ),
    Course(
      id: 'strategy',
      domainId: 'management',
      title: 'Strategy in 20 cases',
      instructor: '[INSTRUCTOR NAME]',
      updated: DateTime(2026, 3),
      banner: const Color(0xFF3C3630),
      about: 'Classic strategy frameworks through twenty Indian and global business cases.',
      lessons: _lessons([('Five forces, one industry', 960, true)], total: 20, avgSeconds: 1100),
    ),
    Course(
      id: 'ux',
      domainId: 'design',
      title: 'UX research on a budget',
      instructor: '[INSTRUCTOR NAME]',
      updated: DateTime(2026, 6),
      banner: const Color(0xFF2E3A33),
      about: 'Interviews, usability tests and surveys you can run this week with no budget.',
      lessons: _lessons([('Asking questions that work', 820, true)], total: 11, avgSeconds: 870),
    ),
  ];

  static Course course(String id) => courses.firstWhere((c) => c.id == id);

  static List<Course> coursesIn(String domainId) => courses.where((c) => c.domainId == domainId).toList();

  static List<Plan> seedPlans() => [
        Plan(id: 'monthly', name: '1 month', days: 30, subtitle: '30 days of full access',
            storeProductId: 'sub_monthly_30'),
        Plan(id: 'quarter', name: '3 months', days: 90, subtitle: '90 days · save [X]%',
            storeProductId: 'sub_quarter_90'),
        Plan(id: 'annual', name: '12 months', days: 365, subtitle: '365 days · best value',
            storeProductId: 'sub_annual_365'),
        Plan(id: 'trial', name: '7-day trial', days: 7, subtitle: '7 days free', storeProductId: 'sub_trial_7',
            price: 0, visible: false),
      ];

  static List<Coupon> seedCoupons() => [
        Coupon(code: 'LAUNCH40', percentOff: 40, used: 318, maxUses: 500, expires: DateTime(2026, 10, 31)),
        Coupon(code: 'COLLEGE199', used: 92, maxUses: 200, expires: DateTime(2026, 12, 15)),
        Coupon(code: 'EARLY100', percentOff: 100, used: 50, maxUses: 50, expires: DateTime(2026, 9, 1)),
      ];

  static List<UploadJob> seedJobs() => [
        UploadJob(lessonTitle: 'Fourier series, term by term', status: JobStatus.uploading, progress: 0.68,
            sizeGb: 2.1),
        UploadJob(lessonTitle: 'The Laplace transform', status: JobStatus.transcoding, sizeGb: 1.8),
        UploadJob(lessonTitle: 'Sampling and aliasing', status: JobStatus.ready, sizeGb: 1.2,
            readyAt: DateTime.now().subtract(const Duration(minutes: 4)),
            length: const Duration(minutes: 16, seconds: 30)),
        UploadJob(lessonTitle: 'Z-transform, part two', status: JobStatus.failed, sizeGb: 1.5,
            error: 'FFmpeg exited with code 1 · audio stream missing'),
      ];

  /// Named lessons first, then numbered placeholders up to [total].
  static List<Lesson> _lessons(List<(String, int, bool)> named,
      {required int total, required int avgSeconds, bool allFree = false}) {
    return List.generate(total, (i) {
      if (i < named.length) {
        final (title, seconds, free) = named[i];
        return Lesson(number: i + 1, title: title, length: Duration(seconds: seconds), free: free || allFree);
      }
      // Deterministic variation so lengths don't all look identical.
      final seconds = avgSeconds + ((i * 97) % 240) - 120;
      return Lesson(number: i + 1, title: 'Lesson ${i + 1}', length: Duration(seconds: seconds), free: allFree);
    });
  }
}
