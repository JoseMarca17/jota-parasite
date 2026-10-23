import 'package:flutter_test/flutter_test.dart';
import 'package:jota_parasite/domain/calendar/calendar_date_utils.dart';

void main() {
  group('CalendarDateUtils', () {
    test('genera una cuadrícula de 6 semanas empezando en lunes', () {
      final days = CalendarDateUtils.monthGrid(DateTime(2026, 10, 15));

      expect(days, hasLength(42));
      expect(days.first, DateTime(2026, 9, 28));
      expect(days.first.weekday, DateTime.monday);
      expect(days.last.weekday, DateTime.sunday);
      expect(days.last, DateTime(2026, 11, 8));
    });

    test('navegar al mes siguiente ajusta los días que no existen', () {
      expect(
        CalendarDateUtils.addMonths(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 28),
      );
      expect(
        CalendarDateUtils.addMonths(DateTime(2028, 1, 31), 1),
        DateTime(2028, 2, 29),
      );
    });

    test('formatea el mes en español', () {
      expect(
        CalendarDateUtils.monthLabel(DateTime(2026, 10, 1)),
        'octubre de 2026',
      );
    });
  });
}
