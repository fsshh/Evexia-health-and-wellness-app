import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────
// Firestore schema for friends
// ─────────────────────────────────────────────────────────
// users/{uid}/friends/{friendUid}
//   addedAt: timestamp
//
// users/{uid}
//   displayName, username, email, totalExp, weekNumber
// ─────────────────────────────────────────────────────────

class FriendsService {
  static final _db = FirebaseFirestore.instance;

  /// Search for a user by exact username (case-insensitive).
  /// Returns their public profile or null if not found.
  static Future<Map<String, dynamic>?> searchUser(String username) async {
    // Look up uid via the username index
    final usernameDoc = await _db
        .collection('usernames')
        .doc(username.trim().toLowerCase())
        .get();

    if (!usernameDoc.exists) return null;

    final uid = usernameDoc.data()?['uid'] as String?;
    if (uid == null) return null;

    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return null;

    return {'uid': uid, ...userDoc.data()!};
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
    final selfDoc = await _db.collection('users').doc(uid).get();
    if (!selfDoc.exists) return [];

    final self    = {'uid': uid, ...selfDoc.data()!};
    final friends = await getFriends(uid);
    final all     = [self, ...friends];

    all.sort((a, b) {
      final expA = (a['totalExp'] as int?) ?? 0;
      final expB = (b['totalExp'] as int?) ?? 0;
      return expB.compareTo(expA);
    });

    return all;
  }
}