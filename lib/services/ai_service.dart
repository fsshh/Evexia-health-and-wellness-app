import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';

class AIService {
  static const String _model = 'gemini-2.5-flash';
  static const String _apiKey = 'AIzaSyClEPdHn-OUMKV9kMTZruU4zkkmA4FzFbM';
  static const int _maxRetries = 4;
  static const List<int> _retryDelaysSeconds = [5, 10, 20];

  static String get _apiUrl =>
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey';

  static Future<List<AIRecommendation>> getRecommendations(UserProfile profile) async {
    int attempt = 0;
    while (true) {
      try {
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [{'text': _buildPrompt(profile)}],
              },
            ],
            'generationConfig': {
              'maxOutputTokens': 8192,
              'temperature': 0.7,
            },
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 429 || response.statusCode == 503) {
          if (attempt < _maxRetries - 1) {
            final delay = _retryDelaysSeconds[attempt.clamp(0, _retryDelaysSeconds.length - 1)];
            print('Gemini busy (${response.statusCode}), retrying in ${delay}s... (attempt ${attempt + 1}/$_maxRetries)');
            await Future.delayed(Duration(seconds: delay));
            attempt++;
            continue;
          }
          throw Exception('Gemini is currently overloaded. Please try again in a moment.');
        }

        if (response.statusCode != 200) {
          print('Gemini error: ${response.statusCode} — ${response.body}');
          throw Exception('API error ${response.statusCode}: ${response.body}');
        }

        final data = jsonDecode(response.body);
        final rawText = data['candidates'][0]['content']['parts'][0]['text'] as String;
        print('Raw Gemini response: $rawText');
        return _parseRecommendations(rawText);

      } on Exception {
        rethrow;
      }
    }
  }

  static String _buildPrompt(UserProfile profile) {
    final goals = profile.primaryGoals.join(', ');
    final struggles = profile.struggles.isEmpty ? 'None specified' : profile.struggles.join(', ');
    final diet = profile.dietaryPatterns.isEmpty ? 'No restrictions' : profile.dietaryPatterns.join(', ');

    return '''
You are an expert health and wellness coach. A user has completed a detailed health survey.

Survey answers:
1. Primary goals (up to 2): $goals
2. Biggest struggles: $struggles
3. Meal planning frequency: ${profile.mealPlanningFrequency}
4. Daily activity level: ${profile.activityLevel}
5. Average nightly sleep: ${profile.sleepHours}
6. Dietary patterns / restrictions: $diet
${profile.notes != null && profile.notes!.isNotEmpty ? '7. Additional notes: ${profile.notes}' : ''}

Generate exactly 3 daily to-do plan sections — one each for nutrition, exercise, and sleep.
Each section must contain EXACTLY 4 specific, actionable daily to-do tasks with concrete numbers/quantities.

Guidelines per category:

NUTRITION todos (4 tasks):
- Give exact meal or eating targets, e.g. "Eat 150g of grilled chicken breast for lunch", "Drink 2.5 litres of water throughout the day", "Have a breakfast with 30g of protein within 1 hour of waking", "Limit sugar intake to under 25g today"
- Respect their dietary restrictions: $diet
- Tailor to their goal: $goals

EXERCISE todos (4 tasks):
- Give SPECIFIC exercise targets with sets/reps/duration, e.g. "Complete 3 sets of 15 push-ups (rest 60s between sets)", "Walk or jog for 30 minutes at a moderate pace", "Do 3 sets of 20 bodyweight squats", "Hold a plank for 3 x 30 seconds"
- Match intensity to their activity level: ${profile.activityLevel}
- Address their struggles where relevant: $struggles

SLEEP todos (4 tasks):
- Give SPECIFIC sleep hygiene actions with times, e.g. "Stop using all screens by 9:30 PM", "Take 200mg magnesium glycinate 30 minutes before bed", "Set a consistent bedtime alarm for 10:00 PM", "Keep your bedroom at 18–20°C tonight"
- Reference their current sleep: ${profile.sleepHours}

Respond ONLY with a valid JSON array. No preamble, no markdown fences, no extra text. Use this exact structure:

[
  {
    "category": "nutrition",
    "title": "Today's Nutrition Tasks",
    "summary": "One sentence overview personalised to this user's nutrition goal.",
    "todos": [
      { "task": "Short task label (max 8 words)", "detail": "Brief extra detail or reason (max 12 words)" },
      { "task": "Short task label (max 8 words)", "detail": "Brief extra detail or reason (max 12 words)" },
      { "task": "Short task label (max 8 words)", "detail": "Brief extra detail or reason (max 12 words)" },
      { "task": "Short task label (max 8 words)", "detail": "Brief extra detail or reason (max 12 words)" }
    ]
  },
  {
    "category": "exercise",
    "title": "Today's Exercise Tasks",
    "summary": "One sentence overview personalised to this user's exercise goal.",
    "todos": [
      { "task": "Short task label (max 8 words)", "detail": "Brief extra detail or reason (max 12 words)" },
      { "task": "Short task label (max 8 words)", "detail": "Brief extra detail or reason (max 12 words)" },
      { "task": "Short task label (max 8 words)", "detail": "Brief extra detail or reason (max 12 words)" },
      { "task": "Short task label (max 8 words)", "detail": "Brief extra detail or reason (max 12 words)" }
    ]
  },
  {
    "category": "sleep",
    "title": "Tonight's Sleep Tasks",
    "summary": "One sentence overview personalised to this user's sleep situation.",
    "todos": [
      { "task": "Short task label (max 8 words)", "detail": "Brief extra detail or reason (max 12 words)" },
      { "task": "Short task label (max 8 words)", "detail": "Brief extra detail or reason (max 12 words)" },
      { "task": "Short task label (max 8 words)", "detail": "Brief extra detail or reason (max 12 words)" },
      { "task": "Short task label (max 8 words)", "detail": "Brief extra detail or reason (max 12 words)" }
    ]
  }
]
''';
  }

  static List<AIRecommendation> _parseRecommendations(String rawText) {
    String clean = rawText
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final startIndex = clean.indexOf('[');
    final endIndex = clean.lastIndexOf(']');
    if (startIndex != -1 && endIndex != -1) {
      clean = clean.substring(startIndex, endIndex + 1);
    }

    final List<dynamic> parsed = jsonDecode(clean);

    return parsed.map((item) {
      final rawTodos = item['todos'] as List;
      final todos = rawTodos.map((t) => TodoItem(
        task: t['task'] as String,
        detail: t['detail'] as String,
      )).toList();

      return AIRecommendation(
        category: item['category'] as String,
        title: item['title'] as String,
        summary: item['summary'] as String,
        todos: todos,
      );
    }).toList();
  }
}