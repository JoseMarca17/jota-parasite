class StreakDayModel {
  const StreakDayModel({
    required this.date,
    required this.hasTaskCompletion,
    required this.wildcardUsed,
  });

  final DateTime date;
  final bool hasTaskCompletion;
  final bool wildcardUsed;

  factory StreakDayModel.fromJson(Map<String, dynamic> json) {
    return StreakDayModel(
      date: DateTime.parse(json['activity_date'] as String),
      hasTaskCompletion: json['has_task_completion'] as bool? ?? false,
      wildcardUsed: json['wildcard_used'] as bool? ?? false,
    );
  }
}
