import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

// ─────────────────────────────────────────────────────────
// Firestore schema
// ─────────────────────────────────────────────────────────
// users/{uid}
//   displayName, email, createdAt, totalExp, weekNumber
//
// users/{uid}/survey/answers
//   primaryGoals, struggles, mealPlanningFrequency,
//   activityLevel, sleepHours, dietaryPatterns, notes
//
// users/{uid}/weeks/week_{N}
//   savedAt, expEarned,
//   recommendations: [ { category, title, summary,
//     todos: [ { task, detail, days: [0|1|2 …] } ] } ]
//   0 = neutral, 1 = done, 2 = missed
// ─────────────────────────────────────────────────────────

class DatabaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Helpers ───────────────────────────────────────────

  static int _encodeDay(DayState s) {
    switch (s) {
      case DayState.done:    return 1;
      case DayState.missed:  return 2;
      case DayState.neutral: return 0;
    }
  }

  static DayState _decodeDay(int v) {
    switch (v) {
      case 1:  return DayState.done;
      case 2:  return DayState.missed;
      default: return DayState.neutral;
    }
  }

  // ── User profile ──────────────────────────────────────

  static Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    await _db.collection('users').doc(uid).set({
      'displayName': displayName,
      'email':       email,
      'createdAt':   FieldValue.serverTimestamp(),
      'totalExp':    0,
      'weekNumber':  1,
    }, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  static Future<void> updateExpAndWeek({
    required String uid,
    required int totalExp,
    required int weekNumber,
  }) async {
    await _db.collection('users').doc(uid).update({
      'totalExp':   totalExp,
      'weekNumber': weekNumber,
    });
  }

  // ── Survey ────────────────────────────────────────────

  static Future<void> saveSurvey({
    required String uid,
    required UserProfile profile,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('survey')
        .doc('answers')
        .set({
      'primaryGoals':          profile.primaryGoals,
      'struggles':             profile.struggles,
      'mealPlanningFrequency': profile.mealPlanningFrequency,
      'activityLevel':         profile.activityLevel,
      'sleepHours':            profile.sleepHours,
      'dietaryPatterns':       profile.dietaryPatterns,
      'notes':                 profile.notes ?? '',
      'savedAt':               FieldValue.serverTimestamp(),
    });
  }

  static Future<UserProfile?> loadSurvey(String uid) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('survey')
        .doc('answers')
        .get();

    if (!doc.exists || doc.data() == null) return null;
    final d = doc.data()!;

    final notes = d['notes'] as String? ?? '';

    return UserProfile(
      primaryGoals:          List<String>.from(d['primaryGoals']    ?? []),
      struggles:             List<String>.from(d['struggles']        ?? []),
      mealPlanningFrequency: d['mealPlanningFrequency'] as String?   ?? '',
      activityLevel:         d['activityLevel']         as String?   ?? '',
      sleepHours:            d['sleepHours']            as String?   ?? '',
      dietaryPatterns:       List<String>.from(d['dietaryPatterns']  ?? []),
      notes:                 notes.isEmpty ? null : notes,
    );
  }

  // ── Weekly todo data ──────────────────────────────────

  static Future<void> saveWeekData({
    required String uid,
    required int weekNumber,
    required List<AIRecommendation> recommendations,
    required int expEarned,
  }) async {
    final List<Map<String, dynamic>> recsData = [];

    for (final rec in recommendations) {
      final List<Map<String, dynamic>> todosData = [];

      for (final todo in rec.todos) {
        todosData.add({
          'task':   todo.task,
          'detail': todo.detail,
          'days':   todo.days.map(_encodeDay).toList(),
        });
      }

      recsData.add({
        'category': rec.category,
        'title':    rec.title,
        'summary':  rec.summary,
        'todos':    todosData,
      });
    }

    await _db
        .collection('users')
        .doc(uid)
        .collection('weeks')
        .doc('week_$weekNumber')
        .set({
      'savedAt':         FieldValue.serverTimestamp(),
      'expEarned':       expEarned,
      'recommendations': recsData,
    });
  }

  static Future<List<AIRecommendation>?> loadWeekData({
    required String uid,
    required int weekNumber,
  }) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('weeks')
        .doc('week_$weekNumber')
        .get();

    if (!doc.exists || doc.data() == null) return null;

    final rawRecs = doc.data()!['recommendations'];
    if (rawRecs == null) return null;

    final List<AIRecommendation> result = [];

    for (final r in rawRecs as List<dynamic>) {
      final recMap  = r as Map<String, dynamic>;
      final rawTodos = recMap['todos'] as List<dynamic>? ?? [];

      final List<TodoItem> todos = [];

      for (final t in rawTodos) {
        final todoMap = t as Map<String, dynamic>;
        final rawDays = todoMap['days'] as List<dynamic>? ?? [];

        todos.add(TodoItem(
          task:   todoMap['task']   as String? ?? '',
          detail: todoMap['detail'] as String? ?? '',
          days:   rawDays
              .map((d) => _decodeDay((d as num).toInt()))
              .toList(),
        ));
      }

      result.add(AIRecommendation(
        category: recMap['category'] as String? ?? '',
        title:    recMap['title']    as String? ?? '',
        summary:  recMap['summary']  as String? ?? '',
        todos:    todos,
      ));
    }

    return result;
  }
}
