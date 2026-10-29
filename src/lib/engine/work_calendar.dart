import '../model/project.dart';

/// Working-day arithmetic: Monday to Friday, minus the project's holidays.
class WorkCalendar {
  WorkCalendar(Iterable<DateTime> holidays) : _holidays = holidays.map(dateOnly).toSet();

  final Set<DateTime> _holidays;

  bool isWorkday(DateTime d) => d.weekday <= DateTime.friday && !_holidays.contains(dateOnly(d));

  /// [d] if it is a working day, else the next one.
  DateTime onOrAfter(DateTime d) {
    var x = dateOnly(d);
    while (!isWorkday(x)) {
      x = x.add(const Duration(days: 1));
    }
    return x;
  }

  /// Like Excel's WORKDAY: [n] working days after [d] (before it when [n] is
  /// negative), not counting [d] itself.
  DateTime addWorkdays(DateTime d, int n) {
    var x = dateOnly(d);
    final step = n >= 0 ? 1 : -1;
    var left = n.abs();
    while (left > 0) {
      x = x.add(Duration(days: step));
      if (isWorkday(x)) left--;
    }
    return x;
  }

  /// Like Excel's NETWORKDAYS: working days from [a] to [b], both included.
  int workdaysBetween(DateTime a, DateTime b) {
    var n = 0;
    for (var x = dateOnly(a); !x.isAfter(dateOnly(b)); x = x.add(const Duration(days: 1))) {
      if (isWorkday(x)) n++;
    }
    return n;
  }
}
