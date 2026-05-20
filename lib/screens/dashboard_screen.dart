import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/user_profile.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

// ─── EXP / Level system ───────────────────────────────────
// EXP rates (per day circle):
//   Done    = +3 EXP
//   Missed  = -1 EXP
//   Neutral =  0 EXP
//
// Perfect week: 3 categories x 4 tasks x 7 days = 84 done = +252 EXP
//
// Level thresholds scale up each level (gets harder):
//   Level 1 → 2 :   500 EXP  (~2 perfect weeks)
//   Level 2 → 3 : 1,000 EXP  (~4 perfect weeks)
//   Level N → N+1: N * 500 EXP
//
// So reaching Level 5 requires 500+1000+1500+2000 = 5,000 EXP (~20 perfect weeks)
const int _expPerDone   =  3;
const int _expPerMissed = -1;

// EXP required to go from level N to N+1
int _expForLevel(int level) => level * 500;

// Total EXP needed to reach a given level from 0
int _totalExpForLevel(int level) {
  int total = 0;
  for (int i = 1; i < level; i++) total += _expForLevel(i);
  return total;
}

// Derive current level from total accumulated EXP
int _levelFromExp(int totalExp) {
  int level = 1;
  while (totalExp >= _totalExpForLevel(level + 1)) level++;
  return level;
}

// EXP accumulated within the current level
int _expIntoLevel(int totalExp) {
  final level = _levelFromExp(totalExp);
  return totalExp - _totalExpForLevel(level);
}

// EXP required to complete the current level
int _expNeededForCurrentLevel(int totalExp) {
  final level = _levelFromExp(totalExp);
  return _expForLevel(level);
}

int _computeWeeklyExp(List<AIRecommendation> recs) {
  int exp = 0;
  for (final rec in recs) {
    for (final todo in rec.todos) {
      for (final day in todo.days) {
        if (day == DayState.done)   exp += _expPerDone;
        if (day == DayState.missed) exp += _expPerMissed;
      }
    }
  }
  return exp.clamp(0, 99999);
}

String _rankLabel(int level) {
  if (level >= 20) return 'Legendary';
  if (level >= 15) return 'Diamond';
  if (level >= 10) return 'Platinum';
  if (level >= 7)  return 'Gold';
  if (level >= 4)  return 'Silver';
  return 'Bronze';
}

Color _rankColor(int level) {
  if (level >= 20) return const Color(0xFFFF6B35);
  if (level >= 15) return const Color(0xFF00BCD4);
  if (level >= 10) return const Color(0xFF9C27B0);
  if (level >= 7)  return const Color(0xFFFFC107);
  if (level >= 4)  return const Color(0xFF9E9E9E);
  return const Color(0xFFCD7F32);
}

// ─────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  final UserProfile userProfile;
  final int savedTotalExp;
  final int savedWeekNumber;
  final List<AIRecommendation>? savedRecommendations;

  const DashboardScreen({
    super.key,
    required this.userProfile,
    this.savedTotalExp = 0,
    this.savedWeekNumber = 1,
    this.savedRecommendations,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  List<AIRecommendation>? _recommendations;
  bool _isLoading = true;
  String? _error;
  String _loadingStatus = 'Generating your plan...';

  // EXP state — persists across weekly resets
  late int _totalExp;
  late int _weekNumber;

  // Level-up animation
  late AnimationController _levelUpCtrl;
  late Animation<double> _levelUpAnim;
  bool _showLevelUp = false;
  int _levelUpTo = 1;

  // EXP gain animation
  late AnimationController _expBurstCtrl;
  late Animation<double> _expBurstAnim;
  int _lastGained = 0;

  @override
  void initState() {
    super.initState();
    _levelUpCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _levelUpAnim = CurvedAnimation(parent: _levelUpCtrl, curve: Curves.elasticOut);

    _expBurstCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _expBurstAnim = CurvedAnimation(parent: _expBurstCtrl, curve: Curves.easeOut);

    _totalExp    = widget.savedTotalExp;
    _weekNumber  = widget.savedWeekNumber;

    if (widget.savedRecommendations != null) {
      // Returning user — restore saved week data, skip AI call
      _recommendations = widget.savedRecommendations;
      _isLoading = false;
    } else {
      _fetchRecommendations();
    }
  }

  @override
  void dispose() {
    _levelUpCtrl.dispose();
    _expBurstCtrl.dispose();
    super.dispose();
  }

  @override
  void dispose() {
    _levelUpCtrl.dispose();
    _expBurstCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRecommendations() async {
    setState(() { _isLoading = true; _error = null; _loadingStatus = 'Generating your plan...'; });
    try {
      _startLoadingStatusCycle();
      final recs = await AIService.getRecommendations(widget.userProfile);
      setState(() { _recommendations = recs; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _startLoadingStatusCycle() {
    final messages = [
      'Generating your plan...',
      'Analysing your activity level...',
      'Calculating your nutrition needs...',
      'Building your exercise routine...',
      'Optimising your sleep schedule...',
      'Almost ready...',
    ];
    int i = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!_isLoading) return false;
      i = (i + 1) % messages.length;
      if (mounted) setState(() => _loadingStatus = messages[i]);
      return _isLoading;
    });
  }

  void _toggleDay(int recIndex, int todoIndex, int dayIndex, DayState current) {
    final next = switch (current) {
      DayState.neutral => DayState.done,
      DayState.done    => DayState.missed,
      DayState.missed  => DayState.neutral,
    };
    setState(() {
      final rec = _recommendations![recIndex];
      final newTodo = rec.todos[todoIndex].copyWithDay(dayIndex, next);
      final newTodos = List<TodoItem>.from(rec.todos);
      newTodos[todoIndex] = newTodo;
      _recommendations![recIndex] = AIRecommendation(
        category: rec.category,
        title: rec.title,
        summary: rec.summary,
        todos: newTodos,
      );
    });
    _autoSaveWeek();
  }

  Future<void> _autoSaveWeek() async {
    final uid = AuthService.currentUid;
    if (uid == null || _recommendations == null) return;
    await DatabaseService.saveWeekData(
      uid: uid,
      weekNumber: _weekNumber,
      recommendations: _recommendations!,
      expEarned: _computeWeeklyExp(_recommendations!),
    );
  }

  void _resetWeek() {
    if (_recommendations == null) return;

    final prevLevel = _levelFromExp(_totalExp);
    final gained    = _computeWeeklyExp(_recommendations!);

    setState(() {
      _lastGained = gained;
      _totalExp  += gained;
      _weekNumber++;

      // Reset all day states to neutral
      _recommendations = _recommendations!.map((rec) {
        return AIRecommendation(
          category: rec.category,
          title: rec.title,
          summary: rec.summary,
          todos: rec.todos.map((todo) =>
            TodoItem(task: todo.task, detail: todo.detail)
          ).toList(),
        );
      }).toList();
    });

    // Persist to Firestore
    final uid = AuthService.currentUid;
    if (uid != null) {
      DatabaseService.updateExpAndWeek(uid: uid, totalExp: _totalExp, weekNumber: _weekNumber);
      DatabaseService.saveWeekData(
        uid: uid,
        weekNumber: _weekNumber,
        recommendations: _recommendations!,
        expEarned: 0, // fresh week
      );
    }

    // Burst animation for EXP gained
    _expBurstCtrl.forward(from: 0);

    // Level-up animation if level changed
    final newLevel = _levelFromExp(_totalExp);
    if (newLevel > prevLevel) {
      setState(() { _showLevelUp = true; _levelUpTo = newLevel; });
      _levelUpCtrl.forward(from: 0).then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showLevelUp = false);
        });
      });
    }
  }

  Map<String, dynamic> _categoryConfig(String category) {
    switch (category) {
      case 'nutrition':
        return {'icon': Icons.restaurant_menu_rounded, 'color': const Color(0xFFE8F4F8), 'iconColor': const Color(0xFF2196F3), 'accentColor': const Color(0xFF2196F3)};
      case 'exercise':
        return {'icon': Icons.fitness_center_rounded, 'color': const Color(0xFFF0F8E8), 'iconColor': const Color(0xFF4CAF50), 'accentColor': const Color(0xFF4CAF50)};
      case 'sleep':
      default:
        return {'icon': Icons.bedtime_rounded, 'color': const Color(0xFFF3EEF8), 'iconColor': const Color(0xFF9C27B0), 'accentColor': const Color(0xFF9C27B0)};
    }
  }

  Widget _buildRecommendationsList() {
    if (_isLoading) {
      return Column(children: List.generate(3, (_) => const _SkeletonCard()));
    }
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.red.shade300, size: 36),
            const SizedBox(height: 12),
            Text('Could not load recommendations.\nPlease check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 14)),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _fetchRecommendations,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF1A1A2E)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(_recommendations!.length, (recIndex) {
        final rec = _recommendations![recIndex];
        final config = _categoryConfig(rec.category);
        return _RecommendationSection(
          rec: rec,
          recIndex: recIndex,
          icon: config['icon'] as IconData,
          bgColor: config['color'] as Color,
          iconColor: config['iconColor'] as Color,
          accentColor: config['accentColor'] as Color,
          onToggleDay: _toggleDay,
        );
      }),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final user = AuthService.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            CircleAvatar(radius: 28, backgroundColor: const Color(0xFF1A1A2E),
                child: Text(
                  (user?.displayName ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700),
                )),
            const SizedBox(height: 12),
            Text(user?.displayName ?? 'User',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            Text(user?.email ?? '',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 24),
            Divider(color: Colors.grey[100]),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20)),
              title: Text('Sign Out',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.red.shade400)),
              onTap: () async {
                Navigator.pop(context);
                await AuthService.signOut();
                // AuthGate StreamBuilder handles navigation back to WelcomeScreen
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = _levelFromExp(_totalExp);
    final expInLevel   = _expIntoLevel(_totalExp);
    final expProgress  = expInLevel / _expNeededForCurrentLevel(_totalExp);
    final rank         = _rankLabel(currentLevel);
    final rankColor    = _rankColor(currentLevel);

    // Live preview of what this week will earn (before reset)
    final previewExp = _recommendations != null ? _computeWeeklyExp(_recommendations!) : 0;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          body: SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Evexia',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E), letterSpacing: 0.5)),
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[200]),
                        child: const Icon(Icons.person_outline, color: Color(0xFF1A1A2E), size: 20),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // ── EXP / Level Card ─────────────────
                        _ExpCard(
                          level: currentLevel,
                          expInLevel: expInLevel,
                          expProgress: expProgress,
                          rank: rank,
                          rankColor: rankColor,
                          totalExp: _totalExp,
                          weekNumber: _weekNumber,
                          previewExp: previewExp,
                          expBurstAnim: _expBurstAnim,
                          lastGained: _lastGained,
                        ),

                        const SizedBox(height: 20),

                        // ── Survey chips ─────────────────────
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _SurveyChip(label: widget.userProfile.activityLevel, icon: Icons.directions_run_rounded),
                            _SurveyChip(label: widget.userProfile.sleepHours, icon: Icons.bedtime_rounded),
                            ...widget.userProfile.primaryGoals.map(
                                (g) => _SurveyChip(label: g, icon: Icons.track_changes_rounded)),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Recommendations header + reset ───
                        Row(
                          children: [
                            const Text('Your Weekly Plan',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                            const Spacer(),
                            if (_isLoading)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A2E).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 10, height: 10,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5, color: const Color(0xFF1A1A2E).withOpacity(0.6)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(_loadingStatus,
                                        style: TextStyle(fontSize: 11,
                                            color: const Color(0xFF1A1A2E).withOpacity(0.6), fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            if (!_isLoading && _error == null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, size: 11, color: Color(0xFF4CAF50)),
                                    SizedBox(width: 4),
                                    Text('AI powered',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 6),
                        Text('Tap a day circle to mark it done.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        const SizedBox(height: 14),

                        _buildRecommendationsList(),

                        // ── Reset week button ────────────────
                        if (!_isLoading && _error == null) ...[
                          const SizedBox(height: 8),
                          _ResetWeekButton(
                            previewExp: previewExp,
                            weekNumber: _weekNumber,
                            onReset: _resetWeek,
                          ),
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // ── Bottom Nav ───────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _NavItem(icon: Icons.home_rounded, label: 'Home', selected: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
                          _NavItem(icon: Icons.bar_chart_rounded, label: 'Goals', selected: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
                          _NavItem(icon: Icons.grid_view_rounded, label: 'BMI', selected: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2)),
                          _NavItem(icon: Icons.person_rounded, label: 'Profile', selected: _selectedIndex == 3, onTap: () => setState(() => _selectedIndex = 3)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Level-up overlay ─────────────────────────
        if (_showLevelUp)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showLevelUp = false),
              child: Container(
                color: Colors.black.withOpacity(0.55),
                child: Center(
                  child: ScaleTransition(
                    scale: _levelUpAnim,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🎉', style: const TextStyle(fontSize: 56)),
                          const SizedBox(height: 12),
                          const Text('LEVEL UP!',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                                  color: Color(0xFF1A1A2E), letterSpacing: 2)),
                          const SizedBox(height: 8),
                          Text('You reached Level $_levelUpTo',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: _rankColor(_levelUpTo).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_rankLabel(_levelUpTo)} Rank',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: _rankColor(_levelUpTo)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Tap anywhere to continue',
                              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// EXP / Level card
// ─────────────────────────────────────────────────────────
class _ExpCard extends StatelessWidget {
  final int level;
  final int expInLevel;
  final double expProgress;
  final String rank;
  final Color rankColor;
  final int totalExp;
  final int weekNumber;
  final int previewExp;
  final Animation<double> expBurstAnim;
  final int lastGained;

  const _ExpCard({
    required this.level,
    required this.expInLevel,
    required this.expProgress,
    required this.rank,
    required this.rankColor,
    required this.totalExp,
    required this.weekNumber,
    required this.previewExp,
    required this.expBurstAnim,
    required this.lastGained,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A2E), rankColor.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: rankColor.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: level badge + rank + week
          Row(
            children: [
              // Level badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text('LVL',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.7), letterSpacing: 1.5)),
                    Text('$level',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rank badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: rankColor.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: rankColor.withOpacity(0.5), width: 1),
                      ),
                      child: Text('⭐ $rank',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(height: 6),
                    Text('$totalExp total EXP',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500)),
                    Text('Week $weekNumber',
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
                  ],
                ),
              ),
              // Animated EXP gained burst
              AnimatedBuilder(
                animation: expBurstAnim,
                builder: (_, __) {
                  if (lastGained == 0) return const SizedBox.shrink();
                  return Opacity(
                    opacity: (1.0 - expBurstAnim.value).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -30 * expBurstAnim.value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('+$lastGained EXP',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 18),

          // EXP progress bar
          Row(
            children: [
              Text('$expInLevel',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_expNeededForCurrentLevel(totalExp)} EXP to next level',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: expProgress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(rankColor == const Color(0xFFCD7F32)
                  ? Colors.amber.shade300
                  : Colors.white),
            ),
          ),

          // This week preview
          if (previewExp > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: Colors.amber.shade300),
                const SizedBox(width: 4),
                Text('This week: +$previewExp EXP pending — press Reset Week to claim',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Reset Week button
// ─────────────────────────────────────────────────────────
class _ResetWeekButton extends StatelessWidget {
  final int previewExp;
  final int weekNumber;
  final VoidCallback onReset;

  const _ResetWeekButton({
    required this.previewExp,
    required this.weekNumber,
    required this.onReset,
  });

  void _confirmReset(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Text('🔄', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 12),
            const Text('End Week & Claim EXP?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Text(
              previewExp > 0
                  ? 'You\'ll earn $previewExp EXP for this week\'s effort.\nAll task trackers will reset for Week ${weekNumber + 1}.'
                  : 'No tasks were completed this week.\nAll task trackers will reset for Week ${weekNumber + 1}.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            if (previewExp > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFF4CAF50), size: 18),
                    const SizedBox(width: 6),
                    Text('+$previewExp EXP',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF4CAF50))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onReset();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A2E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('Claim & Reset', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => _confirmReset(context),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: Text(
          previewExp > 0 ? 'Reset Week  (+$previewExp EXP)' : 'Reset Week',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Recommendation Section
// ─────────────────────────────────────────────────────────
class _RecommendationSection extends StatefulWidget {
  final AIRecommendation rec;
  final int recIndex;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final Color accentColor;
  final void Function(int recIndex, int todoIndex, int dayIndex, DayState current) onToggleDay;

  const _RecommendationSection({
    required this.rec,
    required this.recIndex,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.accentColor,
    required this.onToggleDay,
  });

  @override
  State<_RecommendationSection> createState() => _RecommendationSectionState();
}

class _RecommendationSectionState extends State<_RecommendationSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final doneCount = widget.rec.todos
        .expand((t) => t.days)
        .where((d) => d == DayState.done)
        .length;
    final totalCount = widget.rec.todos.length * 7;
    final progress = totalCount > 0 ? doneCount / totalCount : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: widget.bgColor, borderRadius: BorderRadius.circular(12)),
                        child: Icon(widget.icon, color: widget.iconColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.rec.title,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                            const SizedBox(height: 2),
                            Text(widget.rec.summary,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.3)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress, minHeight: 6,
                            backgroundColor: Colors.grey[100],
                            valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('$doneCount/$totalCount',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.accentColor)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                Divider(height: 1, color: Colors.grey[100]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      ...List.generate(7, (i) => SizedBox(
                        width: 30,
                        child: Center(child: Text(_dayLabels[i],
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[400]))),
                      )),
                    ],
                  ),
                ),
                ...List.generate(widget.rec.todos.length, (todoIndex) {
                  final todo = widget.rec.todos[todoIndex];
                  return _TodoRow(
                    todo: todo,
                    accentColor: widget.accentColor,
                    isLast: todoIndex == widget.rec.todos.length - 1,
                    onToggleDay: (dayIndex, current) =>
                        widget.onToggleDay(widget.recIndex, todoIndex, dayIndex, current),
                  );
                }),
                const SizedBox(height: 4),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Todo row
// ─────────────────────────────────────────────────────────
class _TodoRow extends StatelessWidget {
  final TodoItem todo;
  final Color accentColor;
  final bool isLast;
  final void Function(int dayIndex, DayState current) onToggleDay;

  const _TodoRow({
    required this.todo,
    required this.accentColor,
    required this.isLast,
    required this.onToggleDay,
  });

  @override
  Widget build(BuildContext context) {
    final doneThisWeek   = todo.days.where((d) => d == DayState.done).length;
    final missedThisWeek = todo.days.where((d) => d == DayState.missed).length;

    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(todo.task,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E), height: 1.3)),
                if (todo.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(todo.detail, style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.3)),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: doneThisWeek > 0 ? accentColor.withOpacity(0.1) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('✓ $doneThisWeek',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                              color: doneThisWeek > 0 ? accentColor : Colors.grey[400])),
                    ),
                    if (missedThisWeek > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('✗ $missedThisWeek',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                color: Colors.red.shade400)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: List.generate(7, (dayIndex) {
              final state = todo.days[dayIndex];
              final Color bgColor;
              final Color borderColor;
              final Widget? icon;

              switch (state) {
                case DayState.done:
                  bgColor = accentColor;
                  borderColor = accentColor;
                  icon = const Icon(Icons.check_rounded, size: 13, color: Colors.white);
                case DayState.missed:
                  bgColor = Colors.red.shade400;
                  borderColor = Colors.red.shade400;
                  icon = const Icon(Icons.close_rounded, size: 13, color: Colors.white);
                case DayState.neutral:
                  bgColor = Colors.grey.shade100;
                  borderColor = Colors.grey.shade300;
                  icon = null;
              }

              return GestureDetector(
                onTap: () => onToggleDay(dayIndex, state),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 28, height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bgColor,
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Center(child: icon),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Skeleton loader
// ─────────────────────────────────────────────────────────
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Widget _bar(double width, double height) => Container(
    height: height, width: width,
    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _bar(140, 14), const SizedBox(height: 6), _bar(200, 11),
                ])),
              ]),
              const SizedBox(height: 14),
              ...List.generate(3, (_) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _bar(160, 12), const SizedBox(height: 4), _bar(100, 10),
                  ])),
                  const SizedBox(width: 8),
                  Row(children: List.generate(7, (_) => Container(
                    width: 28, height: 28, margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[200]),
                  ))),
                ]),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Survey chip
// ─────────────────────────────────────────────────────────
class _SurveyChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SurveyChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF1A1A2E)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Bottom nav item
// ─────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: selected ? const Color(0xFF1A1A2E) : Colors.grey[400], size: 24),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? const Color(0xFF1A1A2E) : Colors.grey[400])),
        ],
      ),
    );
  }
}
