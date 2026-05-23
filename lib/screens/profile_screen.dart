import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/friends_service.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int totalExp;
  final int weekNumber;

  const ProfileScreen({
    super.key,
    required this.totalExp,
    required this.weekNumber,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _friendCount = 0;
  bool _loadingFriends = true;
  Map<String, dynamic>? _userProfile;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthService.currentUid;
    if (uid == null) return;

    final results = await Future.wait([
      DatabaseService.getUserProfile(uid),
      FriendsService.getFriends(uid),
    ]);

    if (!mounted) return;
    setState(() {
      _userProfile    = results[0] as Map<String, dynamic>?;
      _friendCount    = (results[1] as List).length;
      _loadingProfile = false;
      _loadingFriends = false;
    });
  }

  // ── EXP helpers ─────────────────────────────────────────
  int get _level => (widget.totalExp ~/ 500) + 1;

  int _expForLevel(int level) => level * 500;

  int _totalExpForLevel(int level) {
    int total = 0;
    for (int i = 1; i < level; i++) total += _expForLevel(i);
    return total;
  }

  int get _expInLevel => widget.totalExp - _totalExpForLevel(_level);
  int get _expNeeded  => _expForLevel(_level);
  double get _expProgress => _expInLevel / _expNeeded;

  String get _rankLabel {
    if (_level >= 20) return 'Legendary';
    if (_level >= 15) return 'Diamond';
    if (_level >= 10) return 'Platinum';
    if (_level >= 7)  return 'Gold';
    if (_level >= 4)  return 'Silver';
    return 'Bronze';
  }

  Color get _rankColor {
    if (_level >= 20) return const Color(0xFFFF6B35);
    if (_level >= 15) return const Color(0xFF00BCD4);
    if (_level >= 10) return const Color(0xFF9C27B0);
    if (_level >= 7)  return const Color(0xFFFFC107);
    if (_level >= 4)  return const Color(0xFF9E9E9E);
    return const Color(0xFFCD7F32);
  }

  Color _colorFromName(String name) {
    final colors = [
      const Color(0xFF1A1A2E), const Color(0xFF2196F3), const Color(0xFF4CAF50),
      const Color(0xFF9C27B0), const Color(0xFFFF6B35), const Color(0xFFFF9800),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final name = user?.displayName ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [

              // ── Hero header ──────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1A1A2E), _rankColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                child: Column(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: _colorFromName(name).withOpacity(0.6),
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(user?.email ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.65))),
                    const SizedBox(height: 16),

                    // Rank badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: _rankColor.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _rankColor.withOpacity(0.5)),
                      ),
                      child: Text('⭐ $_rankLabel  •  Level $_level',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(height: 16),

                    // EXP progress bar
                    Row(
                      children: [
                        Text('$_expInLevel / $_expNeeded EXP',
                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
                        const Spacer(),
                        Text('Next: Level ${_level + 1}',
                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _expProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Stats row ────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _StatCard(label: 'Total EXP',   value: '${widget.totalExp}',   icon: Icons.bolt_rounded,         color: const Color(0xFFFFC107)),
                    const SizedBox(width: 12),
                    _StatCard(label: 'Current Week', value: '#${widget.weekNumber}', icon: Icons.calendar_today_rounded, color: const Color(0xFF2196F3)),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Friends',
                      value: _loadingFriends ? '—' : '$_friendCount',
                      icon: Icons.people_rounded,
                      color: const Color(0xFF4CAF50),
                    ),
                  ],
                ),
              ),

              // ── Account info ─────────────────────────────
              _Section(
                title: 'Account',
                children: [
                  _InfoTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Display Name',
                    value: name,
                  ),
                  _InfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user?.email ?? '—',
                  ),
                  _InfoTile(
                    icon: Icons.calendar_month_outlined,
                    label: 'Member Since',
                    value: _loadingProfile
                        ? '—'
                        : _formatDate(_userProfile?['createdAt']),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Progress info ────────────────────────────
              _Section(
                title: 'Progress',
                children: [
                  _InfoTile(
                    icon: Icons.military_tech_outlined,
                    label: 'Rank',
                    value: _rankLabel,
                    valueColor: _rankColor,
                  ),
                  _InfoTile(
                    icon: Icons.trending_up_rounded,
                    label: 'Level',
                    value: 'Level $_level',
                  ),
                  _InfoTile(
                    icon: Icons.star_outline_rounded,
                    label: 'Total EXP Earned',
                    value: '${widget.totalExp} EXP',
                  ),
                  _InfoTile(
                    icon: Icons.loop_rounded,
                    label: 'Weeks Completed',
                    value: '${widget.weekNumber - 1}',
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Actions ──────────────────────────────────
              _Section(
                title: 'Account Actions',
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20),
                    ),
                    title: Text('Sign Out',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.red.shade400)),
                    trailing: Icon(Icons.chevron_right_rounded, color: Colors.red.shade300),
                    onTap: _signOut,
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '—';
    try {
      final dt = (timestamp as dynamic).toDate() as DateTime;
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '—';
    }
  }
}

// ── Stat card ──────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Section wrapper ────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E), letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: List.generate(children.length, (i) {
                return Column(
                  children: [
                    children[i],
                    if (i < children.length - 1)
                      Divider(height: 1, indent: 56, color: Colors.grey[100]),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Info tile ──────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withOpacity(0.06),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: const Color(0xFF1A1A2E), size: 18),
      ),
      title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
      subtitle: Text(value,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF1A1A2E))),
    );
  }
}
