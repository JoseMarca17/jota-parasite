import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/profile_workspace_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/supabase_profile_repository.dart';
import '../../data/repositories/supabase_task_repository.dart';
import '../../domain/calendar/calendar_date_utils.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation_bar.dart';
import '../streaks/streaks_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    required this.client,
    this.initialWorkspaceId,
    super.key,
  });

  final SupabaseClient client;
  final String? initialWorkspaceId;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const _allWorkspaces = '__all_workspaces__';

  late final SupabaseProfileRepository _profilesRepository;
  late final SupabaseTaskRepository _tasksRepository;
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  String? _selectedWorkspaceId;
  List<ProfileWorkspaceModel> _workspaces = const [];
  List<TaskModel> _monthTasks = const [];
  bool _isLoading = true;
  Object? _loadError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _visibleMonth = CalendarDateUtils.monthStart(today);
    _selectedDate = CalendarDateUtils.dateOnly(today);
    _selectedWorkspaceId = widget.initialWorkspaceId;
    _profilesRepository = SupabaseProfileRepository(widget.client);
    _tasksRepository = SupabaseTaskRepository(widget.client);
    _load();
  }

  DateTime get _monthEnd =>
      DateTime(_visibleMonth.year, _visibleMonth.month + 1);

  List<TaskModel> get _selectedDayTasks {
    return _monthTasks
        .where((task) {
          final localDueDate = CalendarDateUtils.dateOnly(
            task.dueDate.toLocal(),
          );
          return localDueDate == _selectedDate;
        })
        .toList(growable: false);
  }

  Map<DateTime, int> get _taskCountsByDay {
    final counts = <DateTime, int>{};
    for (final task in _monthTasks) {
      final day = CalendarDateUtils.dateOnly(task.dueDate.toLocal());
      counts.update(day, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final workspaces = await _profilesRepository.getAll();
      var workspaceId = _selectedWorkspaceId;
      if (workspaceId != null &&
          !workspaces.any((workspace) => workspace.id == workspaceId)) {
        workspaceId = null;
      }
      final tasks = await _tasksRepository.getForDateRange(
        profileId: workspaceId,
        start: _visibleMonth,
        end: _monthEnd,
      );

      if (!mounted) return;
      setState(() {
        _workspaces = workspaces;
        _selectedWorkspaceId = workspaceId;
        _monthTasks = tasks;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _showMonth(DateTime month) async {
    final normalizedMonth = CalendarDateUtils.monthStart(month);
    final day = _selectedDate.day;
    final lastDay = DateTime(
      normalizedMonth.year,
      normalizedMonth.month + 1,
      0,
    ).day;
    setState(() {
      _visibleMonth = normalizedMonth;
      _selectedDate = DateTime(
        normalizedMonth.year,
        normalizedMonth.month,
        day > lastDay ? lastDay : day,
      );
    });
    await _load();
  }

  Future<void> _selectWorkspace(String? workspaceId) async {
    setState(() => _selectedWorkspaceId = workspaceId);
    await _load();
  }

  Future<void> _selectDate(DateTime date) async {
    final normalized = CalendarDateUtils.dateOnly(date);
    if (normalized.month != _visibleMonth.month ||
        normalized.year != _visibleMonth.year) {
      setState(() {
        _selectedDate = normalized;
        _visibleMonth = CalendarDateUtils.monthStart(normalized);
      });
      await _load();
      return;
    }
    setState(() => _selectedDate = normalized);
  }

  Future<void> _createTask() async {
    if (_workspaces.isEmpty) {
      _showMessage('Primero crea un espacio de trabajo desde el Dashboard.');
      return;
    }

    final draft = await showDialog<_CalendarTaskDraft>(
      context: context,
      builder: (_) => _CreateCalendarTaskDialog(
        workspaces: _workspaces,
        initialWorkspaceId: _selectedWorkspaceId ?? _workspaces.first.id,
        selectedDate: _selectedDate,
      ),
    );
    if (draft == null) return;

    setState(() => _isSaving = true);
    try {
      await _tasksRepository.create(
        profileId: draft.workspaceId,
        title: draft.title,
        description: draft.description,
        dueDate: draft.dueDate,
      );
      await _load(showLoading: false);
      _showMessage('Tarea añadida. La agenda ya tiene algo que vigilar.');
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _setCompleted(TaskModel task, bool isCompleted) async {
    try {
      await _tasksRepository.setCompleted(
        taskId: task.id,
        isCompleted: isCompleted,
      );
      await _load(showLoading: false);
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  void _onDestinationSelected(AppDestination destination) {
    switch (destination) {
      case AppDestination.home:
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case AppDestination.calendar:
        break;
      case AppDestination.streaks:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => StreaksPage(client: widget.client),
          ),
          (route) => route.isFirst,
        );
        break;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) {
    if (error is AuthException) return error.message;
    if (error is PostgrestException) return error.message;
    if (error is StateError) return error.message.toString();
    return 'No se pudo completar la operación. Inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          IconButton(
            tooltip: 'Ir a hoy',
            onPressed: () => _selectDate(DateTime.now()),
            icon: const Icon(Icons.today_rounded),
          ),
          IconButton(
            tooltip: 'Actualizar calendario',
            onPressed: _isLoading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _workspaces.isEmpty || _isLoading || _isSaving
          ? null
          : FloatingActionButton.extended(
              onPressed: _createTask,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text('Nueva tarea'),
            ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? _CalendarErrorState(onRetry: () => _load())
            : RefreshIndicator(
                onRefresh: () => _load(showLoading: false),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    if (_workspaces.isNotEmpty) ...[
                      _WorkspaceFilter(
                        workspaces: _workspaces,
                        selectedWorkspaceId: _selectedWorkspaceId,
                        allWorkspacesValue: _allWorkspaces,
                        onChanged: (value) => _selectWorkspace(
                          value == _allWorkspaces ? null : value,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _MonthCalendar(
                      month: _visibleMonth,
                      selectedDate: _selectedDate,
                      today: DateTime.now(),
                      taskCounts: _taskCountsByDay,
                      onDateSelected: _selectDate,
                      onPreviousMonth: () => _showMonth(
                        CalendarDateUtils.addMonths(_visibleMonth, -1),
                      ),
                      onNextMonth: () => _showMonth(
                        CalendarDateUtils.addMonths(_visibleMonth, 1),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SelectedDayTasks(
                      date: _selectedDate,
                      tasks: _selectedDayTasks,
                      hasWorkspaces: _workspaces.isNotEmpty,
                      onCompletedChanged: _setCompleted,
                      onCreateTask: _createTask,
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedDestination: AppDestination.calendar,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}

class _WorkspaceFilter extends StatelessWidget {
  const _WorkspaceFilter({
    required this.workspaces,
    required this.selectedWorkspaceId,
    required this.allWorkspacesValue,
    required this.onChanged,
  });

  final List<ProfileWorkspaceModel> workspaces;
  final String? selectedWorkspaceId;
  final String allWorkspacesValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedWorkspaceId ?? allWorkspacesValue,
      decoration: const InputDecoration(
        labelText: 'Espacio de trabajo',
        prefixIcon: Icon(Icons.workspaces_outline),
      ),
      items: [
        DropdownMenuItem(
          value: allWorkspacesValue,
          child: const Text('Todos los espacios'),
        ),
        ...workspaces.map(
          (workspace) => DropdownMenuItem(
            value: workspace.id,
            child: Text(workspace.name),
          ),
        ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selectedDate,
    required this.today,
    required this.taskCounts,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  static const _weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  final DateTime month;
  final DateTime selectedDate;
  final DateTime today;
  final Map<DateTime, int> taskCounts;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final dates = CalendarDateUtils.monthGrid(month);
    final monthStart = CalendarDateUtils.monthStart(month);
    final normalizedToday = CalendarDateUtils.dateOnly(today);
    final normalizedSelected = CalendarDateUtils.dateOnly(selectedDate);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: AppTheme.surfaceCardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  CalendarDateUtils.monthLabel(month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final weekday in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            itemCount: dates.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) {
              final date = dates[index];
              final day = CalendarDateUtils.dateOnly(date);
              final isCurrentMonth =
                  date.month == monthStart.month &&
                  date.year == monthStart.year;
              final isSelected = day == normalizedSelected;
              final isToday = day == normalizedToday;
              final count = taskCounts[day] ?? 0;

              return _CalendarDayCell(
                date: date,
                isCurrentMonth: isCurrentMonth,
                isSelected: isSelected,
                isToday: isToday,
                taskCount: count,
                onTap: () => onDateSelected(date),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.actionLight,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'Días con tareas',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isSelected,
    required this.isToday,
    required this.taskCount,
    required this.onTap,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isSelected;
  final bool isToday;
  final int taskCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isSelected
        ? AppColors.textOnSurface
        : isCurrentMonth
        ? AppColors.textOnSurface
        : AppColors.textOnSurface.withValues(alpha: 0.46);

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${date.day}/${date.month}/${date.year}'
          '${taskCount > 0 ? ', $taskCount tareas' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('calendar-day-${date.year}-${date.month}-${date.day}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.lime : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isToday && !isSelected
                  ? Border.all(color: AppColors.actionLight, width: 1.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                if (taskCount > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.textOnSurface.withValues(alpha: 0.14)
                          : AppColors.actionLight,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      '$taskCount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.textOnSurface
                            : AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedDayTasks extends StatelessWidget {
  const _SelectedDayTasks({
    required this.date,
    required this.tasks,
    required this.hasWorkspaces,
    required this.onCompletedChanged,
    required this.onCreateTask,
  });

  final DateTime date;
  final List<TaskModel> tasks;
  final bool hasWorkspaces;
  final Future<void> Function(TaskModel task, bool isCompleted)
  onCompletedChanged;
  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    final completedCount = tasks.where((task) => task.isCompleted).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Agenda · ${_dateLabel(date)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (tasks.isNotEmpty)
              Text(
                '$completedCount/${tasks.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          _EmptyCalendarDay(
            hasWorkspaces: hasWorkspaces,
            onCreateTask: onCreateTask,
          )
        else
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CalendarTaskTile(
                task: task,
                onCompletedChanged: (value) => onCompletedChanged(task, value),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarTaskTile extends StatelessWidget {
  const _CalendarTaskTile({
    required this.task,
    required this.onCompletedChanged,
  });

  final TaskModel task;
  final ValueChanged<bool> onCompletedChanged;

  @override
  Widget build(BuildContext context) {
    final dueTime = TimeOfDay.fromDateTime(
      task.dueDate.toLocal(),
    ).format(context);
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
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _EmptyCalendarDay extends StatelessWidget {
  const _EmptyCalendarDay({
    required this.hasWorkspaces,
    required this.onCreateTask,
  });

  final bool hasWorkspaces;
  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.heroStart,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available_rounded, color: AppColors.lime),
          const SizedBox(height: 8),
          Text(
            hasWorkspaces
                ? 'Sin tareas. Qué día tan sospechosamente libre.'
                : 'Crea primero un espacio de trabajo.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (hasWorkspaces) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onCreateTask,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir tarea a este día'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalendarErrorState extends StatelessWidget {
  const _CalendarErrorState({required this.onRetry});

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
              color: AppColors.alert,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el calendario.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
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

class _CalendarTaskDraft {
  const _CalendarTaskDraft({
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

class _CreateCalendarTaskDialog extends StatefulWidget {
  const _CreateCalendarTaskDialog({
    required this.workspaces,
    required this.initialWorkspaceId,
    required this.selectedDate,
  });

  final List<ProfileWorkspaceModel> workspaces;
  final String initialWorkspaceId;
  final DateTime selectedDate;

  @override
  State<_CreateCalendarTaskDialog> createState() =>
      _CreateCalendarTaskDialogState();
}

class _CreateCalendarTaskDialogState extends State<_CreateCalendarTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _workspaceId = widget.initialWorkspaceId;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final day = widget.selectedDate;
    Navigator.pop(
      context,
      _CalendarTaskDraft(
        workspaceId: _workspaceId,
        title: _titleController.text.trim(),
        description: _descriptionController.text,
        dueDate: DateTime(day.year, day.month, day.day, 23, 59),
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
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Fecha límite'),
                subtitle: Text(_dateLabel(widget.selectedDate)),
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

String _dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';
