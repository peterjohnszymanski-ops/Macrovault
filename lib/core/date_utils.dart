import 'package:intl/intl.dart';

/// Day/week helpers. A "day key" is a local-date string `yyyy-MM-dd`, used as
/// the grouping key for all day-granular logs so that crossing midnight while
/// logging assigns to the chosen calendar day, not wall-clock UTC.
class Days {
  Days._();

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  static String key(DateTime d) => _fmt.format(DateTime(d.year, d.month, d.day));

  static String today() => key(DateTime.now());

  static DateTime parse(String dayKey) => _fmt.parse(dayKey);

  static String addDays(String dayKey, int days) =>
      key(parse(dayKey).add(Duration(days: days)));

  /// Monday of the ISO week containing [d].
  static DateTime weekStart(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  static String weekStartKey(DateTime d) => key(weekStart(d));

  /// The 7 day-keys (Mon..Sun) for the week starting at [weekStartKey].
  static List<String> weekDays(String weekStartKey) =>
      List.generate(7, (i) => addDays(weekStartKey, i));

  static bool isWeekend(String dayKey) {
    final wd = parse(dayKey).weekday;
    return wd == DateTime.saturday || wd == DateTime.sunday;
  }

  /// Inclusive list of day-keys from [start] to [end].
  static List<String> range(String start, String end) {
    final out = <String>[];
    var cur = parse(start);
    final stop = parse(end);
    while (!cur.isAfter(stop)) {
      out.add(key(cur));
      cur = cur.add(const Duration(days: 1));
    }
    return out;
  }

  static String pretty(String dayKey) =>
      DateFormat('EEE, MMM d').format(parse(dayKey));

  static String prettyMonthDay(String dayKey) =>
      DateFormat('MMM d').format(parse(dayKey));
}
