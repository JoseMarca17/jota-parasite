class ProfileWorkspaceModel {
  const ProfileWorkspaceModel({
    required this.id,
    required this.userId,
    required this.name,
    this.colorHex = 4285284024,
    this.iconName = 'school',
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.lastCompletedDate,
    this.wildcardsAvailable = 3,
    this.frozenDaysMask = const [6, 7],
    this.xpTotal = 0,
    this.wildcardsPeriodStart,
  });

  final String id;
  final String userId;
  final String name;
  final int colorHex;
  final String iconName;
  final int currentStreak;
  final int maxStreak;
  final DateTime? lastCompletedDate;
  final int wildcardsAvailable;
  final List<int> frozenDaysMask;
  final int xpTotal;
  final DateTime? wildcardsPeriodStart;

  factory ProfileWorkspaceModel.fromJson(Map<String, dynamic> json) {
    return ProfileWorkspaceModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      colorHex: _intValue(json['color_hex'], defaultValue: 4285284024),
      iconName: json['icon_name'] as String? ?? 'school',
      currentStreak: _intValue(json['current_streak']),
      maxStreak: _intValue(json['max_streak']),
      lastCompletedDate: _dateOnlyValue(json['last_completed_date']),
      wildcardsAvailable: _intValue(
        json['wildcards_available'],
        defaultValue: 3,
      ),
      frozenDaysMask: _intList(
        json['frozen_days_mask'],
        defaultValue: const [6, 7],
      ),
      xpTotal: _intValue(json['xp_total']),
      wildcardsPeriodStart: _dateOnlyValue(json['wildcards_period_start']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'color_hex': colorHex,
    'icon_name': iconName,
    'current_streak': currentStreak,
    'max_streak': maxStreak,
    'last_completed_date': _dateOnlyToJson(lastCompletedDate),
    'wildcards_available': wildcardsAvailable,
    'frozen_days_mask': frozenDaysMask,
    'xp_total': xpTotal,
    'wildcards_period_start': _dateOnlyToJson(wildcardsPeriodStart),
  };

  ProfileWorkspaceModel copyWith({
    String? name,
    int? colorHex,
    String? iconName,
    int? currentStreak,
    int? maxStreak,
    DateTime? lastCompletedDate,
    int? wildcardsAvailable,
    List<int>? frozenDaysMask,
    int? xpTotal,
    DateTime? wildcardsPeriodStart,
  }) {
    return ProfileWorkspaceModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      wildcardsAvailable: wildcardsAvailable ?? this.wildcardsAvailable,
      frozenDaysMask: frozenDaysMask ?? this.frozenDaysMask,
      xpTotal: xpTotal ?? this.xpTotal,
      wildcardsPeriodStart: wildcardsPeriodStart ?? this.wildcardsPeriodStart,
    );
  }
}

int _intValue(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is num) return value.toInt();
  throw FormatException(
    'Se esperaba un entero, se recibió ${value.runtimeType}.',
  );
}

List<int> _intList(dynamic value, {required List<int> defaultValue}) {
  if (value == null) return defaultValue;
  if (value is! List) {
    throw const FormatException(
      'Se esperaba una lista de enteros para frozen_days_mask.',
    );
  }
  return value.map((item) => _intValue(item)).toList(growable: false);
}

DateTime? _dateOnlyValue(dynamic value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException(
      'Se esperaba una fecha ISO para last_completed_date.',
    );
  }
  return DateTime.parse(value);
}

String? _dateOnlyToJson(DateTime? value) {
  if (value == null) return null;
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
