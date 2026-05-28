import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';

/// *** Contributions in the file: Acier Jan Andres, Andrei Deseo ***

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid     = AuthService.currentUid!;
    final entries = await FriendsService.getLeaderboard(uid);
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  String _rankLabel(int level) {
    if (level >= 20) return '🔥 Legendary';
    if (level >= 15) return '🩵 Diamond';
    if (level >= 10) return '🟣 Platinum';
    if (level >= 7)  return '🟡 Gold';
    if (level >= 4)  return '⬜ Silver';
    return '🟫 Bronze';
  }

  Color _rankColor(int level) {
    if (level >= 20) return const Color(0xFFFF6B35);
    if (level >= 15) return const Color(0xFF00BCD4);
    if (level >= 10) return const Color(0xFF9C27B0);
    if (level >= 7)  return const Color(0xFFFFC107);
    if (level >= 4)  return const Color(0xFF9E9E9E);
    return const Color(0xFFCD7F32);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService.currentUid;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A2D3E) : const Color(0xFFF1EFEE);
    final txtColor = isDark ? Colors.white : const Color(0xFF454D6E);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Header ---------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Leaderboard',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: txtColor)),
                  const SizedBox(height: 4),
                  Text('You and your friends ranked by total EXP.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),

            // -- Top 3 podium ----------------------------
            if (!_loading && _entries.length >= 3)
              _Podium(entries: _entries.take(3).toList(), currentUid: currentUid, isDark: isDark),

            const SizedBox(height: 16),

            // -- Full ranked list -------------------------
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.leaderboard_outlined, size: 56, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No data yet', style: TextStyle(fontSize: 15, color: Colors.grey[400], fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Add friends to start competing!',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _entries.length,
                            itemBuilder: (_, i) {
                              final entry   = _entries[i];
                              final isMe    = entry['uid'] == currentUid;
                              final exp     = (entry['totalExp'] as int?) ?? 0;
                              final level   = (exp ~/ 500) + 1;
                              final rank    = i + 1;

                              return _LeaderboardTile(
                                rank: rank,
                                name: entry['displayName'] ?? 'Unknown',
                                exp: exp,
                                level: level,
                                rankLabel: _rankLabel(level),
                                rankColor: _rankColor(level),
                                isMe: isMe,
                                isDark: isDark,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Podium (top 3) -----------------------------------------
class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final String? currentUid;
  final bool isDark;
  const _Podium({required this.entries, required this.currentUid, required this.isDark});

  Color _colorFromName(String name) {
    final colors = [
      const Color(0xFF454D6E), const Color(0xFF2196F3), const Color(0xFF4CAF50),
      const Color(0xFF9C27B0), const Color(0xFFFF6B35), const Color(0xFFFF9800),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  Widget _podiumSlot(Map<String, dynamic> entry, int position, double height) {
    final name  = entry['displayName'] ?? 'Unknown';
    final exp   = (entry['totalExp'] as int?) ?? 0;
    final isMe  = entry['uid'] == currentUid;

    final medals = ['🥇', '🥈', '🥉'];
    final podiumColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final nameColor = isDark ? Colors.white : const Color(0xFF454D6E);
    final expColor  = isDark ? Colors.grey[400]! : Colors.grey[500]!;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isMe)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF454D6E), borderRadius: BorderRadius.circular(8)),
              child: const Text('You', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 4),
          CircleAvatar(
            radius: position == 0 ? 28 : 22,
            backgroundColor: _colorFromName(name),
            child: Text(name[0].toUpperCase(),
                style: TextStyle(
                    fontSize: position == 0 ? 22 : 16,
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Text(name.split(' ').first,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: nameColor),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('$exp EXP', style: TextStyle(fontSize: 11, color: expColor)),
          const SizedBox(height: 6),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: podiumColors[position].withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Center(
              child: Text(medals[position], style: const TextStyle(fontSize: 22)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Order: 2nd, 1st, 3rd for visual podium effect
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _podiumSlot(entries[1], 1, 80),
            const SizedBox(width: 8),
            _podiumSlot(entries[0], 0, 110),
            const SizedBox(width: 8),
            _podiumSlot(entries[2], 2, 60),
          ],
        ),
      ),
    );
  }
}

// -- Single leaderboard tile --------------------------------
class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final String name;
  final int exp;
  final int level;
  final String rankLabel;
  final Color rankColor;
  final bool isMe;
  final bool isDark;

  const _LeaderboardTile({
    required this.rank,
    required this.name,
    required this.exp,
    required this.level,
    required this.rankLabel,
    required this.rankColor,
    required this.isMe,
    required this.isDark,
  });

  Color _colorFromName(String n) {
    final colors = [
      const Color(0xFF454D6E), const Color(0xFF2196F3), const Color(0xFF4CAF50),
      const Color(0xFF9C27B0), const Color(0xFFFF6B35), const Color(0xFFFF9800),
    ];
    return colors[n.codeUnitAt(0) % colors.length];
  }

  String _medalFor(int rank) {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '$rank';
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = isMe
        ? const Color(0xFF454D6E)
        : (isDark ? const Color(0xFF363A52) : Colors.white);
    final nameColor = isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF454D6E));
    final subColor  = isMe ? Colors.white60 : Colors.grey[500]!;
    final rankNumColor = isMe ? Colors.white70 : Colors.grey[400]!;
    final expColor  = isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF454D6E));
    final expSubColor = isMe ? Colors.white60 : Colors.grey[400]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: isMe
                ? const Color(0xFF454D6E).withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Rank number / medal
          SizedBox(
            width: 36,
            child: Center(
              child: rank <= 3
                  ? Text(_medalFor(rank), style: const TextStyle(fontSize: 22))
                  : Text('#$rank',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: rankNumColor)),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: _colorFromName(name).withValues(alpha: isMe ? 0.5 : 1),
            child: Text(name[0].toUpperCase(),
                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          // Name + rank label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: nameColor)),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('You',
                            style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('$rankLabel  •  Lvl $level',
                    style: TextStyle(fontSize: 11, color: subColor)),
              ],
            ),
          ),
          // EXP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$exp',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: expColor)),
              Text('EXP',
                  style: TextStyle(fontSize: 10, color: expSubColor)),
            ],
          ),
        ],
      ),
    );
  }
}