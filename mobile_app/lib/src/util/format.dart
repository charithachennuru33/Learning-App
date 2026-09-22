/// Display helpers shared by the screens.
abstract final class Fmt {
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// 11:20 or 1:05:30.
  static String clock(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// 6h 10m, or 45m.
  static String length(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  /// 0:24 for countdowns.
  static String countdown(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  /// ₹2,499 with Indian digit grouping, or ₹[PRICE] while prices are unset.
  static String price(int? rupees) {
    if (rupees == null) return '₹[PRICE]';
    final s = rupees.toString();
    if (s.length <= 3) return '₹$s';
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '₹${parts.join(',')},$last3';
  }

  /// 14 Jun 2027.
  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// Aug 2026.
  static String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  /// +91 98765 43210 for Indian numbers, otherwise unchanged.
  static String phone(String? e164) {
    if (e164 == null) return '';
    if (e164.startsWith('+91') && e164.length == 13) {
      return '+91 ${e164.substring(3, 8)} ${e164.substring(8)}';
    }
    return e164;
  }

  /// "Ravi Kumar" -> "RK".
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  static String twoDigits(int n) => n.toString().padLeft(2, '0');
}
