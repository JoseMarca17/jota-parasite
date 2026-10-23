import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_workspace_model.dart';
import '../models/streak_day_model.dart';
import 'streak_repository.dart';

class SupabaseStreakRepository implements StreakRepository {
  SupabaseStreakRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión para consultar tu racha.');
    }
    return user.id;
  }

  @override
  Future<void> refreshMonthlyWildcards(DateTime localToday) async {
    await _client.rpc(
      'refresh_workspace_wildcards',
      params: {'p_local_today': _dateString(localToday)},
    );
  }

  @override
  Future<List<StreakDayModel>> getWeek({
    required String profileId,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    final rows = await _client
        .from('workspace_streak_days')
        .select('activity_date,has_task_completion,wildcard_used')
        .eq('user_id', _userId)
        .eq('profile_id', profileId)
        .gte('activity_date', _dateString(weekStart))
        .lte('activity_date', _dateString(weekEnd))
        .order('activity_date');

    return rows
        .map((row) => StreakDayModel.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<ProfileWorkspaceModel> saveStreak({
    required String profileId,
    required DateTime localToday,
  }) async {
    final row = await _client
        .rpc(
          'save_workspace_streak',
          params: {
            'p_profile_id': profileId,
            'p_local_today': _dateString(localToday),
          },
        )
        .single();

    return ProfileWorkspaceModel.fromJson(
      Map<String, dynamic>.from(row as Map),
    );
  }
}

String _dateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
