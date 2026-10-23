import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/profile_workspace_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/supabase_profile_repository.dart';
import '../../data/repositories/supabase_streak_repository.dart';
import '../../data/repositories/supabase_task_repository.dart';
import '../../domain/streak/streak_calculator.dart';
import '../calendar/calendar_page.dart';
import '../streaks/streaks_page.dart';
import '../../theme/app_theme.dart';
import '../../widgets/roast_mascot_card.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({required this.client, super.key});

  final SupabaseClient client;

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  late final SupabaseProfileRepository _profilesRepository;
  late final SupabaseStreakRepository _streakRepository;
  late final SupabaseTaskRepository _tasksRepository;

  List<ProfileWorkspaceModel> _workspaces = const [];
  List<TaskModel> _tasks = const [];
  List<TaskModel> _overdueTasks = const [];
  String? _activeWorkspaceId;
  bool _hasSelectedWorkspace = false;
  bool _isLoading = true;
  Object? _loadError;
  MascotMood _mood = MascotMood.neutral;

  @override
  void initState() {
    super.initState();
    _profilesRepository = SupabaseProfileRepository(widget.client);
    _streakRepository = SupabaseStreakRepository(widget.client);
    _tasksRepository = SupabaseTaskRepository(widget.client);
    _load();
  }

  DateTime get _todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _load({bool showLoading = true, MascotMood? actionMood}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      await _streakRepository.refreshMonthlyWildcards(DateTime.now());
      final workspaces = await _profilesRepository.getAll();
      var workspaceId = _activeWorkspaceId;
      if (!_hasSelectedWorkspace && workspaces.isNotEmpty) {
        workspaceId = workspaces.first.id;
      } else if (workspaceId != null &&
          !workspaces.any((item) => item.id == workspaceId)) {
        workspaceId = workspaces.isEmpty ? null : workspaces.first.id;
      }

      final start = _todayStart;
      final results = await Future.wait<Object>([
        _tasksRepository.getForDateRange(
          profileId: workspaceId,
          start: start,
          end: start.add(const Duration(days: 1)),
        ),
        _tasksRepository.getOverdue(profileId: workspaceId, before: start),
      ]);
      final tasks = results[0] as List<TaskModel>;
      final overdueTasks = results[1] as List<TaskModel>;
      final allTasks = [...overdueTasks, ...tasks];

      if (!mounted) return;
      final derivedMood = _deriveMood(
        allTasks,
        workspaces: workspaces,
        workspaceId: workspaceId,
      );
      final resolvedMood =
          actionMood != null &&
              derivedMood != MascotMood.angry &&
              derivedMood != MascotMood.judging
          ? actionMood
          : derivedMood;
      setState(() {
        _workspaces = workspaces;
        _activeWorkspaceId = workspaceId;
        _hasSelectedWorkspace = true;
        _tasks = tasks;
        _overdueTasks = overdueTasks;
        _isLoading = false;
        _loadError = null;
        _mood = resolvedMood;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  MascotMood _deriveMood(
    List<TaskModel> tasks, {
    required List<ProfileWorkspaceModel> workspaces,
    required String? workspaceId,
  }) {
    final now = DateTime.now();
    final visibleWorkspaces = workspaceId == null
        ? workspaces
        : workspaces.where((workspace) => workspace.id == workspaceId);
    if (visibleWorkspaces.any(
      (workspace) =>
          workspace.currentStreak > 0 &&
          StreakCalculator.effectiveCurrentStreak(workspace, now) == 0,
    )) {
      return MascotMood.angry;
    }
    if (tasks.any((task) => !task.isCompleted && task.dueDate.isBefore(now))) {
      return MascotMood.angry;
    }
    if (tasks.any((task) => !task.isCompleted && task.postponeCount > 2)) {
      return MascotMood.judging;
    }
    if (tasks.isNotEmpty && tasks.every((task) => task.isCompleted)) {
      return MascotMood.proud;
    }
    if (now.hour >= 15 && tasks.every((task) => !task.isCompleted)) {
      return MascotMood.judging;
    }
    return MascotMood.neutral;
  }

  Future<void> _selectWorkspace(String? workspaceId) async {
    setState(() {
      _activeWorkspaceId = workspaceId;
      _hasSelectedWorkspace = true;
    });
    await _load();
  }

  Future<void> _createWorkspace({String initialName = ''}) async {
    final controller = TextEditingController();
    controller.text = initialName;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo espacio'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre del espacio'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;

    try {
      final workspace = await _profilesRepository.create(name: name);
      _activeWorkspaceId = workspace.id;
      _hasSelectedWorkspace = true;
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _createTask() async {
    if (_workspaces.isEmpty) {
      await _createWorkspace();
      return;
    }

    final draft = await showDialog<_TaskDraft>(
      context: context,
      builder: (context) => _CreateTaskDialog(
        workspaces: _workspaces,
        initialWorkspaceId: _activeWorkspaceId ?? _workspaces.first.id,
      ),
    );
    if (draft == null) return;

    try {
      await _tasksRepository.create(
        profileId: draft.workspaceId,
        title: draft.title,
        description: draft.description,
        dueDate: draft.dueDate,
      );
      await _load(showLoading: false);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _setTaskCompleted(TaskModel task, bool value) async {
    try {
      await _tasksRepository.setCompleted(taskId: task.id, isCompleted: value);
      final allTasks = [..._overdueTasks, ..._tasks];
      var actionMood = _deriveMood(
        allTasks,
        workspaces: _workspaces,
        workspaceId: _activeWorkspaceId,
      );
      if (value) {
        final remainingIncomplete = allTasks.any(
          (item) => item.id != task.id && !item.isCompleted,
        );
        final lateOrClose =
            task.dueDate.isBefore(DateTime.now()) ||
            task.dueDate.difference(DateTime.now()) <= const Duration(hours: 1);
        actionMood = lateOrClose
            ? MascotMood.smirking
            : remainingIncomplete
            ? MascotMood.neutral
            : MascotMood.proud;
      }
      await _load(showLoading: false, actionMood: actionMood);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _postponeTask(TaskModel task) async {
    try {
      await _tasksRepository.postpone(taskId: task.id);
      await _load(showLoading: false, actionMood: MascotMood.judging);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteTask(TaskModel task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Borramos “${task.title}”? No hay comodín para esto.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await _tasksRepository.delete(task.id);
      await _load(showLoading: false);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.client.auth.signOut();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openCalendar() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalendarPage(
          client: widget.client,
          initialWorkspaceId: _activeWorkspaceId,
        ),
      ),
    );
    if (mounted) await _load(showLoading: false);
  }

  Future<void> _openStreaks() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StreaksPage(client: widget.client),
      ),
    );
    if (mounted) await _load(showLoading: false);
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
  }

  String _friendlyError(Object error) {
    if (error is AuthException) return error.message;
    if (error is PostgrestException) return error.message;
    if (error is StateError) return error.message.toString();
    return 'No se pudo completar la operación. Inténtalo de nuevo.';
  }

  int get _xpTotal {
    if (_activeWorkspaceId != null) {
      return _workspaces
          .where((workspace) => workspace.id == _activeWorkspaceId)
          .fold(0, (total, workspace) => total + workspace.xpTotal);
    }
    return _workspaces.fold(0, (total, workspace) => total + workspace.xpTotal);
  }

  int get _wildcardsAvailable {
    if (_activeWorkspaceId != null) {
      return _workspaces
          .where((workspace) => workspace.id == _activeWorkspaceId)
          .fold(0, (total, workspace) => total + workspace.wildcardsAvailable);
    }
    return _workspaces.fold(
      0,
      (total, workspace) => total + workspace.wildcardsAvailable,
    );
  }

  int get _currentStreak {
    if (_activeWorkspaceId != null) {
      for (final workspace in _workspaces) {
        if (workspace.id == _activeWorkspaceId) {
          return StreakCalculator.effectiveCurrentStreak(
            workspace,
            DateTime.now(),
          );
        }
      }
      return 0;
    }
    return _workspaces.fold<int>(0, (maximum, workspace) {
      final streak = StreakCalculator.effectiveCurrentStreak(
        workspace,
        DateTime.now(),
      );
      return streak > maximum ? streak : maximum;
    });
  }

  String get _rank {
    if (_xpTotal >= 3000) return 'Amenaza para el calendario';
    if (_xpTotal >= 1000) return 'Procrastinador certificado';
    if (_xpTotal >= 500) return 'Flojo promedio';
    return 'Parásito en prácticas';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.client.auth.currentUser;
    final compactAppBar = MediaQuery.sizeOf(context).width < 520;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jota Parasite'),
        actions: compactAppBar
            ? [
                PopupMenuButton<_DashboardAction>(
                  tooltip: 'Acciones',
                  onSelected: (action) {
                    switch (action) {
                      case _DashboardAction.calendar:
                        _openCalendar();
                        break;
                      case _DashboardAction.streaks:
                        _openStreaks();
                        break;
                      case _DashboardAction.signOut:
                        _signOut();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _DashboardAction.calendar,
                      child: _DashboardMenuLabel(
                        icon: Icons.calendar_month_rounded,
                        label: 'Calendario',
                      ),
                    ),
                    PopupMenuItem(
                      value: _DashboardAction.streaks,
                      child: _DashboardMenuLabel(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Rachas y comodines',
                      ),
                    ),
                    PopupMenuItem(
                      value: _DashboardAction.signOut,
                      child: _DashboardMenuLabel(
                        icon: Icons.logout_rounded,
                        label: 'Cerrar sesión',
                      ),
                    ),
                  ],
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Calendario',
                  onPressed: _openCalendar,
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
                IconButton(
                  tooltip: 'Rachas y comodines',
                  onPressed: _openStreaks,
                  icon: const Icon(Icons.local_fire_department_rounded),
                ),
                if (user?.email != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: Tooltip(
                        message: user!.email!,
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: AppColors.action,
                          child: Text(
                            user.email!.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
      ),
      floatingActionButton: _workspaces.isEmpty || _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _createTask,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva tarea'),
            ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? _ErrorState(onRetry: () => _load())
            : RefreshIndicator(
                onRefresh: () => _load(showLoading: false),
                child: _workspaces.isEmpty
                    ? _EmptyWorkspaceState(
                        onCreate: () =>
                            _createWorkspace(initialName: 'General'),
                      )
                    : _dashboardContent(),
              ),
      ),
    );
  }

  Widget _dashboardContent() {
    final level = (_xpTotal ~/ 500) + 1;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
      children: [
        Text(
          'LVL $level  ·  Rango: $_rank',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.lime,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tu agenda, bajo vigilancia.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        _WorkspaceSelector(
          workspaces: _workspaces,
          selectedWorkspaceId: _activeWorkspaceId,
          onSelected: _selectWorkspace,
          onCreate: _createWorkspace,
        ),
        const SizedBox(height: 18),
        RoastMascotCard(mood: _mood, miracleNumber: (_xpTotal ~/ 100) + 1),
        const SizedBox(height: 18),
        _EffortSummary(
          xpTotal: _xpTotal,
          wildcards: _wildcardsAvailable,
          streak: _currentStreak,
          level: level,
        ),
        const SizedBox(height: 24),
        if (_overdueTasks.isNotEmpty) ...[
          Text(
            'Pendientes vencidas',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.alert),
          ),
          const SizedBox(height: 12),
          ..._overdueTasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TaskTile(
                task: task,
                onCompletedChanged: (value) => _setTaskCompleted(task, value),
                onPostpone: () => _postponeTask(task),
                onDelete: () => _deleteTask(task),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'Tareas de hoy',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '${_tasks.where((task) => task.isCompleted).length}/${_tasks.length}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tasks.isEmpty)
          const _EmptyTasksState()
        else
          ..._tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TaskTile(
                task: task,
                onCompletedChanged: (value) => _setTaskCompleted(task, value),
                onPostpone: () => _postponeTask(task),
                onDelete: () => _deleteTask(task),
              ),
            ),
          ),
      ],
    );
  }
}

enum _DashboardAction { calendar, streaks, signOut }

class _DashboardMenuLabel extends StatelessWidget {
  const _DashboardMenuLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon), const SizedBox(width: 12), Text(label)]);
  }
}

class _WorkspaceSelector extends StatelessWidget {
  const _WorkspaceSelector({
    required this.workspaces,
    required this.selectedWorkspaceId,
    required this.onSelected,
    required this.onCreate,
  });

  final List<ProfileWorkspaceModel> workspaces;
  final String? selectedWorkspaceId;
  final ValueChanged<String?> onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todos'),
              selected: selectedWorkspaceId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...workspaces.map(
            (workspace) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(workspace.name),
                selected: selectedWorkspaceId == workspace.id,
                onSelected: (_) => onSelected(workspace.id),
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Crear espacio',
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _EffortSummary extends StatelessWidget {
  const _EffortSummary({
    required this.xpTotal,
    required this.wildcards,
    required this.streak,
    required this.level,
  });

  final int xpTotal;
  final int wildcards;
  final int streak;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.surfaceCardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BOTÍN POR ESFUERZO MÍNIMO',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textOnSurface,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: Icons.bolt_rounded,
                  value: '$xpTotal XP',
                  caption: '+100 XP por tarea · Nivel $level',
                  accent: AppColors.action,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  icon: Icons.shield_outlined,
                  value: '$wildcards',
                  caption: 'Escudos anti-vergüenza',
                  accent: AppColors.action,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  icon: Icons.local_fire_department_rounded,
                  value: '$streak días',
                  caption: 'Racha activa',
                  accent: AppColors.limeStrong,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.caption,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 19),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textOnSurface),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          caption,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textOnSurface.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onCompletedChanged,
    required this.onPostpone,
    required this.onDelete,
  });

  final TaskModel task;
  final ValueChanged<bool> onCompletedChanged;
  final VoidCallback onPostpone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dueTime = TimeOfDay.fromDateTime(task.dueDate).format(context);
    return Container(
      decoration: AppTheme.surfaceCardDecoration,
      child: Row(
        children: [
          Checkbox(
            value: task.isCompleted,
            onChanged: (value) {
              if (value != null) onCompletedChanged(value);
            },
            activeColor: AppColors.action,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textOnSurface,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${task.isCompleted ? 'Completada' : 'Vence'} · $dueTime'
                    '${task.postponeCount > 0 ? ' · Aplazada ${task.postponeCount}×' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textOnSurface.withValues(alpha: 0.68),
                    ),
                  ),
                  if (task.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textOnSurface.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!task.isCompleted)
            IconButton(
              tooltip: 'Postergar un día',
              onPressed: onPostpone,
              icon: const Icon(Icons.snooze_rounded, color: AppColors.action),
            ),
          IconButton(
            tooltip: 'Eliminar tarea',
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: AppColors.textOnSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _EmptyWorkspaceState extends StatelessWidget {
  const _EmptyWorkspaceState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.workspaces_outline, size: 52, color: AppColors.lime),
        const SizedBox(height: 16),
        Text(
          'Sin espacios de trabajo',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Tu cuenta está vacía. Crea un espacio y deja de procrastinar en abstracto.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear espacio General'),
          ),
        ),
      ],
    );
  }
}

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.heroStart,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          const Icon(Icons.task_alt_rounded, color: AppColors.lime, size: 30),
          const SizedBox(height: 8),
          Text(
            'Ni una tarea para hoy. Sospechoso.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Usa “Nueva tarea” antes de que el día se te escape.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: AppColors.alert,
            ),
            const SizedBox(height: 12),
            Text(
              'Supabase no respondió.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tu productividad tendrá que esperar a que vuelva la conexión.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskDraft {
  const _TaskDraft({
    required this.workspaceId,
    required this.title,
    required this.description,
    required this.dueDate,
  });

  final String workspaceId;
  final String title;
  final String? description;
  final DateTime dueDate;
}

class _CreateTaskDialog extends StatefulWidget {
  const _CreateTaskDialog({
    required this.workspaces,
    required this.initialWorkspaceId,
  });

  final List<ProfileWorkspaceModel> workspaces;
  final String initialWorkspaceId;

  @override
  State<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<_CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _workspaceId = widget.initialWorkspaceId;
  late DateTime _dueDay = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDay,
      firstDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null) setState(() => _dueDay = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _TaskDraft(
        workspaceId: _workspaceId,
        title: _titleController.text.trim(),
        description: _descriptionController.text,
        dueDate: DateTime(_dueDay.year, _dueDay.month, _dueDay.day, 23, 59),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva tarea'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿Qué vas a hacer?',
                ),
                validator: (value) => value?.trim().isNotEmpty == true
                    ? null
                    : 'Escribe un título.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _workspaceId,
                decoration: const InputDecoration(labelText: 'Espacio'),
                items: widget.workspaces
                    .map(
                      (workspace) => DropdownMenuItem(
                        value: workspace.id,
                        child: Text(workspace.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _workspaceId = value);
                },
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Fecha límite'),
                subtitle: Text(
                  '${_dueDay.day}/${_dueDay.month}/${_dueDay.year} · 23:59',
                ),
                onTap: _chooseDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
