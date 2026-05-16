class UserProfile {
  final List<String> primaryGoals;       // Q1 — up to 2
  final List<String> struggles;          // Q2 — multi-select
  final String mealPlanningFrequency;    // Q3 — single
  final String activityLevel;            // Q4 — single
  final String sleepHours;               // Q5 — single
  final List<String> dietaryPatterns;    // Q6 — multi-select
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

class AIRecommendation {
  final String category; // 'nutrition' | 'exercise' | 'sleep'
  final String title;
  final String summary;
  final List<String> bullets;

  const AIRecommendation({
    required this.category,
    required this.title,
    required this.summary,
    required this.bullets,
  });
}
