class UserProfile {
  final List<String> primaryGoals;
  final List<String> struggles;
  final String mealPlanningFrequency;
  final String activityLevel;
  final String sleepHours;
  final List<String> dietaryPatterns;
  final String? notes;

  const UserProfile({
    required this.primaryGoals,
    required this.struggles,
    required this.mealPlanningFrequency,
    required this.activityLevel,
    required this.sleepHours,
    required this.dietaryPatterns,
    this.notes,
  });
}

/// Three states for each day circle:
/// neutral → done → missed → neutral → ...
enum DayState { neutral, done, missed }

class TodoItem {
  final String task;
  final String detail;
  final List<DayState> days; // 7 entries, Mon–Sun

  TodoItem({
    required this.task,
    required this.detail,
    List<DayState>? days,
  }) : days = days ?? List.filled(7, DayState.neutral);

  TodoItem copyWithDay(int dayIndex, DayState state) {
    final newDays = List<DayState>.from(days);
    newDays[dayIndex] = state;
    return TodoItem(task: task, detail: detail, days: newDays);
  }
}

class AIRecommendation {
  final String category; // 'nutrition' | 'exercise' | 'sleep'
  final String title;
  final String summary;
  final List<TodoItem> todos;

  const AIRecommendation({
    required this.category,
    required this.title,
    required this.summary,
    required this.todos,
  });
}
