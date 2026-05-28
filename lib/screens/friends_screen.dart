import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/friends_service.dart';

/// *** Contributions in the file: Dexter Logdonio, Raign Vincent Rueda ***

/// Screen for managing friends: search by username, send/cancel requests, accept/decline

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String? _searchError;
  Map<String, dynamic>? _searchResult;
  bool _requestSent = false;      // tracks if we just sent a request this session
  bool _sendingRequest = false;

  List<Map<String, dynamic>> _friends = [];
  bool _loadingFriends = true;

  List<Map<String, dynamic>> _pendingRequests = [];
  bool _loadingRequests = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadFriends(), _loadRequests()]);
  }

  Future<void> _loadFriends() async {
    setState(() => _loadingFriends = true);
    final uid     = AuthService.currentUid!;
    final friends = await FriendsService.getFriends(uid);
    if (mounted) setState(() { _friends = friends; _loadingFriends = false; });
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    final uid      = AuthService.currentUid!;
    final requests = await FriendsService.getPendingRequests(uid);
    if (mounted) setState(() { _pendingRequests = requests; _loadingRequests = false; });
  }

  Future<void> _searchUser() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching      = true;
      _searchError    = null;
      _searchResult   = null;
      _requestSent    = false;
    });

    final result = await FriendsService.searchUser(query);
    if (!mounted) return;

    if (result == null) {
      setState(() { _searching = false; _searchError = 'No user found with that username.'; });
      return;
    }
    if (result['uid'] == AuthService.currentUid) {
      setState(() { _searching = false; _searchError = "That's you!"; });
      return;
    }

    // Check if already friends
    final alreadyFriend = _friends.any((f) => f['uid'] == result['uid']);

    // Check if request already pending
    final hasPending = !alreadyFriend
        ? await FriendsService.hasPendingRequestTo(
            uid: AuthService.currentUid!,
            toUid: result['uid'],
          )
        : false;

    if (!mounted) return;
    setState(() {
      _searching    = false;
      _searchResult = result;
      _requestSent  = hasPending;
    });
  }

  Future<void> _sendRequest(String toUid) async {
    setState(() => _sendingRequest = true);
    final uid      = AuthService.currentUid!;
    final profile  = await DatabaseService.getUserProfile(uid);
    final fromName     = profile?['displayName'] as String? ?? 'User';
    final fromUsername = profile?['username']    as String? ?? '';

    await FriendsService.sendFriendRequest(
      uid:             uid,
      toUid:           toUid,
      fromDisplayName: fromName,
      fromUsername:    fromUsername,
    );

    if (!mounted) return;
    setState(() { _sendingRequest = false; _requestSent = true; });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Friend request sent!'),
          backgroundColor: Color(0xFF999A5E)),
    );
  }

  Future<void> _cancelRequest(String toUid) async {
    await FriendsService.cancelFriendRequest(
        uid: AuthService.currentUid!, toUid: toUid);
    if (!mounted) return;
    setState(() => _requestSent = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request cancelled.')),
    );
  }

  Future<void> _acceptRequest(String fromUid) async {
    await FriendsService.acceptFriendRequest(
        uid: AuthService.currentUid!, fromUid: fromUid);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Friend added!'),
            backgroundColor: Color(0xFF4CAF50)),
      );
    }
  }

  Future<void> _declineRequest(String fromUid) async {
    await FriendsService.declineFriendRequest(
        uid: AuthService.currentUid!, fromUid: fromUid);
    await _loadRequests();
  }

  Future<void> _removeFriend(String friendUid) async {
    await FriendsService.removeFriend(AuthService.currentUid!, friendUid);
    await _loadFriends();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A2D3E) : const Color(0xFFF1EFEE);
    final cardCol = isDark ? const Color(0xFF363A52) : Colors.white;
    final txtCol  = isDark ? Colors.white : const Color(0xFF454D6E);

    final pendingBadge = _pendingRequests.length;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Friends',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800, color: txtCol)),
                  const SizedBox(height: 4),
                  Text('Add friends and compete on the leaderboard.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  const SizedBox(height: 16),

                  // ── Search bar ────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onSubmitted: (_) => _searchUser(),
                          style: TextStyle(fontSize: 14, color: txtCol),
                          decoration: InputDecoration(
                            hintText: 'Search by username...',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                            prefixIcon: Icon(Icons.alternate_email_rounded,
                                color: Colors.grey[400], size: 20),
                            filled: true,
                            fillColor: cardCol,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[200]!)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[200]!)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF454D6E),
                                    width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _searching ? null : _searchUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF454D6E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: _searching
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Search',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),

                  // ── Search result / error ─────────────
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
                          Icon(Icons.info_outline_rounded,
                              color: Colors.red.shade400, size: 16),
                          const SizedBox(width: 8),
                          Text(_searchError!,
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  if (_searchResult != null) ...[
                    const SizedBox(height: 10),
                    _SearchResultCard(
                      user: _searchResult!,
                      alreadyFriend:
                          _friends.any((f) => f['uid'] == _searchResult!['uid']),
                      requestSent:   _requestSent,
                      sendingRequest: _sendingRequest,
                      onSendRequest:  () => _sendRequest(_searchResult!['uid']),
                      onCancelRequest: () => _cancelRequest(_searchResult!['uid']),
                      cardColor: cardCol,
                      txtColor:  txtCol,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Tabs ──────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3A3F58)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabCtrl,
                      indicator: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF363A52)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4)
                        ],
                      ),
                      indicatorPadding: const EdgeInsets.all(3),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor:
                          isDark ? Colors.white : const Color(0xFF454D6E),
                      unselectedLabelColor: Colors.grey[500],
                      labelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: 'Friends (${_friends.length})'),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Requests'),
                              if (pendingBadge > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade400,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('$pendingBadge',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Tab views ────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Tab 0: Friends list ───────────────
                  _loadingFriends
                      ? const Center(child: CircularProgressIndicator())
                      : _friends.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline_rounded,
                                      size: 56, color: Colors.grey[300]),
                                  const SizedBox(height: 12),
                                  Text('No friends yet',
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey[400],
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text('Search by username to add friends.',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[400])),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadFriends,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                itemCount: _friends.length,
                                itemBuilder: (_, i) => _FriendTile(
                                  friend:    _friends[i],
                                  onRemove:  () =>
                                      _removeFriend(_friends[i]['uid']),
                                  cardColor: isDark
                                      ? const Color(0xFF363A52)
                                      : Colors.white,
                                  txtColor: isDark
                                      ? Colors.white
                                      : const Color(0xFF454D6E),
                                ),
                              ),
                            ),

                  // ── Tab 1: Pending requests ───────────
                  _loadingRequests
                      ? const Center(child: CircularProgressIndicator())
                      : _pendingRequests.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mail_outline_rounded,
                                      size: 56, color: Colors.grey[300]),
                                  const SizedBox(height: 12),
                                  Text('No pending requests',
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey[400],
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text('When someone adds you, it shows here.',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[400])),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadRequests,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                itemCount: _pendingRequests.length,
                                itemBuilder: (_, i) {
                                  final req = _pendingRequests[i];
                                  return _RequestTile(
                                    request:  req,
                                    onAccept: () =>
                                        _acceptRequest(req['fromUid']),
                                    onDecline: () =>
                                        _declineRequest(req['fromUid']),
                                    cardColor: isDark
                                        ? const Color(0xFF363A52)
                                        : Colors.white,
                                    txtColor: isDark
                                        ? Colors.white
                                        : const Color(0xFF454D6E),
                                  );
                                },
                              ),
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }
}

// ── Search result card ─────────────────────────────────────
class _SearchResultCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool alreadyFriend;
  final bool requestSent;
  final bool sendingRequest;
  final VoidCallback onSendRequest;
  final VoidCallback onCancelRequest;
  final Color cardColor;
  final Color txtColor;

  const _SearchResultCard({
    required this.user,
    required this.alreadyFriend,
    required this.requestSent,
    required this.sendingRequest,
    required this.onSendRequest,
    required this.onCancelRequest,
    required this.cardColor,
    required this.txtColor,
  });

  @override
  Widget build(BuildContext context) {
    final username    = user['username']    as String? ?? '';
    final displayName = user['displayName'] as String? ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF454D6E).withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          _Avatar(name: displayName, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: txtColor)),
                if (username.isNotEmpty)
                  Text('@$username',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          if (alreadyFriend)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded,
                      size: 14, color: Color(0xFF4CAF50)),
                  SizedBox(width: 4),
                  Text('Friends',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else if (requestSent)
            GestureDetector(
              onTap: onCancelRequest,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('Pending',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: sendingRequest ? null : onSendRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF454D6E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                elevation: 0,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: sendingRequest
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Add Friend',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ── Incoming request tile ──────────────────────────────────
class _RequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final Color cardColor;
  final Color txtColor;

  const _RequestTile({
    required this.request,
    required this.onAccept,
    required this.onDecline,
    required this.cardColor,
    required this.txtColor,
  });

  @override
  Widget build(BuildContext context) {
    final fromName     = request['fromName']     as String? ?? 'Unknown';
    final fromUsername = request['fromUsername'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          _Avatar(name: fromName, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fromName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: txtColor)),
                const SizedBox(height: 2),
                Text(
                  '${fromUsername.isNotEmpty ? '@$fromUsername  •  ' : ''}Wants to be friends',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Decline
              GestureDetector(
                onTap: onDecline,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded,
                      color: Colors.red.shade400, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              // Accept
              GestureDetector(
                onTap: onAccept,
                child: Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(
                      color: Color(0xFF454D6E),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
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
  final Color cardColor;
  final Color txtColor;

  const _FriendTile({
    required this.friend,
    required this.onRemove,
    required this.cardColor,
    required this.txtColor,
  });

  @override
  Widget build(BuildContext context) {
    final exp      = (friend['totalExp'] as int?) ?? 0;
    final level    = (exp ~/ 500) + 1;
    final username = friend['username'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
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
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: txtColor)),
                const SizedBox(height: 2),
                Text(
                  '${username.isNotEmpty ? '@$username  •  ' : ''}Level $level  •  $exp EXP',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.person_remove_outlined,
                color: Colors.red.shade300, size: 20),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove friend?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Remove ${friend['displayName']} from your friends list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onRemove();
            },
            child: Text('Remove',
                style: TextStyle(
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w700)),
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
      const Color(0xFF454D6E),
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFF9C27B0),
      const Color(0xFFFF6B35),
      const Color(0xFFFF9800),
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
        style: TextStyle(
            fontSize: size * 0.38,
            color: Colors.white,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}