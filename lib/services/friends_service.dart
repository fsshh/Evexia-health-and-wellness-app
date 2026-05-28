import 'package:cloud_firestore/cloud_firestore.dart';

// *** Contributions in the file: Dexter Logdonio, Raign Vincent Rueda ***
// ----------------------------------------------
// Firestore schema for friends
// ----------------------------------------------
// users/{uid}/friends/{friendUid}
//   addedAt: timestamp
//
// users/{uid}/friendRequests/{fromUid}
//   fromUid:      string
//   fromName:     string
//   fromUsername: string
//   sentAt:       timestamp
//   status:       'pending' | 'accepted' | 'declined'
//
// users/{uid}
//   displayName, username, email, totalExp, weekNumber
// ----------------------------------------------

class FriendsService {
  static final _db = FirebaseFirestore.instance;

  /// Search for a user by exact username (case-insensitive).
  static Future<Map<String, dynamic>?> searchUser(String username) async {
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

  // -----------------------Friend Requests-----------------------
  /// Send a friend request
  static Future<void> sendFriendRequest({
    required String uid,
    required String toUid,
    required String fromDisplayName,
    required String fromUsername,
  }) async {
    await _db
        .collection('users')
        .doc(toUid)
        .collection('friendRequests')
        .doc(uid)
        .set({
      'fromUid':      uid,
      'fromName':     fromDisplayName,
      'fromUsername': fromUsername,
      'sentAt':       FieldValue.serverTimestamp(),
      'status':       'pending',
    });
  }

  /// Cancel / withdraw a friend request
  static Future<void> cancelFriendRequest({
    required String uid,
    required String toUid,
  }) async {
    await _db
        .collection('users')
        .doc(toUid)
        .collection('friendRequests')
        .doc(uid)
        .delete();
  }

  /// Accept a friend request
  static Future<void> acceptFriendRequest({
    required String uid,
    required String fromUid,
  }) async {
    final batch = _db.batch();

    // Mark request accepted
    batch.update(
      _db.collection('users').doc(uid).collection('friendRequests').doc(fromUid),
      {'status': 'accepted'},
    );

    // Add mutual friendship
    batch.set(
      _db.collection('users').doc(uid).collection('friends').doc(fromUid),
      {'addedAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      _db.collection('users').doc(fromUid).collection('friends').doc(uid),
      {'addedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  /// Decline a friend request
  static Future<void> declineFriendRequest({
    required String uid,
    required String fromUid,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('friendRequests')
        .doc(fromUid)
        .delete();
  }

  /// Get all pending incoming friend requests for uid

static Future<List<Map<String, dynamic>>> getPendingRequests(String uid) async {
  final snap = await _db
      .collection('users')
      .doc(uid)
      .collection('friendRequests')
      .where('status', isEqualTo: 'pending')
      .get();

  final docs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  // Sort by client side timestamp (newest first). Server timestamp may be null if just created, so we default to 0.
  docs.sort((a, b) {
    final aTime = (a['sentAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
    final bTime = (b['sentAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
    return bTime.compareTo(aTime);
  });

  return docs;
}

  /// Check if uid has already sent a request to toUid (pending).
  static Future<bool> hasPendingRequestTo({
    required String uid,
    required String toUid,
  }) async {
    final doc = await _db
        .collection('users')
        .doc(toUid)
        .collection('friendRequests')
        .doc(uid)
        .get();
    return doc.exists && doc.data()?['status'] == 'pending';
  }

  //------------------------Friends------------------------
  /// Remove a friend (both users).
  static Future<void> removeFriend(String uid, String friendUid) async {
    final batch = _db.batch();

    batch.delete(_db.collection('users').doc(uid).collection('friends').doc(friendUid));
    batch.delete(_db.collection('users').doc(friendUid).collection('friends').doc(uid));

    await batch.commit();
  }

  /// Get all friends of a user with their full profile data
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