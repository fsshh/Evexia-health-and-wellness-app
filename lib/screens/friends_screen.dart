import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String? _searchError;
  Map<String, dynamic>? _searchResult;
  List<Map<String, dynamic>> _friends = [];
  bool _loadingFriends = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _loadingFriends = true);
    final uid = AuthService.currentUid!;
    final friends = await FriendsService.getFriends(uid);
    if (mounted) setState(() { _friends = friends; _loadingFriends = false; });
  }

  Future<void> _searchUser() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() { _searching = true; _searchError = null; _searchResult = null; });

    final result = await FriendsService.searchUser(query);
    if (!mounted) return;

    if (result == null) {
      setState(() { _searching = false; _searchError = 'No user found with that email.'; });
    } else if (result['uid'] == AuthService.currentUid) {
      setState(() { _searching = false; _searchError = 'That\'s you!'; });
    } else {
      setState(() { _searching = false; _searchResult = result; });
    }
  }

  Future<void> _addFriend(String friendUid) async {
    final uid = AuthService.currentUid!;
    await FriendsService.addFriend(uid, friendUid);
    _searchCtrl.clear();
    setState(() { _searchResult = null; _searchError = null; });
    await _loadFriends();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend added!'), backgroundColor: Color(0xFF4CAF50)),
      );
    }
  }

  Future<void> _removeFriend(String friendUid) async {
    final uid = AuthService.currentUid!;
    await FriendsService.removeFriend(uid, friendUid);
    await _loadFriends();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Friends',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 4),
                  Text('Add friends and compete on the leaderboard.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  const SizedBox(height: 16),

                  // ── Search bar ──────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          keyboardType: TextInputType.emailAddress,
                          onSubmitted: (_) => _searchUser(),
                          style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                          decoration: InputDecoration(
                            hintText: 'Search by email address...',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.grey[200]!)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.grey[200]!)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFF1A1A2E), width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _searching ? null : _searchUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A2E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: _searching
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),

                  // ── Search result / error ───────────────
                  if (_searchError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade100)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.red.shade400, size: 16),
                          const SizedBox(width: 8),
                          Text(_searchError!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  if (_searchResult != null) ...[
                    const SizedBox(height: 10),
                    _SearchResultCard(
                      user: _searchResult!,
                      alreadyFriend: _friends.any((f) => f['uid'] == _searchResult!['uid']),
                      onAdd: () => _addFriend(_searchResult!['uid']),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Friends list ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _loadingFriends ? 'Friends' : 'Friends (${_friends.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _loadingFriends
                  ? const Center(child: CircularProgressIndicator())
                  : _friends.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline_rounded, size: 56, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No friends yet', style: TextStyle(fontSize: 15, color: Colors.grey[400], fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Search by email to add friends.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _friends.length,
                          itemBuilder: (_, i) => _FriendTile(
                            friend: _friends[i],
                            onRemove: () => _removeFriend(_friends[i]['uid']),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// ── Search result card ──────────────────────────────────────
class _SearchResultCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool alreadyFriend;
  final VoidCallback onAdd;

  const _SearchResultCard({required this.user, required this.alreadyFriend, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A1A2E).withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          _Avatar(name: user['displayName'] ?? 'U', size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['displayName'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                Text(user['email'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          if (alreadyFriend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
              child: Text('Added', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
            )
          else
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Add Friend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ── Friend tile ────────────────────────────────────────────
class _FriendTile extends StatelessWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onRemove;

  const _FriendTile({required this.friend, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final exp   = (friend['totalExp'] as int?) ?? 0;
    final level = (exp ~/ 500) + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          _Avatar(name: friend['displayName'] ?? 'U', size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend['displayName'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                const SizedBox(height: 2),
                Text('Level $level  •  $exp EXP',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.person_remove_outlined, color: Colors.red.shade300, size: 20),
            onPressed: () => _confirmRemove(context),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove friend?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remove ${friend['displayName']} from your friends list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(context); onRemove(); },
            child: Text('Remove', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Shared avatar widget ───────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  const _Avatar({required this.name, required this.size});

  Color _colorFromName(String name) {
    final colors = [
      const Color(0xFF1A1A2E), const Color(0xFF2196F3), const Color(0xFF4CAF50),
      const Color(0xFF9C27B0), const Color(0xFFFF6B35), const Color(0xFFFF9800),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _colorFromName(name),
      child: Text(
        name[0].toUpperCase(),
        style: TextStyle(fontSize: size * 0.38, color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
