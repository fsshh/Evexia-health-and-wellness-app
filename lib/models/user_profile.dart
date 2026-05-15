class UserProfile {
  final String behavior;
  final String weightGoal;
  final String? notes;

  const UserProfile({
    required this.behavior,
    required this.weightGoal,
    this.notes,
  });
}

class AIRecommendation {
  final String category; // 'nutrition' | 'exercise' | 'sleep'
  final String title;
  final String summary;       // 1-sentence overview shown collapsed
  final List<String> bullets; // detailed bullet points shown when expanded

  const AIRecommendation({
    required this.category,
    required this.title,
    required this.summary,
    required this.bullets,
  });
}
