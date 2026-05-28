import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

// ─────────────────────────────────────────────────────────
// Firestore schema
// ─────────────────────────────────────────────────────────
// users/{uid}
//   displayName, username, email, createdAt, totalExp, weekNumber,
//   weekStartTimestamp
//
// usernames/{username}   ← uniqueness index
//   uid: string
//
// users/{uid}/survey/answers
//   primaryGoals, struggles, mealPlanningFrequency,
//   activityLevel, sleepHours, dietaryPatterns, notes
//
// users/{uid}/weeks/week_{N}
//   savedAt, expEarned, weekStart, weekEnd
//   recommendations: [ { category, title, summary,
//     todos: [ { task, detail, days: [0|1|2 …] } ] } ]
//   0 = neutral, 1 = done, 2 = missed
//
// users/{uid}/weekReports/week_{N}
//   weekNumber, weekStart, weekEnd, totalTasks, doneTasks,
//   missedTasks, expEarned, commendation, createdAt
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

  // ── Username uniqueness ───────────────────────────────

  /// Returns true if the username is available (not taken).
  static Future<bool> isUsernameAvailable(String username) async {
    final doc = await _db.collection('usernames').doc(username.toLowerCase()).get();
    return !doc.exists;
  }

  /// Validates username format: 3–20 chars, letters/numbers/._  no spaces.
  static String? validateUsername(String username) {
    if (username.isEmpty) return 'Username is required.';
    if (username.length < 3) return 'Username must be at least 3 characters.';
    if (username.length > 20) return 'Username must be 20 characters or fewer.';
    final regex = RegExp(r'^[a-zA-Z0-9._]+$');
    if (!regex.hasMatch(username)) {
      return 'Only letters, numbers, "." and "_" are allowed.';
    }
    return null;
  }

  // ── User profile ──────────────────────────────────────

  /// Creates the user document and reserves the username atomically.
  static Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
    required String username,
  }) async {
    final batch = _db.batch();

    // Reserve username
    batch.set(
      _db.collection('usernames').doc(username.toLowerCase()),
      {'uid': uid},
    );

    // Create user doc
    batch.set(
      _db.collection('users').doc(uid),
      {
        'displayName':        displayName.isEmpty ? username : displayName,
        'username':           username.toLowerCase(),
        'email':              email.toLowerCase(),
        'createdAt':          FieldValue.serverTimestamp(),
        'totalExp':           0,
        'weekNumber':         1,
        'weekStartTimestamp': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
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
      'totalExp':           totalExp,
      'weekNumber':         weekNumber,
      'weekStartTimestamp': FieldValue.serverTimestamp(),
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
    DateTime? weekStart,
    Set<int>? claimedDays,
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
      'weekStart':       weekStart != null ? Timestamp.fromDate(weekStart) : FieldValue.serverTimestamp(),
      'claimedDays':     claimedDays != null ? claimedDays.toList() : [],
      'recommendations': recsData,
    });
  }

  static Future<List<AIRecommendation>?> loadWeekData({
    required String uid,
    required int weekNumber,
  }) async {
    final result = await loadWeekDataFull(uid: uid, weekNumber: weekNumber);
    return result?['recommendations'] as List<AIRecommendation>?;
  }

  /// Loads recommendations AND claimedDays for a given week.
  static Future<Map<String, dynamic>?> loadWeekDataFull({
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
      final recMap   = r as Map<String, dynamic>;
      final rawTodos = recMap['todos'] as List<dynamic>? ?? [];
      final List<TodoItem> todos = [];

      for (final t in rawTodos) {
        final todoMap = t as Map<String, dynamic>;
        final rawDays = todoMap['days'] as List<dynamic>? ?? [];
        todos.add(TodoItem(
          task:   todoMap['task']   as String? ?? '',
          detail: todoMap['detail'] as String? ?? '',
          days:   rawDays.map((d) => _decodeDay((d as num).toInt())).toList(),
        ));
      }

      result.add(AIRecommendation(
        category: recMap['category'] as String? ?? '',
        title:    recMap['title']    as String? ?? '',
        summary:  recMap['summary']  as String? ?? '',
        todos:    todos,
      ));
    }

    // Parse claimed days
    final rawClaimed = doc.data()!['claimedDays'];
    final claimedDays = rawClaimed != null
        ? Set<int>.from((rawClaimed as List<dynamic>).map((e) => (e as num).toInt()))
        : <int>{};

    return {
      'recommendations': result,
      'claimedDays': claimedDays,
    };
  }

  // ── Week Reports ──────────────────────────────────────

  /// Saves a weekly performance report when the week is finalized.
  static Future<void> saveWeekReport({
    required String uid,
    required int weekNumber,
    required int totalTasks,
    required int doneTasks,
    required int missedTasks,
    required int expEarned,
    required String commendation,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('weekReports')
        .doc('week_$weekNumber')
        .set({
      'weekNumber':   weekNumber,
      'weekStart':    Timestamp.fromDate(weekStart),
      'weekEnd':      Timestamp.fromDate(weekEnd),
      'totalTasks':   totalTasks,
      'doneTasks':    doneTasks,
      'missedTasks':  missedTasks,
      'expEarned':    expEarned,
      'commendation': commendation,
      'createdAt':    FieldValue.serverTimestamp(),
    });
  }

  /// Loads all weekly reports ordered by week number descending.
  static Future<List<Map<String, dynamic>>> loadWeekReports(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('weekReports')
        .orderBy('weekNumber', descending: true)
        .get();

    return snap.docs.map((d) => d.data()).toList();
  }
}