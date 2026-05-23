import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────
// Firestore schema for friends
// ─────────────────────────────────────────────────────────
// users/{uid}/friends/{friendUid}
//   addedAt: timestamp
//
// users/{uid}           (already exists)
//   displayName, email, totalExp, weekNumber
// ─────────────────────────────────────────────────────────

class FriendsService {
  static final _db = FirebaseFirestore.instance;

  /// Search for a user by exact email address.
  /// Returns their public profile or null if not found.
  static Future<Map<String, dynamic>?> searchUser(String email) async {
    final query = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return {'uid': doc.id, ...doc.data()};
  }

  /// Add a friend (both directions so each user sees the other).
  static Future<void> addFriend(String uid, String friendUid) async {
    final batch = _db.batch();

    batch.set(
      _db.collection('users').doc(uid).collection('friends').doc(friendUid),
      {'addedAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      _db.collection('users').doc(friendUid).collection('friends').doc(uid),
      {'addedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  /// Remove a friend (both directions).
  static Future<void> removeFriend(String uid, String friendUid) async {
    final batch = _db.batch();

    batch.delete(_db.collection('users').doc(uid).collection('friends').doc(friendUid));
    batch.delete(_db.collection('users').doc(friendUid).collection('friends').doc(uid));

    await batch.commit();
  }

  /// Get all friends of a user with their full profile data.
  static Future<List<Map<String, dynamic>>> getFriends(String uid) async {
    final friendDocs = await _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .get();

    if (friendDocs.docs.isEmpty) return [];

    // Fetch each friend's profile in parallel
    final futures = friendDocs.docs.map((d) async {
      final profile = await _db.collection('users').doc(d.id).get();
      if (!profile.exists) return null;
      return {'uid': d.id, ...profile.data()!};
    });

    final results = await Future.wait(futures);
    return results.whereType<Map<String, dynamic>>().toList();
  }

  /// Get leaderboard: current user + all friends, sorted by totalExp descending.
  static Future<List<Map<String, dynamic>>> getLeaderboard(String uid) async {
    // Fetch current user profile
    final selfDoc = await _db.collection('users').doc(uid).get();
    if (!selfDoc.exists) return [];

    final self = {'uid': uid, ...selfDoc.data()!};

    // Fetch friends
    final friends = await getFriends(uid);

    // Combine and sort
    final all = [self, ...friends];
    all.sort((a, b) {
      final expA = (a['totalExp'] as int?) ?? 0;
      final expB = (b['totalExp'] as int?) ?? 0;
      return expB.compareTo(expA); // descending
    });

    return all;
  }
}
