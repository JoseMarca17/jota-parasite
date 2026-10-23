import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/profile_workspace_model.dart';
import '../../data/models/streak_day_model.dart';
import '../../data/repositories/supabase_profile_repository.dart';
import '../../data/repositories/supabase_streak_repository.dart';
import '../../domain/streak/streak_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation_bar.dart';
import '../calendar/calendar_page.dart';

class StreaksPage extends StatefulWidget {
  const StreaksPage({required this.client, super.key});

  final SupabaseClient client;

  @override
  State<StreaksPage> createState() => _StreaksPageState();
}

class _StreaksPageState extends State<StreaksPage> {
  late final SupabaseProfileRepository _profilesRepository;
  late final SupabaseStreakRepository _streakRepository;

  List<ProfileWorkspaceModel> _workspaces = const [];
  List<StreakDayModel> _week = const [];
  String? _selectedWorkspaceId;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _profilesRepository = SupabaseProfileRepository(widget.client);
    _streakRepository = SupabaseStreakRepository(widget.client);
    _load();
  }

  ProfileWorkspaceModel? get _selectedWorkspace {
    for (final workspace in _workspaces) {
      if (workspace.id == _selectedWorkspaceId) return workspace;
    }
    return null;
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final today = DateTime.now();
      await _streakRepository.refreshMonthlyWildcards(today);
      final workspaces = await _profilesRepository.getAll();
      var selectedId = _selectedWorkspaceId;
      if (selectedId == null ||
          !workspaces.any((item) => item.id == selectedId)) {
        selectedId = workspaces.isEmpty ? null : workspaces.first.id;
      }

      var week = <StreakDayModel>[];
      if (selectedId != null) {
        final weekStart = StreakCalculator.mondayOf(today);
        week = await _streakRepository.getWeek(
          profileId: selectedId,
          weekStart: weekStart,
          weekEnd: weekStart.add(const Duration(days: 6)),
        );
      }

      if (!mounted) return;
      setState(() {
        _workspaces = workspaces;
        _selectedWorkspaceId = selectedId;
        _week = week;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _selectWorkspace(String workspaceId) async {
    setState(() => _selectedWorkspaceId = workspaceId);
    await _load();
  }

  Future<void> _toggleWeekendFreeze(bool enabled) async {
    final workspace = _selectedWorkspace;
    if (workspace == null) return;

    final frozenDays = workspace.frozenDaysMask.toSet();
    if (enabled) {
      frozenDays.addAll([DateTime.saturday, DateTime.sunday]);
    } else {
      frozenDays.remove(DateTime.saturday);
      frozenDays.remove(DateTime.sunday);
    }

    setState(() => _saving = true);
    try {
      await _profilesRepository.update(
        workspace.copyWith(frozenDaysMask: frozenDays.toList()..sort()),
      );
      await _load(showLoading: false);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveStreak() async {
    final workspace = _selectedWorkspace;
    if (workspace == null) return;

    setState(() => _saving = true);
    try {
      await _streakRepository.saveStreak(
        profileId: workspace.id,
        localToday: DateTime.now(),
      );
      await _load(showLoading: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Racha salvada. Sí, esta vez cuenta.')),
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onDestinationSelected(AppDestination destination) {
    switch (destination) {
      case AppDestination.home:
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case AppDestination.calendar:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => CalendarPage(
              client: widget.client,
              initialWorkspaceId: _selectedWorkspaceId,
            ),
          ),
          (route) => route.isFirst,
        );
        break;
      case AppDestination.streaks:
        break;
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is PostgrestException
        ? error.message
        : error is StateError
        ? error.message.toString()
        : 'No se pudo actualizar tu racha. Inténtalo otra vez.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rachas & comodines')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _StreakErrorState(onRetry: () => _load())
            : _workspaces.isEmpty
            ? const _NoWorkspaceState()
            : _buildContent(),
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedDestination: AppDestination.streaks,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }

  Widget _buildContent() {
    final workspace = _selectedWorkspace!;
    final today = DateTime.now();
    final currentStreak = StreakCalculator.effectiveCurrentStreak(
      workspace,
      today,
    );
    final saveTarget = StreakCalculator.wildcardTarget(workspace, today);
    final eventsByDate = <DateTime, StreakDayModel>{
      for (final item in _week) StreakCalculator.dateOnly(item.date): item,
    };
    final weekStart = StreakCalculator.mondayOf(today);
    final weekendFrozen =
        workspace.frozenDaysMask.contains(DateTime.saturday) &&
        workspace.frozenDaysMask.contains(DateTime.sunday);

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          _WorkspacePicker(
            workspaces: _workspaces,
            selectedId: workspace.id,
            onSelected: _selectWorkspace,
          ),
          const SizedBox(height: 22),
          _StreakHero(
            currentStreak: currentStreak,
            maxStreak: workspace.maxStreak,
            goal: 30,
          ),
          const SizedBox(height: 22),
          Text('Esta semana', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _WeekStrip(
            weekStart: weekStart,
            today: today,
            frozenDays: workspace.frozenDaysMask,
            events: eventsByDate,
          ),
          const SizedBox(height: 22),
          _WildcardCard(
            available: workspace.wildcardsAvailable,
            saveTarget: saveTarget,
            saving: _saving,
            onSave:
                _saving ||
                    saveTarget == null ||
                    workspace.wildcardsAvailable <= 0
                ? null
                : _saveStreak,
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              value: weekendFrozen,
              onChanged: _saving ? null : _toggleWeekendFreeze,
              tileColor: AppColors.surfaceSoft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
                side: const BorderSide(color: AppColors.border),
              ),
              activeThumbColor: AppColors.action,
              secondary: const Icon(
                Icons.nights_stay_outlined,
                color: AppColors.action,
              ),
              title: const Text(
                'Días libres oficiales',
                style: TextStyle(
                  color: AppColors.textOnSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Congelar sábado y domingo para que tu racha sobreviva al fin de semana.',
                style: TextStyle(color: AppColors.textOnSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspacePicker extends StatelessWidget {
  const _WorkspacePicker({
    required this.workspaces,
    required this.selectedId,
    required this.onSelected,
  });

  final List<ProfileWorkspaceModel> workspaces;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final workspace in workspaces)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(workspace.name),
                selected: workspace.id == selectedId,
                onSelected: (_) => onSelected(workspace.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({
    required this.currentStreak,
    required this.maxStreak,
    required this.goal,
  });

  final int currentStreak;
  final int maxStreak;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final progress = (currentStreak / goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.heroCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.lime,
                size: 34,
              ),
              const SizedBox(width: 10),
              Text(
                '$currentStreak',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.lime,
                  fontSize: 42,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'DÍAS DE RACHA',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const Spacer(),
              Text(
                'MEJOR: $maxStreak',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0x44FFFFFF),
              valueColor: const AlwaysStoppedAnimation(AppColors.lime),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$currentStreak / $goal días para el siguiente objetivo',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.weekStart,
    required this.today,
    required this.frozenDays,
    required this.events,
  });

  static const _labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  final DateTime weekStart;
  final DateTime today;
  final List<int> frozenDays;
  final Map<DateTime, StreakDayModel> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: AppTheme.surfaceCardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          final date = weekStart.add(Duration(days: index));
          final event = events[StreakCalculator.dateOnly(date)];
          final isFrozen = frozenDays.contains(date.weekday);
          final isFuture = StreakCalculator.dateOnly(
            date,
          ).isAfter(StreakCalculator.dateOnly(today));
          final isToday =
              StreakCalculator.dateOnly(date) ==
              StreakCalculator.dateOnly(today);

          final IconData icon;
          final Color color;
          final String status;

          if (isFrozen) {
            icon = date.weekday == DateTime.saturday
                ? Icons.nights_stay_rounded
                : Icons.schedule_rounded;
            color = AppColors.action;
            status = 'Día congelado';
          } else if (event?.wildcardUsed == true &&
              event?.hasTaskCompletion != true) {
            icon = Icons.shield_rounded;
            color = AppColors.actionLight;
            status = 'Racha salvada con comodín';
          } else if (event?.hasTaskCompletion == true) {
            icon = Icons.local_fire_department_rounded;
            color = AppColors.limeStrong;
            status = 'Día cumplido';
          } else if (isToday) {
            icon = Icons.local_fire_department_outlined;
            color = AppColors.actionLight;
            status = 'Hoy';
          } else if (isFuture) {
            icon = Icons.circle_outlined;
            color = AppColors.textSecondary;
            status = 'Próximamente';
          } else {
            icon = Icons.close_rounded;
            color = const Color(0xFFE87979);
            status = 'Día perdido';
          }

          return Tooltip(
            message: '$status · ${date.day}/${date.month}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _labels[index],
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textOnSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(height: 5),
                Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textOnSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _WildcardCard extends StatelessWidget {
  const _WildcardCard({
    required this.available,
    required this.saveTarget,
    required this.saving,
    required this.onSave,
  });

  final int available;
  final DateTime? saveTarget;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final targetLabel = saveTarget == null
        ? 'No hay un día laborable pendiente que un comodín pueda cubrir.'
        : 'Puede cubrir el ${saveTarget!.day}/${saveTarget!.month}.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: AppColors.action),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Comodines Anti-Vergüenza',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textOnSurface,
                  ),
                ),
              ),
              Text(
                '$available / 3',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.action),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            targetLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textOnSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSave,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.health_and_safety_outlined),
              label: const Text('Salvar racha'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoWorkspaceState extends StatelessWidget {
  const _NoWorkspaceState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Crea primero un espacio de trabajo desde el Dashboard para empezar tu racha.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _StreakErrorState extends StatelessWidget {
  const _StreakErrorState({required this.onRetry});

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
              'No se pudo cargar la racha.',
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
