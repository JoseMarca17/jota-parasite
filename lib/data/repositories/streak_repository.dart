import '../models/profile_workspace_model.dart';
import '../models/streak_day_model.dart';

abstract interface class StreakRepository {
  Future<void> refreshMonthlyWildcards(DateTime localToday);

  Future<List<StreakDayModel>> getWeek({
    required String profileId,
    required DateTime weekStart,
    required DateTime weekEnd,
  });

  Future<ProfileWorkspaceModel> saveStreak({
    required String profileId,
    required DateTime localToday,
  });
}
