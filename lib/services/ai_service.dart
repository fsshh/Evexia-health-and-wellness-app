import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';

class AIService {
  static const String _model = 'gemini-2.5-flash';
  // Replace with your actual Google AI Studio API key
  static const String _apiKey = 'API_KEY';

  static String get _apiUrl =>
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey';

  static const int _maxRetries = 4;
  // Delay between retries: 5s, 10s, 20s
  static const List<int> _retryDelaysSeconds = [5, 10, 20];

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

        // 429 = rate limited / overloaded — retry after delay
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
        return _parseRecommendations(rawText);

      } on Exception catch (e) {
        // Don't retry on non-rate-limit errors
        rethrow;
      }
    }
  }

  static String _buildPrompt(UserProfile profile) {
    return '''
You are an expert health and wellness coach. A user has completed a short health survey.

Survey answers:
- Current activity level: ${profile.behavior}
- Weight goal: ${profile.weightGoal}
${profile.notes != null && profile.notes!.isNotEmpty ? '- Additional notes: ${profile.notes}' : ''}

Generate exactly 3 detailed, personalized health recommendations — one each for nutrition, exercise, and sleep.

Requirements per category:

NUTRITION:
- State a specific daily calorie target (e.g. "Aim for ~2,000 kcal/day") based on their goal
- Give a recommended macro split (protein / carbs / fats as percentages and grams)
- List 3–4 specific foods to prioritize with brief reasons
- List 1–2 foods or habits to avoid or limit
- Mention meal timing or frequency if relevant

EXERCISE:
- Specify workout frequency (days/week) and session duration
- Recommend exercise types suited to their activity level and goal (e.g. strength training, cardio, HIIT, yoga)
- Give one concrete example weekly schedule or workout routine
- Include a warm-up or recovery tip

SLEEP:
- State the recommended sleep duration (hours/night)
- Suggest a specific bedtime and wake-up time window
- List 3 actionable habits to improve sleep quality (e.g. no screens 1 hr before bed, magnesium glycinate 200mg, cool room at 18–20°C)
- Explain how better sleep directly supports their specific goal

Respond ONLY with a valid JSON array. No preamble, no markdown fences, no extra text whatsoever. Use this exact structure:

[
  {
    "category": "nutrition",
    "title": "Your Nutrition Plan",
    "summary": "One sentence personalised overview of the nutrition approach for this user.",
    "bullets": [
      "Detailed point 1",
      "Detailed point 2",
      "Detailed point 3",
      "Detailed point 4",
      "Detailed point 5"
    ]
  },
  {
    "category": "exercise",
    "title": "Your Exercise Plan",
    "summary": "One sentence personalised overview of the exercise approach for this user.",
    "bullets": [
      "Detailed point 1",
      "Detailed point 2",
      "Detailed point 3",
      "Detailed point 4",
      "Detailed point 5"
    ]
  },
  {
    "category": "sleep",
    "title": "Your Sleep Plan",
    "summary": "One sentence personalised overview of the sleep approach for this user.",
    "bullets": [
      "Detailed point 1",
      "Detailed point 2",
      "Detailed point 3",
      "Detailed point 4",
      "Detailed point 5"
    ]
  }
]
''';
  }

  static List<AIRecommendation> _parseRecommendations(String rawText) {
    // Strip markdown fences Gemini sometimes adds despite instructions
    String clean = rawText
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    // Extract just the JSON array — guards against any leading/trailing prose
    final startIndex = clean.indexOf('[');
    final endIndex = clean.lastIndexOf(']');
    if (startIndex != -1 && endIndex != -1) {
      clean = clean.substring(startIndex, endIndex + 1);
    }

    print('Raw Gemini response: $rawText');
    final List<dynamic> parsed = jsonDecode(clean);

    return parsed.map((item) {
      return AIRecommendation(
        category: item['category'] as String,
        title: item['title'] as String,
        summary: item['summary'] as String,
        bullets: List<String>.from(item['bullets'] as List),
      );
    }).toList();
  }
}
