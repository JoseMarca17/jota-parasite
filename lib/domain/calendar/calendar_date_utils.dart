abstract final class CalendarDateUtils {
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

  static DateTime addMonths(DateTime date, int months) {
    final targetMonth = DateTime(date.year, date.month + months);
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(targetMonth.year, targetMonth.month, day);
  }

  static List<DateTime> monthGrid(DateTime month) {
    final firstDay = monthStart(month);
    final gridStart = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    return List<DateTime>.generate(
      42,
      (index) => gridStart.add(Duration(days: index)),
      growable: false,
    );
  }

  static String monthLabel(DateTime month) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${months[month.month - 1]} de ${month.year}';
  }
}
