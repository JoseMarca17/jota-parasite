import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jota_parasite/data/models/profile_workspace_model.dart';
import 'package:jota_parasite/data/models/task_model.dart';
import 'package:jota_parasite/data/repositories/profile_workspace_repository.dart';
import 'package:jota_parasite/data/repositories/task_repository.dart';
import 'package:jota_parasite/features/calendar/calendar_page.dart';
import 'package:jota_parasite/theme/app_theme.dart';

void main() {
  const university = ProfileWorkspaceModel(
    id: 'workspace-university',
    userId: 'user-1',
    name: 'Universidad',
  );
  const home = ProfileWorkspaceModel(
    id: 'workspace-home',
    userId: 'user-1',
    name: 'Casa',
  );
  final october = DateTime(2026, 10, 15);

  testWidgets('selecciona fechas y navega entre meses', (tester) async {
    final tasks = _FakeTaskRepository([
      _task(
        id: 'october-task',
        title: 'Tarea de octubre',
        dueDate: DateTime(2026, 10, 16),
      ),
      _task(
        id: 'november-task',
        title: 'Tarea de noviembre',
        dueDate: DateTime(2026, 11, 16),
      ),
    ]);

    await _pumpCalendar(
      tester,
      workspaces: const [university],
      tasks: tasks,
      initialDate: october,
    );

    expect(find.text('octubre de 2026'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('calendar-day-2026-10-16')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-10-16')));
    await tester.pumpAndSettle();
    await _showSelectedAgenda(tester);
    expect(find.text('Agenda · 16/10/2026'), findsOneWidget);
    expect(find.text('Tarea de octubre'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('noviembre de 2026'), findsOneWidget);
    await _showSelectedAgenda(tester);
    expect(find.text('Agenda · 16/11/2026'), findsOneWidget);
    expect(find.text('Tarea de noviembre'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Mes anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mes anterior'));
    await tester.pumpAndSettle();
    expect(find.text('octubre de 2026'), findsOneWidget);
  });

  testWidgets('el filtro limita las tareas al workspace seleccionado', (
    tester,
  ) async {
    final tasks = _FakeTaskRepository([
      _task(
        id: 'university-task',
        title: 'Tarea universidad',
        dueDate: october,
        profileId: university.id,
      ),
      _task(
        id: 'home-task',
        title: 'Tarea casa',
        dueDate: october,
        profileId: home.id,
      ),
    ]);

    await _pumpCalendar(
      tester,
      workspaces: const [university, home],
      tasks: tasks,
      initialDate: october,
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casa').last);
    await tester.pumpAndSettle();

    expect(tasks.lastProfileFilter, home.id);
    await _showSelectedAgenda(tester);
    expect(find.text('Tarea casa'), findsOneWidget);
    expect(find.text('Tarea universidad'), findsNothing);
  });

  testWidgets('crea una tarea para el día elegido y permite completarla', (
    tester,
  ) async {
    final tasks = _FakeTaskRepository([]);

    await _pumpCalendar(
      tester,
      workspaces: const [university],
      tasks: tasks,
      initialDate: october,
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Preparar entrega',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await _showSelectedAgenda(tester);

    expect(find.text('Preparar entrega'), findsOneWidget);
    expect(tasks.items.single.dueDate, DateTime(2026, 10, 15, 23, 59));

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await _showSelectedAgenda(tester);

    expect(tasks.items.single.isCompleted, isTrue);
    expect(find.textContaining('Completada'), findsOneWidget);
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required List<ProfileWorkspaceModel> workspaces,
  required _FakeTaskRepository tasks,
  required DateTime initialDate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: CalendarPage(
        initialDate: initialDate,
        profileRepository: _FakeProfileRepository(workspaces),
        taskRepository: tasks,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _showSelectedAgenda(WidgetTester tester) async {
  final agenda = find.textContaining('Agenda ·');
  for (var attempt = 0; attempt < 5 && agenda.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

TaskModel _task({
  required String id,
  required String title,
  required DateTime dueDate,
  String profileId = 'workspace-university',
  bool isCompleted = false,
  int postponeCount = 0,
}) {
  return TaskModel(
    id: id,
    userId: 'user-1',
    profileId: profileId,
    title: title,
    dueDate: dueDate,
    createdAt: DateTime(2026, 10, 1),
    isCompleted: isCompleted,
    postponeCount: postponeCount,
  );
}

class _FakeProfileRepository implements ProfileWorkspaceRepository {
  _FakeProfileRepository(this.workspaces);

  final List<ProfileWorkspaceModel> workspaces;

  @override
  Future<List<ProfileWorkspaceModel>> getAll() async => workspaces;

  @override
  Future<ProfileWorkspaceModel?> getById(String id) async {
    for (final workspace in workspaces) {
      if (workspace.id == id) return workspace;
    }
    return null;
  }

  @override
  Future<ProfileWorkspaceModel> create({
    required String name,
    int colorHex = 4285284024,
    String iconName = 'school',
    List<int> frozenDaysMask = const [6, 7],
  }) => throw UnimplementedError();

  @override
  Future<ProfileWorkspaceModel> update(ProfileWorkspaceModel workspace) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository(this.items);

  final List<TaskModel> items;
  String? lastProfileFilter;
  int _nextId = 0;

  @override
  Future<List<TaskModel>> getForDateRange({
    String? profileId,
    required DateTime start,
    required DateTime end,
  }) async {
    lastProfileFilter = profileId;
    return items
        .where(
          (task) =>
              !task.dueDate.isBefore(start) &&
              task.dueDate.isBefore(end) &&
              (profileId == null || task.profileId == profileId),
        )
        .toList(growable: false);
  }

  @override
  Future<List<TaskModel>> getOverdue({
    String? profileId,
    required DateTime before,
  }) async => const [];

  @override
  Future<TaskModel> create({
    required String profileId,
    required String title,
    required DateTime dueDate,
    String? description,
    bool affectsStreak = true,
  }) async {
    final task = _task(
      id: 'created-${_nextId++}',
      title: title,
      dueDate: dueDate,
      profileId: profileId,
    );
    items.add(task);
    return task;
  }

  @override
  Future<TaskModel> setCompleted({
    required String taskId,
    required bool isCompleted,
  }) async {
    final index = items.indexWhere((task) => task.id == taskId);
    if (index < 0) throw StateError('Task not found.');
    final task = items[index];
    final updated = TaskModel(
      id: task.id,
      userId: task.userId,
      profileId: task.profileId,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      createdAt: task.createdAt,
      isCompleted: isCompleted,
      completedAt: isCompleted ? DateTime(2026, 10, 15, 12) : null,
      postponeCount: task.postponeCount,
      affectsStreak: task.affectsStreak,
      xpAwardedAt: task.xpAwardedAt,
    );
    items[index] = updated;
    return updated;
  }

  @override
  Future<TaskModel> update(TaskModel task) async => task;

  @override
  Future<TaskModel> postpone({required String taskId, int days = 1}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((task) => task.id == id);
  }
}
