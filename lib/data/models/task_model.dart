class TaskModel {
  const TaskModel({
    required this.id,
    required this.userId,
    required this.profileId,
    required this.title,
    required this.dueDate,
    required this.createdAt,
    this.description,
    this.isCompleted = false,
    this.completedAt,
    this.postponeCount = 0,
    this.affectsStreak = true,
    this.xpAwardedAt,
  });

  final String id;
  final String userId;
  final String profileId;
  final String title;
  final String? description;
  final DateTime dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final int postponeCount;
  final bool affectsStreak;
  final DateTime createdAt;
  final DateTime? xpAwardedAt;

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      profileId: json['profile_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: DateTime.parse(json['due_date'] as String),
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: _nullableDateTime(json['completed_at']),
      postponeCount: _intValue(json['postpone_count']),
      affectsStreak: json['affects_streak'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      xpAwardedAt: _nullableDateTime(json['xp_awarded_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'profile_id': profileId,
    'title': title,
    'description': description,
    'due_date': dueDate.toUtc().toIso8601String(),
    'is_completed': isCompleted,
    'completed_at': completedAt?.toUtc().toIso8601String(),
    'postpone_count': postponeCount,
    'affects_streak': affectsStreak,
    'created_at': createdAt.toUtc().toIso8601String(),
    'xp_awarded_at': xpAwardedAt?.toUtc().toIso8601String(),
  };
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  throw FormatException(
    'Se esperaba un entero, se recibió ${value.runtimeType}.',
  );
}

DateTime? _nullableDateTime(dynamic value) {
  if (value == null) return null;
  if (value is! String) {
    throw FormatException(
      'Se esperaba una fecha ISO, se recibió ${value.runtimeType}.',
    );
  }
  return DateTime.parse(value);
}
