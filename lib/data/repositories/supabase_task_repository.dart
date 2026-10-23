import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_model.dart';
import 'task_repository.dart';

class SupabaseTaskRepository implements TaskRepository {
  SupabaseTaskRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'tasks';

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError(
        'Se necesita una sesión activa para acceder a las tareas.',
      );
    }
    return user.id;
  }

  @override
  Future<List<TaskModel>> getOverdue({
    String? profileId,
    required DateTime before,
  }) async {
    var query = _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .eq('is_completed', false)
        .lt('due_date', before.toUtc().toIso8601String());

    if (profileId != null) query = query.eq('profile_id', profileId);

    final rows = await query.order('due_date');
    return rows
        .map((row) => TaskModel.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<List<TaskModel>> getForDateRange({
    String? profileId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!end.isAfter(start)) {
      throw ArgumentError('El final del rango debe ser posterior al inicio.');
    }

    var query = _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .gte('due_date', start.toUtc().toIso8601String())
        .lt('due_date', end.toUtc().toIso8601String());

    if (profileId != null) query = query.eq('profile_id', profileId);

    final rows = await query.order('due_date');
    return rows
        .map((row) => TaskModel.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<TaskModel> create({
    required String profileId,
    required String title,
    required DateTime dueDate,
    String? description,
    bool affectsStreak = true,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'El título no puede estar vacío.',
      );
    }

    final row = await _client
        .from(_table)
        .insert({
          'user_id': _userId,
          'profile_id': profileId,
          'title': normalizedTitle,
          'description': _normalizeDescription(description),
          'due_date': dueDate.toUtc().toIso8601String(),
          'affects_streak': affectsStreak,
        })
        .select()
        .single();

    return TaskModel.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<TaskModel> update(TaskModel task) async {
    final userId = _userId;
    if (task.userId != userId) {
      throw StateError('No se puede modificar una tarea de otro usuario.');
    }

    final row = await _client
        .from(_table)
        .update({
          'title': task.title.trim(),
          'description': _normalizeDescription(task.description),
          'due_date': task.dueDate.toUtc().toIso8601String(),
          'affects_streak': task.affectsStreak,
        })
        .eq('id', task.id)
        .eq('user_id', userId)
        .select()
        .single();

    return TaskModel.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<TaskModel> setCompleted({
    required String taskId,
    required bool isCompleted,
  }) async {
    final row = await _client
        .rpc(
          'set_task_completion',
          params: {
            'p_task_id': taskId,
            'p_is_completed': isCompleted,
            'p_local_date': _localDateString(DateTime.now()),
          },
        )
        .single();

    return TaskModel.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<TaskModel> postpone({required String taskId, int days = 1}) async {
    if (days < 1 || days > 365) {
      throw ArgumentError.value(days, 'days', 'Debe estar entre 1 y 365.');
    }

    final row = await _client
        .rpc('postpone_task', params: {'p_task_id': taskId, 'p_days': days})
        .single();

    return TaskModel.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id).eq('user_id', _userId);
  }
}

String? _normalizeDescription(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _localDateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
