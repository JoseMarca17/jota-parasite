import 'package:flutter_test/flutter_test.dart';
import 'package:jota_parasite/data/models/profile_workspace_model.dart';
import 'package:jota_parasite/domain/streak/streak_calculator.dart';

void main() {
  final friday = DateTime(2026, 10, 9);

  ProfileWorkspaceModel workspace({
    int current = 24,
    int wildcards = 3,
    List<int> frozenDays = const [6, 7],
    DateTime? lastCompleted,
  }) {
    return ProfileWorkspaceModel(
      id: 'workspace-1',
      userId: 'user-1',
      name: 'Universidad',
      currentStreak: current,
      lastCompletedDate: lastCompleted ?? friday,
      wildcardsAvailable: wildcards,
      frozenDaysMask: frozenDays,
    );
  }

  test('los días congelados no rompen la racha al pasar el fin de semana', () {
    expect(
      StreakCalculator.effectiveCurrentStreak(
        workspace(),
        DateTime(2026, 10, 12), // lunes
      ),
      24,
    );
  });

  test(
    'una jornada abierta perdida deja la racha en cero al día siguiente',
    () {
      expect(
        StreakCalculator.effectiveCurrentStreak(
          workspace(),
          DateTime(2026, 10, 13), // martes: el lunes quedó atrás sin actividad
        ),
        0,
      );
    },
  );

  test('un comodín cubre exactamente el último día abierto perdido', () {
    expect(
      StreakCalculator.wildcardTarget(workspace(), DateTime(2026, 10, 13)),
      DateTime(2026, 10, 12),
    );
  });

  test('un comodín no cubre dos días abiertos perdidos', () {
    expect(
      StreakCalculator.wildcardTarget(
        workspace(frozenDays: const []),
        DateTime(2026, 10, 12), // lunes: sábado y domingo también cuentan
      ),
      isNull,
    );
  });

  test('un día congelado actual no consume un comodín', () {
    expect(
      StreakCalculator.wildcardTarget(workspace(), DateTime(2026, 10, 10)),
      isNull,
    );
  });
}
