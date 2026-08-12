/// The whole business operates in Qatar only (UTC+3, no daylight saving).
/// We must never rely on the device's own system timezone for "today" or
/// time comparisons — a dispatcher's PC or a driver's phone could be set to
/// any timezone, which would silently break dates and punctuality.
class QatarTime {
  static const _offsetHours = 3;

  /// "Now," but always in Qatar time, regardless of device timezone.
  static DateTime now() => DateTime.now().toUtc().add(const Duration(hours: _offsetHours));
  /// Use this whenever SAVING a "now" timestamp to Supabase — guarantees
  /// it's tagged as true UTC, so the database interprets it correctly
  /// regardless of what timezone the device's own clock is set to.
  static String nowUtcIso() => DateTime.now().toUtc().toIso8601String();
  
  /// Converts a stored UTC timestamp (ISO string) to Qatar time.
  static DateTime fromIso(String iso) => DateTime.parse(iso).toUtc().add(const Duration(hours: _offsetHours));

  static String todayStr() {
    final n = now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
  /// Delivery window times are stored as "08:00:00" — this trims the
  /// seconds for display, since minute-level precision is all that matters.
  static String trimSeconds(String? raw) {
    if (raw == null) return '';
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }
  static String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';
}