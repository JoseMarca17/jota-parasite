import '../../data/models/profile_workspace_model.dart';

abstract final class StreakCalculator {
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime mondayOf(DateTime date) {
    final day = dateOnly(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// Expira el contador solo después de que termine un día laborable perdido.
  /// Los días congelados se omiten y el día actual sigue abierto.
  static int effectiveCurrentStreak(
    ProfileWorkspaceModel workspace,
    DateTime today,
  ) {
    final last = workspace.lastCompletedDate;
    if (workspace.currentStreak <= 0 || last == null) return 0;

    final normalizedLast = dateOnly(last);
    final normalizedToday = dateOnly(today);
    if (normalizedLast.isAfter(normalizedToday)) return 0;

    var cursor = normalizedLast.add(const Duration(days: 1));
    while (cursor.isBefore(normalizedToday)) {
      if (!workspace.frozenDaysMask.contains(cursor.weekday)) return 0;
      cursor = cursor.add(const Duration(days: 1));
    }
    return workspace.currentStreak;
  }

  /// Devuelve el único día abierto que puede cubrir un comodín ahora.
  /// Si se perdieron varios días laborables, un solo comodín no basta.
  static DateTime? wildcardTarget(
    ProfileWorkspaceModel workspace,
    DateTime today,
  ) {
    final last = workspace.lastCompletedDate;
    if (workspace.currentStreak <= 0 ||
        workspace.wildcardsAvailable <= 0 ||
        last == null) {
      return null;
    }

    final normalizedLast = dateOnly(last);
    final normalizedToday = dateOnly(today);
    if (!normalizedLast.isBefore(normalizedToday)) return null;

    final missedOpenDays = <DateTime>[];
    var cursor = normalizedLast.add(const Duration(days: 1));
    while (cursor.isBefore(normalizedToday)) {
      if (!workspace.frozenDaysMask.contains(cursor.weekday)) {
        missedOpenDays.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    if (missedOpenDays.length == 1) return missedOpenDays.single;
    if (missedOpenDays.isNotEmpty ||
        workspace.frozenDaysMask.contains(normalizedToday.weekday)) {
      return null;
    }
    return normalizedToday;
  }
}
