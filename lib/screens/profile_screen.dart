import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/friends_service.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int totalExp;
  final int weekNumber;
  // DEV ONLY — null in production builds
  final Future<void> Function()? onDevResetWeek;
  final void Function(int targetLevel)? onDevSetLevel;

  const ProfileScreen({
    super.key,
    required this.totalExp,
    required this.weekNumber,
    this.onDevResetWeek,
    this.onDevSetLevel,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _friendCount = 0;
  bool _loadingFriends = true;
  Map<String, dynamic>? _userProfile;
  bool _loadingProfile = true;

  // DEV: hidden 5-tap trigger on the version footer
  int _devTapCount = 0;

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
  int _expForLevel(int level) => level * 500;

  int _totalExpForLevel(int level) {
    int total = 0;
    for (int i = 1; i < level; i++) {
      total += _expForLevel(i);
    }
    return total;
  }

  int _levelFromExp(int exp) {
    int level = 1;
    while (exp >= _totalExpForLevel(level + 1)) {
      level++;
    }
    return level;
  }

  int get _level => _levelFromExp(widget.totalExp);
  int get _expInLevel => widget.totalExp - _totalExpForLevel(_level);
  int get _expNeeded  => _expForLevel(_level);
  double get _expProgress => _expNeeded > 0 ? _expInLevel / _expNeeded : 0.0;

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
      const Color(0xFF454D6E), const Color(0xFF2196F3), const Color(0xFF4CAF50),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A2D3E) : const Color(0xFFF1EFEE);
    final user = AuthService.currentUser;
    final name = user?.displayName ?? 'User';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [

              // ── Hero header ──────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF454D6E), const Color(0xFFAB6470).withValues(alpha: 0.85)],
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
                      backgroundColor: _colorFromName(name).withValues(alpha: 0.6),
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
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65))),
                    const SizedBox(height: 16),

                    // Rank badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: _rankColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _rankColor.withValues(alpha: 0.5)),
                      ),
                      child: Text('⭐ $_rankLabel  •  Level $_level',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(height: 16),

                    // EXP progress bar
                    Row(
                      children: [
                        Text('$_expInLevel / $_expNeeded EXP',
                            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                        const Spacer(),
                        Text('Next: Level ${_level + 1}',
                            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _expProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
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

              // ── Hidden dev footer (5-tap to unlock) ──────
              if (widget.onDevResetWeek != null)
                GestureDetector(
                  onTap: () {
                    _devTapCount++;
                    if (_devTapCount >= 5) {
                      _devTapCount = 0;
                      _showDevSheet();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Text(
                      'v1.0.0',
                      style: TextStyle(fontSize: 11, color: Colors.grey[300]),
                    ),
                  ),
                )
              else
                const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  void _showDevSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        bool resetting = false;
        int targetLevel = _level; // start at current level
        return StatefulBuilder(
          builder: (ctx, setLocal) => Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: const Color(0xFF454D6E),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: const Text('DEV',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.amber,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(width: 10),
                    const Text('Developer Tools',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Testing utilities — not visible in production.',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
                const SizedBox(height: 20),
                Divider(color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 16),

                // ── Set Level ────────────────────────────────
                if (widget.onDevSetLevel != null) ...[
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.military_tech_rounded,
                            color: Colors.purpleAccent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Set Level',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            Text('Current: Level $_level',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.45))),
                          ],
                        ),
                      ),
                      // Stepper
                      Row(
                        children: [
                          _DevStepBtn(
                            icon: Icons.remove_rounded,
                            onTap: () {
                              if (targetLevel > 1) setLocal(() => targetLevel--);
                            },
                          ),
                          Container(
                            width: 44,
                            alignment: Alignment.center,
                            child: Text(
                              '$targetLevel',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white),
                            ),
                          ),
                          _DevStepBtn(
                            icon: Icons.add_rounded,
                            onTap: () {
                              if (targetLevel < 30) setLocal(() => targetLevel++);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: targetLevel == _level
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              widget.onDevSetLevel!(targetLevel);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent.withValues(alpha: 0.25),
                        foregroundColor: Colors.purpleAccent,
                        disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                        disabledForegroundColor: Colors.white24,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        targetLevel == _level
                            ? 'Select a different level'
                            : 'Apply Level $targetLevel',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 16),
                ],

                // ── Reset Week ───────────────────────────────
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.restart_alt_rounded,
                        color: Colors.orange, size: 22),
                  ),
                  title: const Text('Reset Current Week',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  subtitle: Text('Runs the full week-end flow now',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45))),
                  trailing: resetting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.orange))
                      : const Icon(Icons.chevron_right_rounded,
                          color: Colors.white38),
                  onTap: resetting
                      ? null
                      : () async {
                          setLocal(() => resetting = true);
                          Navigator.pop(ctx);
                          await widget.onDevResetWeek!();
                        },
                ),
              ],
            ),
          ),
        );
      },
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

// ── Dev stepper button ─────────────────────────────────────
class _DevStepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DevStepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
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
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF363A52) : Colors.white;
    final txtColor  = isDark ? Colors.white : const Color(0xFF454D6E);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: txtColor)),
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
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final cardColor  = isDark ? const Color(0xFF363A52) : Colors.white;
    final titleColor = isDark ? Colors.white70 : const Color(0xFF454D6E);
    final divColor   = isDark ? Colors.white12 : Colors.grey[100]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: titleColor, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: List.generate(children.length, (i) {
                return Column(
                  children: [
                    children[i],
                    if (i < children.length - 1)
                      Divider(height: 1, indent: 56, color: divColor),
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
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final txtColor = isDark ? Colors.white : const Color(0xFF454D6E);
    final iconBg   = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFF454D6E).withValues(alpha: 0.06);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF454D6E);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
      subtitle: Text(value,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? txtColor)),
    );
  }
}