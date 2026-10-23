import '../models/task_model.dart';

/// Contrato de persistencia de tareas; null en profileId significa todos
/// los workspaces accesibles del usuario autenticado.
abstract interface class TaskRepository {
  Future<List<TaskModel>> getOverdue({
    String? profileId,
    required DateTime before,
  });

  Future<List<TaskModel>> getForDateRange({
    String? profileId,
    required DateTime start,
    required DateTime end,
  });

  Future<TaskModel> create({
    required String profileId,
    required String title,
    required DateTime dueDate,
    String? description,
    bool affectsStreak = true,
  });

  Future<TaskModel> update(TaskModel task);

  Future<TaskModel> setCompleted({
    required String taskId,
    required bool isCompleted,
  });

  /// Aplaza la fecha límite y aumenta postpone_count en una unidad.
  Future<TaskModel> postpone({required String taskId, int days = 1});

  Future<void> delete(String id);
}
