import 'package:flutter_test/flutter_test.dart';
import 'package:jota_parasite/data/models/profile_workspace_model.dart';
import 'package:jota_parasite/data/models/task_model.dart';

void main() {
  group('ProfileWorkspaceModel', () {
    test('serializa y reconstruye campos de Supabase, incluida XP', () {
      final json = <String, dynamic>{
        'id': 'workspace-1',
        'user_id': 'user-1',
        'name': 'Universidad',
        'color_hex': 4285284024,
        'icon_name': 'school',
        'current_streak': 4,
        'max_streak': 10,
        'last_completed_date': '2026-10-12',
        'wildcards_available': 2,
        'frozen_days_mask': [6, 7],
        'xp_total': 300,
        'wildcards_period_start': '2026-10-01',
      };

      final model = ProfileWorkspaceModel.fromJson(json);

      expect(model.name, 'Universidad');
      expect(model.xpTotal, 300);
      expect(model.frozenDaysMask, [6, 7]);
      expect(model.toJson(), json);
    });
  });

  group('TaskModel', () {
    test('serializa timestamps y el marcador de recompensa única', () {
      final json = <String, dynamic>{
        'id': 'task-1',
        'user_id': 'user-1',
        'profile_id': 'workspace-1',
        'title': 'Entregar el informe',
        'description': null,
        'due_date': '2026-10-12T23:59:00.000Z',
        'is_completed': true,
        'completed_at': '2026-10-12T10:30:00.000Z',
        'postpone_count': 0,
        'affects_streak': true,
        'created_at': '2026-10-10T12:00:00.000Z',
        'xp_awarded_at': '2026-10-12T10:30:00.000Z',
      };

      final model = TaskModel.fromJson(json);

      expect(model.title, 'Entregar el informe');
      expect(model.isCompleted, isTrue);
      expect(
        model.xpAwardedAt,
        DateTime.parse(json['xp_awarded_at'] as String),
      );
      expect(model.toJson(), json);
    });
  });
}
