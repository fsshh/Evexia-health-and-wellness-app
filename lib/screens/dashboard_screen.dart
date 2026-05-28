import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'friends_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'welcome_screen.dart';
import '../providers/theme_notifier.dart';

const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

int _todayIndex() => DateTime.now().weekday - 1; // 0=Mon … 6=Sun

// *** Contributions in the following functions: Raign Vincent Rueda, Dexter Logdonio, Acier Jan Andres ***
// --------------------- EXP / Level system ------------------------------
const int _expPerDone   =  3;
const int _expPerMissed = -1;

int _expForLevel(int level) => level * 500;

int _totalExpForLevel(int level) {
  int total = 0;
  for (int i = 1; i < level; i++) {
    total += _expForLevel(i);
  }
  return total;
}

int _levelFromExp(int totalExp) {
  int level = 1;
  while (totalExp >= _totalExpForLevel(level + 1)) {
    level++;
  }
  return level;
}

int _expIntoLevel(int totalExp) {
  final level = _levelFromExp(totalExp);
  return totalExp - _totalExpForLevel(level);
}

int _expNeededForCurrentLevel(int totalExp) {
  final level = _levelFromExp(totalExp);
  return _expForLevel(level);
}

int _computeDayExp(List<AIRecommendation> recs, int dayIndex) {
  int exp = 0;
  for (final rec in recs) {
    for (final todo in rec.todos) {
      final state = todo.days[dayIndex];
      if (state == DayState.done)   exp += _expPerDone;
      if (state == DayState.missed) exp += _expPerMissed;
    }
  }
  return exp.clamp(0, 99999);
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

/// Computes a commendation string based on weekly performance.
String _buildCommendation(int doneTasks, int totalTasks) {
  if (totalTasks == 0) return 'Keep going — every step counts!';
  final pct = doneTasks / totalTasks;
  if (pct == 1.0)  return 'Perfect week! Absolutely flawless — you crushed every single task! 🔥';
  if (pct >= 0.85) return 'Outstanding effort! You were so close to perfect. Keep that momentum!';
  if (pct >= 0.70) return 'Great week! You nailed the majority of your tasks. Consistency is key!';
  if (pct >= 0.50) return "Good effort! You're over halfway there. Push a little harder next week!";
  if (pct >= 0.30) return "You've made a start! Every habit takes time — don't give up.";
  return "Tough week? That's okay. Tomorrow is a fresh start. You've got this! 💪";
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

// --------------------- EXP / Level system End ------------------------------


class DashboardScreen extends StatefulWidget {
  final UserProfile userProfile;
  final int savedTotalExp;
  final int savedWeekNumber;
  final List<AIRecommendation>? savedRecommendations;
  final DateTime? savedWeekStart;
  final Set<int> savedClaimedDays;

  const DashboardScreen({
    super.key,
    required this.userProfile,
    this.savedTotalExp = 0,
    this.savedWeekNumber = 1,
    this.savedRecommendations,
    this.savedWeekStart,
    Set<int>? savedClaimedDays,
  }) : savedClaimedDays = savedClaimedDays ?? const {};

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

  late int _totalExp;
  late int _weekNumber;
  late DateTime _weekStart;

  // Which days have been claimed (0=Mon … 6=Sun)
  late final Set<int> _claimedDays;

  // Level-up animation
  late AnimationController _levelUpCtrl;
  late Animation<double> _levelUpAnim;
  bool _showLevelUp = false;
  int _levelUpTo = 1;
  bool _levelUpRefreshing = false; // true while new AI plan loads after level-up

  // EXP gain animation
  late AnimationController _expBurstCtrl;
  late Animation<double> _expBurstAnim;
  int _lastGained = 0;

  // New-week announcement animation
  late AnimationController _newWeekCtrl;
  late Animation<double> _newWeekAnim;
  bool _showNewWeek = false;
  bool _newWeekIsLevelUp = false; // true when banner is triggered by level-up refresh

  @override
  void initState() {
    super.initState();
    _levelUpCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _levelUpAnim =
        CurvedAnimation(parent: _levelUpCtrl, curve: Curves.elasticOut);

    _expBurstCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _expBurstAnim =
        CurvedAnimation(parent: _expBurstCtrl, curve: Curves.easeOut);

    _newWeekCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _newWeekAnim =
        CurvedAnimation(parent: _newWeekCtrl, curve: Curves.elasticOut);

    _totalExp   = widget.savedTotalExp;
    _weekNumber = widget.savedWeekNumber;
    _weekStart  = widget.savedWeekStart ?? _currentMonday();
    _claimedDays = Set<int>.from(widget.savedClaimedDays);

    if (widget.savedRecommendations != null) {
      _recommendations = widget.savedRecommendations;
      _isLoading = false;
      // Check if we need to auto-reset
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutoReset());
    } else {
      _fetchRecommendations();
    }
  }

  @override
  void dispose() {
    _levelUpCtrl.dispose();
    _expBurstCtrl.dispose();
    _newWeekCtrl.dispose();
    super.dispose();
  }

  DateTime _currentMonday() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  /// Auto-resets the week if the current Monday is past _weekStart.
  Future<void> _checkAutoReset() async {
    final monday = _currentMonday();
    final weekStartDate = DateTime(
        _weekStart.year, _weekStart.month, _weekStart.day);
    final mondayDate = DateTime(monday.year, monday.month, monday.day);

    if (mondayDate.isAfter(weekStartDate) && _recommendations != null) {
      await _finalizeWeek(auto: true);
    }
  }

  /// Claim EXP for today only.
  void _claimDay() {
    final today = _todayIndex();
    if (_claimedDays.contains(today)) return;
    if (_recommendations == null) return;

    final prevLevel = _levelFromExp(_totalExp);
    final gained    = _computeDayExp(_recommendations!, today);

    setState(() {
      _claimedDays.add(today);
      _lastGained = gained;
      _totalExp  += gained;
    });

    _autoSaveWeek();
    _expBurstCtrl.forward(from: 0);

    final uid = AuthService.currentUid;
    if (uid != null) {
      DatabaseService.updateExpAndWeek(
          uid: uid, totalExp: _totalExp, weekNumber: _weekNumber);
    }

    // Level-up check
    final newLevel = _levelFromExp(_totalExp);
    if (newLevel > prevLevel) {
      setState(() { _showLevelUp = true; _levelUpTo = newLevel; });
      _levelUpCtrl.forward(from: 0).then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _showLevelUp = false);
            // Trigger fresh AI recommendations for the new level
            _fetchRecommendationsForLevel(newLevel);
          }
        });
      });
    }
  }

  /// Finalize week: save report, reset tasks, bump week number, show animations.
  /// devMode makes the summary modal dismissible (for dev tool testing).
  Future<void> _finalizeWeek({bool auto = false, bool devMode = false}) async {
    if (_recommendations == null) return;

    final uid        = AuthService.currentUid;
    final now        = DateTime.now();
    final weekEnd    = now.subtract(const Duration(days: 1));
    final totalTasks = _recommendations!.fold<int>(
        0, (s, r) => s + r.todos.length * 7);
    final doneTasks  = _recommendations!.fold<int>(
        0,
        (s, r) => s +
            r.todos.fold<int>(
                0,
                (ts, t) =>
                    ts + t.days.where((d) => d == DayState.done).length));
    final missedTasks = _recommendations!.fold<int>(
        0,
        (s, r) => s +
            r.todos.fold<int>(
                0,
                (ts, t) =>
                    ts + t.days.where((d) => d == DayState.missed).length));
    final expEarned   = _computeWeeklyExp(_recommendations!);
    final commendation = _buildCommendation(doneTasks, totalTasks);

    // Save report to Firestore
    if (uid != null) {
      await DatabaseService.saveWeekReport(
        uid:          uid,
        weekNumber:   _weekNumber,
        totalTasks:   totalTasks,
        doneTasks:    doneTasks,
        missedTasks:  missedTasks,
        expEarned:    expEarned,
        commendation: commendation,
        weekStart:    _weekStart,
        weekEnd:      weekEnd,
      );
    }

    // Show the week report modal BEFORE resetting.
    // Returns false if dismissed via drag/tap-outside (dev mode only) — abort reset.
    if (mounted) {
      final confirmed = await _showWeekReportModal(
        weekNumber:   _weekNumber,
        totalTasks:   totalTasks,
        doneTasks:    doneTasks,
        missedTasks:  missedTasks,
        expEarned:    expEarned,
        commendation: commendation,
        devMode:      devMode,
      );
      if (!confirmed) return;
    }

    // Reset state
    setState(() {
      _weekNumber++;
      _weekStart  = _currentMonday();
      _claimedDays.clear();

      _recommendations = _recommendations!.map((rec) {
        return AIRecommendation(
          category: rec.category,
          title:    rec.title,
          summary:  rec.summary,
          todos: rec.todos
              .map((todo) => TodoItem(task: todo.task, detail: todo.detail))
              .toList(),
        );
      }).toList();
    });

    // Persist
    if (uid != null) {
      await DatabaseService.updateExpAndWeek(
          uid: uid, totalExp: _totalExp, weekNumber: _weekNumber);
      await DatabaseService.saveWeekData(
        uid:             uid,
        weekNumber:      _weekNumber,
        recommendations: _recommendations!,
        expEarned:       0,
        weekStart:       _weekStart,
        claimedDays:     {},
      );
    }

    // "New tasks for this week!" banner
    if (mounted) {
      setState(() { _showNewWeek = true; _newWeekIsLevelUp = false; });
      _newWeekCtrl.forward(from: 0);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _newWeekCtrl.reverse().then((_) {
            if (mounted) setState(() => _showNewWeek = false);
          });
        }
      });
    }
  }

  Future<bool> _showWeekReportModal({
    required int weekNumber,
    required int totalTasks,
    required int doneTasks,
    required int missedTasks,
    required int expEarned,
    required String commendation,
    bool devMode = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: devMode,
      enableDrag: devMode,
      builder: (_) => _WeekReportModal(
        weekNumber:   weekNumber,
        totalTasks:   totalTasks,
        doneTasks:    doneTasks,
        missedTasks:  missedTasks,
        expEarned:    expEarned,
        commendation: commendation,
      ),
    );
    return result == true;
  }

  Future<void> _fetchRecommendations() async {
    setState(() {
      _isLoading = true;
      _error     = null;
      _loadingStatus = 'Generating your plan...';
    });
    try {
      _startLoadingStatusCycle();
      final recs = await AIService.getRecommendations(widget.userProfile);
      if (!mounted) return;
      setState(() { _recommendations = recs; _isLoading = false; });
      _autoSaveWeek();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  /// Called after a level-up — fetches a fresh plan tuned to the new level,
  /// preserving existing day-state marks (only replaces tasks & summaries).
  Future<void> _fetchRecommendationsForLevel(int newLevel) async {
    setState(() {
      _levelUpRefreshing = true;
      _loadingStatus = 'Unlocking Level $newLevel tasks...';
    });
    try {
      final recs = await AIService.getRecommendations(
          widget.userProfile, level: newLevel);
      if (!mounted) return;

      // Preserve day-state marks from the existing week where possible
      List<AIRecommendation> merged = recs;
      if (_recommendations != null && _recommendations!.length == recs.length) {
        merged = List.generate(recs.length, (ri) {
          final newRec = recs[ri];
          final oldRec = _recommendations![ri];
          final mergedTodos = List.generate(newRec.todos.length, (ti) {
            final newTodo = newRec.todos[ti];
            // Keep day marks if the same todo index exists in old rec
            final oldDays = ti < oldRec.todos.length
                ? oldRec.todos[ti].days
                : null;
            return TodoItem(
              task:   newTodo.task,
              detail: newTodo.detail,
              days:   oldDays ?? newTodo.days,
            );
          });
          return AIRecommendation(
            category: newRec.category,
            title:    newRec.title,
            summary:  newRec.summary,
            todos:    mergedTodos,
          );
        });
      }

      setState(() {
        _recommendations    = merged;
        _levelUpRefreshing  = false;
      });
      _autoSaveWeek();

      // Show "new plan unlocked" banner
      if (mounted) {
        setState(() { _showNewWeek = true; _newWeekIsLevelUp = true; });
        _newWeekCtrl.forward(from: 0);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _newWeekCtrl.reverse().then((_) {
              if (mounted) setState(() { _showNewWeek = false; _newWeekIsLevelUp = false; });
            });
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _levelUpRefreshing = false);
      // Silently fail — the old plan stays intact
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

  void _toggleDay(
      int recIndex, int todoIndex, int dayIndex, DayState current) {
    final next = switch (current) {
      DayState.neutral => DayState.done,
      DayState.done    => DayState.missed,
      DayState.missed  => DayState.neutral,
    };
    setState(() {
      final rec     = _recommendations![recIndex];
      final newTodo = rec.todos[todoIndex].copyWithDay(dayIndex, next);
      final newTodos = List<TodoItem>.from(rec.todos);
      newTodos[todoIndex] = newTodo;
      _recommendations![recIndex] = AIRecommendation(
        category: rec.category,
        title:    rec.title,
        summary:  rec.summary,
        todos:    newTodos,
      );
    });
    _autoSaveWeek();
  }

  Future<void> _autoSaveWeek() async {
    final uid = AuthService.currentUid;
    if (uid == null || _recommendations == null) return;
    await DatabaseService.saveWeekData(
      uid:             uid,
      weekNumber:      _weekNumber,
      recommendations: _recommendations!,
      expEarned:       _computeWeeklyExp(_recommendations!),
      weekStart:       _weekStart,
      claimedDays:     _claimedDays,
    );
  }

  /// DEV: jumps totalExp to targetLevel and triggers level-up + AI refresh.
  void _devSetLevel(int targetLevel) {
    // Set EXP to 1 past the boundary so _levelFromExp resolves unambiguously
    final newExp = _totalExpForLevel(targetLevel) + 1;
    final prevLevel = _levelFromExp(_totalExp);
    setState(() => _totalExp = newExp);
    final uid = AuthService.currentUid;
    if (uid != null) {
      DatabaseService.updateExpAndWeek(
          uid: uid, totalExp: _totalExp, weekNumber: _weekNumber);
    }
    if (targetLevel > prevLevel) {
      // Show level-up overlay, then immediately fire AI refresh (no extra delay for dev)
      setState(() { _showLevelUp = true; _levelUpTo = targetLevel; });
      _levelUpCtrl.forward(from: 0).then((_) {
        if (mounted) {
          setState(() => _showLevelUp = false);
          _fetchRecommendationsForLevel(targetLevel);
        }
      });
    } else {
      // Going down or same — just refresh plan for that level without overlay
      _fetchRecommendationsForLevel(targetLevel);
    }
  }

  Map<String, dynamic> _categoryConfig(String category) {
    switch (category) {
      case 'nutrition':
        return {
          'icon':        Icons.restaurant_menu_rounded,
          'color':       const Color(0xFFE8F4F8),
          'iconColor':   const Color(0xFF2196F3),
          'accentColor': const Color(0xFF2196F3),
        };
      case 'exercise':
        return {
          'icon':        Icons.fitness_center_rounded,
          'color':       const Color(0xFFF0F8E8),
          'iconColor':   const Color(0xFF4CAF50),
          'accentColor': const Color(0xFF4CAF50),
        };
      case 'sleep':
      default:
        return {
          'icon':        Icons.bedtime_rounded,
          'color':       const Color(0xFFF3EEF8),
          'iconColor':   const Color(0xFF9C27B0),
          'accentColor': const Color(0xFF9C27B0),
        };
    }
  }

  Widget _buildRecommendationsList(bool isDark) {
    if (_isLoading) {
      return Column(
          children: List.generate(3, (_) => const _SkeletonCard()));
    }
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.red.shade900.withValues(alpha: 0.25)
              : Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? Colors.red.shade800 : Colors.red.shade100),
        ),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.red.shade300, size: 36),
            const SizedBox(height: 12),
            Text(
              'Could not load recommendations.\nPlease check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                  fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _fetchRecommendations,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                  foregroundColor: isDark
                      ? Colors.red.shade300
                      : const Color(0xFF1A1A2E)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(_recommendations!.length, (recIndex) {
        final rec    = _recommendations![recIndex];
        final config = _categoryConfig(rec.category);
        return _RecommendationSection(
          rec:         rec,
          recIndex:    recIndex,
          icon:        config['icon'] as IconData,
          bgColor:     config['color'] as Color,
          iconColor:   config['iconColor'] as Color,
          accentColor: config['accentColor'] as Color,
          onToggleDay: _toggleDay,
          onEditTodo:  _editTodo,
          todayIndex:  _todayIndex(),
          isDark:      isDark,
        );
      }),
    );
  }

  /// Opens the task edit sheet for the given rec/todo.
  void _editTodo(int recIndex, int todoIndex) {
    final rec  = _recommendations![recIndex];
    final todo = rec.todos[todoIndex];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditTodoSheet(
        todo:        todo,
        category:    rec.category,
        userProfile: widget.userProfile,
        onSave:      (newTask, newDetail) {
          setState(() {
            final newTodos = List<TodoItem>.from(rec.todos);
            newTodos[todoIndex] = TodoItem(
              task:   newTask,
              detail: newDetail,
              days:   todo.days,
            );
            _recommendations![recIndex] = AIRecommendation(
              category: rec.category,
              title:    rec.title,
              summary:  rec.summary,
              todos:    newTodos,
            );
          });
          _autoSaveWeek();
        },
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final user = AuthService.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final isDark  = Theme.of(context).brightness == Brightness.dark;
        final cardCol = isDark ? const Color(0xFF1E1E2E) : Colors.white;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration:
              BoxDecoration(color: cardCol, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF1A1A2E),
                  child: Text(
                    (user?.displayName ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  )),
              const SizedBox(height: 12),
              Text(user?.displayName ?? 'User',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
              Text(user?.email ?? '',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 24),
              Divider(color: isDark ? Colors.white12 : Colors.grey[100]),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: isDark
                            ? Colors.red.shade900.withValues(alpha: 0.3)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.logout_rounded,
                        color: Colors.red.shade400, size: 20)),
                title: Text('Sign Out',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade400)),
                onTap: () async {
                  Navigator.pop(context);
                  await AuthService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const WelcomeScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

///-----------------------------------------------------
/// *** Contributions in the following UI and functions: Dexter Logdonio, Andrei Deseo, Raign Vincent Rueda *** 
///-----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF7F8FA);
    final cardColor   = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final txtColor    = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor    = isDark ? Colors.grey[400]! : Colors.grey[500]!;

    final currentLevel = _levelFromExp(_totalExp);
    final expInLevel   = _expIntoLevel(_totalExp);
    final expProgress  = expInLevel / _expNeededForCurrentLevel(_totalExp);
    final rank         = _rankLabel(currentLevel);
    final rankColor    = _rankColor(currentLevel);

    final today         = _todayIndex();
    final todayClaimed  = _claimedDays.contains(today);
    final todayExp      = _recommendations != null
        ? _computeDayExp(_recommendations!, today)
        : 0;

    // Bottom nav
    Widget bottomNav = Container(
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -3))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                  isDark: isDark),
              _NavItem(
                  icon: Icons.people_rounded,
                  label: 'Friends',
                  selected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                  isDark: isDark),
              _NavItem(
                  icon: Icons.leaderboard_rounded,
                  label: 'Ranking',
                  selected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                  isDark: isDark),
              _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  selected: _selectedIndex == 3,
                  onTap: () => setState(() => _selectedIndex = 3),
                  isDark: isDark),
            ],
          ),
        ),
      ),
    );

    return Stack(
      children: [
        Scaffold(
          backgroundColor: bgColor,
          bottomNavigationBar: bottomNav,
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              // ── Tab 0: Home ───────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    // ── Header ───────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Text('Evexia',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: txtColor,
                                  letterSpacing: 0.5)),
                          const Spacer(),
                          // Dark mode toggle
                          ValueListenableBuilder<ThemeMode>(
                            valueListenable: themeNotifier,
                            builder: (_, mode, __) => GestureDetector(
                              onTap: () => themeNotifier.toggle(),
                              child: Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark
                                        ? const Color(0xFF2A2A3E)
                                        : Colors.grey[200]),
                                child: Icon(
                                  mode == ThemeMode.dark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                  color: isDark
                                      ? Colors.amber
                                      : const Color(0xFF1A1A2E),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Profile avatar
                          GestureDetector(
                            onTap: () => _showProfileMenu(context),
                            child: Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? const Color(0xFF2A2A3E)
                                      : Colors.grey[200]),
                              child: Icon(Icons.person_outline,
                                  color: txtColor, size: 20),
                            ),
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

                            // ── EXP Card ──────────────────────
                            _ExpCard(
                              level:       currentLevel,
                              expInLevel:  expInLevel,
                              expProgress: expProgress,
                              rank:        rank,
                              rankColor:   rankColor,
                              totalExp:    _totalExp,
                              weekNumber:  _weekNumber,
                              expBurstAnim: _expBurstAnim,
                              lastGained:  _lastGained,
                            ),

                            const SizedBox(height: 20),

                            // ── Survey chips ───────────────────
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: [
                                _SurveyChip(
                                    label: widget.userProfile.activityLevel,
                                    icon: Icons.directions_run_rounded,
                                    isDark: isDark),
                                _SurveyChip(
                                    label: widget.userProfile.sleepHours,
                                    icon: Icons.bedtime_rounded,
                                    isDark: isDark),
                                ...widget.userProfile.primaryGoals.map(
                                    (g) => _SurveyChip(
                                        label: g,
                                        icon: Icons.track_changes_rounded,
                                        isDark: isDark)),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // ── Weekly Plan header ─────────────
                            Row(
                              children: [
                                Text('Your Weekly Plan',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: txtColor)),
                                const Spacer(),
                                if (_isLoading)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: txtColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 10, height: 10,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: txtColor.withValues(alpha: 0.6)),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(_loadingStatus,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: txtColor.withValues(alpha: 0.6),
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                if (_levelUpRefreshing && !_isLoading)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(width: 10, height: 10,
                                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4CAF50))),
                                        SizedBox(width: 6),
                                        Text('Upgrading plan…',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF4CAF50),
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                if (!_isLoading && !_levelUpRefreshing && _error == null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.auto_awesome,
                                            size: 11,
                                            color: Color(0xFF4CAF50)),
                                        SizedBox(width: 4),
                                        Text('AI powered',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF4CAF50),
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 6),
                            Text('Tap a day circle to mark done or missed.',
                                style: TextStyle(
                                    fontSize: 12, color: subColor)),
                            const SizedBox(height: 14),

                            _buildRecommendationsList(isDark),

                            // ── Claim Today button ─────────────
                            if (!_isLoading && _error == null) ...[
                              const SizedBox(height: 8),
                              _ClaimDayButton(
                                todayIndex:   today,
                                todayExp:     todayExp,
                                alreadyClaimed: todayClaimed,
                                onClaim:      _claimDay,
                              ),
                            ],

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tab 1: Friends ────────────────────────
              const FriendsScreen(),

              // ── Tab 2: Leaderboard ────────────────────
              const LeaderboardScreen(),

              // ── Tab 3: Profile ────────────────────────
              ProfileScreen(
                totalExp:         _totalExp,
                weekNumber:       _weekNumber,
                onDevResetWeek:   () => _finalizeWeek(auto: false, devMode: true),
                onDevSetLevel:    _devSetLevel,
              ),
            ],
          ),
        ),

        // ── "New tasks this week!" overlay ────────────
        if (_showNewWeek)
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 20, right: 20,
            child: ScaleTransition(
              scale: _newWeekAnim,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF4A90D9)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20)
                  ],
                ),
                child: Row(
                  children: [
                    Text(_newWeekIsLevelUp ? '⚡' : '🎯', style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _newWeekIsLevelUp ? 'Level $_levelUpTo plan unlocked!' : 'New tasks for this week!',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(
                            _newWeekIsLevelUp
                                ? 'Your AI plan just upgraded. Check it out! 🚀'
                                : 'Week $_weekNumber starts now. Let\'s go! 🚀',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.75))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Level-up overlay ─────────────────────────
        if (_showLevelUp)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showLevelUp = false),
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: ScaleTransition(
                    scale: _levelUpAnim,
                    child: Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 36),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E2E)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 40)
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎉',
                              style: TextStyle(fontSize: 56)),
                          const SizedBox(height: 12),
                          Text('LEVEL UP!',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                  letterSpacing: 2)),
                          const SizedBox(height: 8),
                          Text('You reached Level $_levelUpTo',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[isDark ? 400 : 600])),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: _rankColor(_levelUpTo)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_rankLabel(_levelUpTo)} Rank',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _rankColor(_levelUpTo)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Tap anywhere to continue',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[400])),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 10, height: 10,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4CAF50))),
                              const SizedBox(width: 8),
                              Text('Unlocking your Level $_levelUpTo plan…',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
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
// Week Report Modal (bottom sheet shown at week end)
// ─────────────────────────────────────────────────────────
class _WeekReportModal extends StatelessWidget {
  final int weekNumber;
  final int totalTasks;
  final int doneTasks;
  final int missedTasks;
  final int expEarned;
  final String commendation;

  const _WeekReportModal({
    required this.weekNumber,
    required this.totalTasks,
    required this.doneTasks,
    required this.missedTasks,
    required this.expEarned,
    required this.commendation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final cardCol  = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final txtColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final pct      = totalTasks > 0 ? doneTasks / totalTasks : 0.0;
    final pctStr   = '${(pct * 100).round()}%';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      decoration: BoxDecoration(
          color: cardCol, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          const Text('📊', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text('Week $weekNumber Wrap-Up',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: txtColor)),
          const SizedBox(height: 20),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ReportStat(
                  emoji: '✅',
                  value: '$doneTasks',
                  label: 'Completed',
                  color: const Color(0xFF4CAF50)),
              _ReportStat(
                  emoji: '❌',
                  value: '$missedTasks',
                  label: 'Missed',
                  color: Colors.red.shade400),
              _ReportStat(
                  emoji: '⚡',
                  value: '+$expEarned',
                  label: 'EXP',
                  color: const Color(0xFFFFC107)),
              _ReportStat(
                  emoji: '🎯',
                  value: pctStr,
                  label: 'Rate',
                  color: const Color(0xFF2196F3)),
            ],
          ),

          const SizedBox(height: 20),

          // Completion bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 0.8
                    ? const Color(0xFF4CAF50)
                    : pct >= 0.5
                        ? const Color(0xFFFFC107)
                        : Colors.red.shade400,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Commendation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              commendation,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: txtColor,
                  height: 1.5),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Start New Week 🚀',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;

  const _ReportStat({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style:
                TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Claim Day Button
// ─────────────────────────────────────────────────────────
class _ClaimDayButton extends StatelessWidget {
  final int todayIndex;
  final int todayExp;
  final bool alreadyClaimed;
  final VoidCallback onClaim;

  const _ClaimDayButton({
    required this.todayIndex,
    required this.todayExp,
    required this.alreadyClaimed,
    required this.onClaim,
  });

  static const _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final dayName = _dayNames[todayIndex];

    if (alreadyClaimed) {
      return Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 8),
            Text("$dayName's EXP claimed!",
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4CAF50))),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: todayExp > 0 ? onClaim : null,
        icon: const Icon(Icons.bolt_rounded, size: 18),
        label: Text(
          todayExp > 0
              ? 'Claim $dayName (+$todayExp EXP)'
              : 'Mark tasks first to claim EXP',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 121, 121, 255),
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey[300],
          disabledForegroundColor: isDark ? Colors.white30 : Colors.black45,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
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
          colors: [
            const Color(0xFF1A1A2E),
            rankColor.withValues(alpha: 0.85)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: rankColor.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text('LVL',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 1.5)),
                    Text('$level',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: rankColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: rankColor.withValues(alpha: 0.5), width: 1),
                      ),
                      child: Text('⭐ $rank',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                    const SizedBox(height: 6),
                    Text('$totalExp total EXP',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500)),
                    Text('Week $weekNumber',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              // EXP burst animation
              AnimatedBuilder(
                animation: expBurstAnim,
                builder: (_, __) {
                  if (lastGained == 0) return const SizedBox.shrink();
                  return Opacity(
                    opacity: (1.0 - expBurstAnim.value).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -30 * expBurstAnim.value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('+$lastGained EXP',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Text('$expInLevel',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_expNeededForCurrentLevel(totalExp)} EXP to next level',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: expProgress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                  rankColor == const Color(0xFFCD7F32)
                      ? Colors.amber.shade300
                      : Colors.white),
            ),
          ),
        ],
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
  final void Function(int recIndex, int todoIndex, int dayIndex, DayState current)
      onToggleDay;
  final void Function(int recIndex, int todoIndex) onEditTodo;
  final int todayIndex;
  final bool isDark;

  const _RecommendationSection({
    required this.rec,
    required this.recIndex,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.accentColor,
    required this.onToggleDay,
    required this.onEditTodo,
    required this.todayIndex,
    required this.isDark,
  });

  @override
  State<_RecommendationSection> createState() =>
      _RecommendationSectionState();
}

class _RecommendationSectionState
    extends State<_RecommendationSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cardColor  = widget.isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final txtColor   = widget.isDark ? Colors.white : const Color(0xFF1A1A2E);
    final summaryColor = widget.isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final dividerColor = widget.isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey[100]!;
    final progressBg   = widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100]!;
    final iconBg       = widget.isDark
        ? widget.iconColor.withValues(alpha: 0.15)
        : widget.bgColor;

    final doneCount  = widget.rec.todos
        .expand((t) => t.days)
        .where((d) => d == DayState.done)
        .length;
    final totalCount = widget.rec.todos.length * 7;
    final progress   = totalCount > 0 ? doneCount / totalCount : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black
                  .withValues(alpha: widget.isDark ? 0.3 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _expanded = !_expanded),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(widget.icon,
                            color: widget.iconColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(widget.rec.title,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: txtColor)),
                            const SizedBox(height: 2),
                            Text(widget.rec.summary,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: summaryColor,
                                    height: 1.3)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.25 : 0,
                        duration:
                            const Duration(milliseconds: 250),
                        child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: Colors.grey[400]),
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
                            value: progress,
                            minHeight: 6,
                            backgroundColor: progressBg,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                widget.accentColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('$doneCount/$totalCount',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.accentColor)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                Divider(height: 1, color: dividerColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      ...List.generate(7, (i) {
                        final isToday = i == widget.todayIndex;
                        return SizedBox(
                          width: 30,
                          child: Center(
                            child: Text(_dayLabels[i],
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isToday
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    color: isToday
                                        ? widget.accentColor
                                        : Colors.grey[400])),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                ...List.generate(
                    widget.rec.todos.length, (todoIndex) {
                  final todo = widget.rec.todos[todoIndex];
                  return _TodoRow(
                    todo:        todo,
                    accentColor: widget.accentColor,
                    isLast:      todoIndex ==
                        widget.rec.todos.length - 1,
                    todayIndex:  widget.todayIndex,
                    isDark:      widget.isDark,
                    onToggleDay: (dayIndex, current) =>
                        widget.onToggleDay(
                            widget.recIndex, todoIndex,
                            dayIndex, current),
                    onEdit: () => widget.onEditTodo(widget.recIndex, todoIndex),
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
  final int todayIndex;
  final bool isDark;
  final void Function(int dayIndex, DayState current) onToggleDay;
  final VoidCallback onEdit;

  const _TodoRow({
    required this.todo,
    required this.accentColor,
    required this.isLast,
    required this.todayIndex,
    required this.isDark,
    required this.onToggleDay,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final txtColor       = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final dividerColor   = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey[100]!;
    final doneThisWeek   =
        todo.days.where((d) => d == DayState.done).length;
    final missedThisWeek =
        todo.days.where((d) => d == DayState.missed).length;

    // Day circle backgrounds for neutral/future states
    final neutralBg     = isDark ? const Color(0xFF2A2A3E) : Colors.white;
    final futureBg      = isDark ? const Color(0xFF1A1A2E) : Colors.grey.shade50;
    final futureBorder  = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200;
    final futureIcon    = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300;
    final pastNeutralBg = isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade100;
    final pastNeutralBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300;
    final pastNeutralIcon   = isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade400;
    final doneBadgeBg   = doneThisWeek > 0
        ? accentColor.withValues(alpha: 0.1)
        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[100]!);
    final doneBadgeTxt  = doneThisWeek > 0 ? accentColor : Colors.grey[400]!;
    final missedBadgeBg = isDark ? Colors.red.shade900.withValues(alpha: 0.35) : Colors.red.shade50;

    return GestureDetector(
      onLongPress: onEdit,
      child: Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: dividerColor, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(todo.task,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: txtColor,
                              height: 1.3)),
                    ),
                    GestureDetector(
                      onTap: onEdit,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.edit_outlined,
                            size: 14,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.25)
                                : Colors.grey[350]),
                      ),
                    ),
                  ],
                ),
                if (todo.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(todo.detail,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          height: 1.3)),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: doneBadgeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('✓ $doneThisWeek',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: doneBadgeTxt)),
                    ),
                    if (missedThisWeek > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: missedBadgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('✗ $missedThisWeek',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
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
              final state    = todo.days[dayIndex];
              final isToday  = dayIndex == todayIndex;
              final isPast   = dayIndex < todayIndex;
              final isFuture = dayIndex > todayIndex;

              if (isFuture) {
                return Tooltip(
                  message: 'Not yet',
                  child: Container(
                    width: 28, height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: futureBg,
                      border: Border.all(color: futureBorder, width: 1.5),
                    ),
                    child: Icon(Icons.lock_outline_rounded,
                        size: 11, color: futureIcon),
                  ),
                );
              }

              if (isPast) {
                final Color bgColor;
                final Color borderColor;
                final Widget child;

                switch (state) {
                  case DayState.done:
                    bgColor     = accentColor.withValues(alpha: 0.7);
                    borderColor = accentColor.withValues(alpha: 0.7);
                    child = const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white);
                  case DayState.missed:
                    bgColor     = Colors.red.shade300;
                    borderColor = Colors.red.shade300;
                    child = const Icon(Icons.close_rounded,
                        size: 13, color: Colors.white);
                  case DayState.neutral:
                    bgColor     = pastNeutralBg;
                    borderColor = pastNeutralBorder;
                    child = Icon(Icons.lock_rounded,
                        size: 11, color: pastNeutralIcon);
                }

                return Tooltip(
                  message: 'Day passed',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 28, height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bgColor,
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Center(child: child),
                  ),
                );
              }

              // Today
              final Color bgColor;
              final Color borderColor;
              final Widget? icon;

              switch (state) {
                case DayState.done:
                  bgColor     = accentColor;
                  borderColor = accentColor;
                  icon = const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white);
                case DayState.missed:
                  bgColor     = Colors.red.shade400;
                  borderColor = Colors.red.shade400;
                  icon = const Icon(Icons.close_rounded,
                      size: 13, color: Colors.white);
                case DayState.neutral:
                  bgColor     = neutralBg;
                  borderColor = accentColor;
                  icon        = null;
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
                    border: Border.all(
                        color: borderColor,
                        width: isToday ? 2 : 1.5),
                    boxShadow: isToday
                        ? [BoxShadow(
                              color: accentColor.withValues(alpha: 0.35),
                              blurRadius: 6,
                              spreadRadius: 1)]
                        : null,
                  ),
                  child: Center(child: icon),
                ),
              );
            }),
          ),
        ],
      ),
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

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
            color: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200],
            borderRadius: BorderRadius.circular(4)),
      );

  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final isDark     = _isDark;
    final cardColor  = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final shimmerBg  = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: shimmerBg,
                        borderRadius: BorderRadius.circular(12))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _bar(140, 14),
                      const SizedBox(height: 6),
                      _bar(200, 11),
                    ])),
              ]),
              const SizedBox(height: 14),
              ...List.generate(
                  3,
                  (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                _bar(160, 12),
                                const SizedBox(height: 4),
                                _bar(100, 10),
                              ])),
                          const SizedBox(width: 8),
                          Row(
                              children:
                                  List.generate(
                                      7,
                                      (_) => Container(
                                            width: 28,
                                            height: 28,
                                            margin: const EdgeInsets
                                                .symmetric(
                                                horizontal: 1),
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: shimmerBg),
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
  final bool isDark;
  const _SurveyChip(
      {required this.label, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : const Color(0xFF1A1A2E).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13,
              color: isDark
                  ? Colors.white70
                  : const Color(0xFF1A1A2E)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white70
                      : const Color(0xFF1A1A2E))),
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
  final bool isDark;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor =
        isDark ? Colors.white : const Color(0xFF1A1A2E);
    final inactiveColor = Colors.grey[400]!;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: selected ? activeColor : inactiveColor,
              size: 24),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: selected ? activeColor : inactiveColor)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Edit Todo Sheet
// Two tabs: Manual edit | Ask AI for a suggestion
// ─────────────────────────────────────────────────────────
class _EditTodoSheet extends StatefulWidget {
  final TodoItem todo;
  final String category;
  final UserProfile userProfile;
  final void Function(String task, String detail) onSave;

  const _EditTodoSheet({
    required this.todo,
    required this.category,
    required this.userProfile,
    required this.onSave,
  });

  @override
  State<_EditTodoSheet> createState() => _EditTodoSheetState();
}

class _EditTodoSheetState extends State<_EditTodoSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late TextEditingController _taskCtrl;
  late TextEditingController _detailCtrl;
  final TextEditingController _aiPromptCtrl = TextEditingController();

  bool _aiLoading = false;
  String? _aiError;
  String? _aiSuggestedTask;
  String? _aiSuggestedDetail;

  @override
  void initState() {
    super.initState();
    _tabCtrl   = TabController(length: 2, vsync: this);
    _taskCtrl   = TextEditingController(text: widget.todo.task);
    _detailCtrl = TextEditingController(text: widget.todo.detail);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _taskCtrl.dispose();
    _detailCtrl.dispose();
    _aiPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _askAI() async {
    final prompt = _aiPromptCtrl.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _aiLoading       = true;
      _aiError         = null;
      _aiSuggestedTask   = null;
      _aiSuggestedDetail = null;
    });

    try {
      final goals = widget.userProfile.primaryGoals.join(', ');
      final diet  = widget.userProfile.dietaryPatterns.isEmpty
          ? 'No restrictions'
          : widget.userProfile.dietaryPatterns.join(', ');

      final systemPrompt = '''
You are a health coach assistant. The user is customising one of their ${widget.category} tasks.

Their context:
- Goals: $goals
- Activity level: ${widget.userProfile.activityLevel}
- Sleep: ${widget.userProfile.sleepHours}
- Diet: $diet

Current task: "${widget.todo.task}"
Current detail: "${widget.todo.detail}"
User's request: "$prompt"

Respond ONLY with a valid JSON object — no markdown, no preamble:
{
  "task": "Short replacement task label (max 8 words)",
  "detail": "Brief extra detail or reason (max 12 words)"
}
''';

      final response = await AIService.getRawCompletion(systemPrompt);
      if (!mounted) return;

      // Parse JSON
      final clean = response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final startIdx = clean.indexOf('{');
      final endIdx   = clean.lastIndexOf('}');
      final jsonStr  = clean.substring(startIdx, endIdx + 1);
      final parsed   = jsonDecode(jsonStr) as Map<String, dynamic>;

      setState(() {
        _aiSuggestedTask   = parsed['task']   as String?;
        _aiSuggestedDetail = parsed['detail'] as String?;
        _aiLoading         = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError   = 'Could not get a suggestion: ${e.toString().replaceAll('Exception: ', '')}';
        _aiLoading = false;
      });
    }
  }

  void _applyAISuggestion() {
    if (_aiSuggestedTask == null) return;
    _taskCtrl.text   = _aiSuggestedTask!;
    _detailCtrl.text = _aiSuggestedDetail ?? '';
    _tabCtrl.animateTo(0);
    setState(() {
      _aiSuggestedTask   = null;
      _aiSuggestedDetail = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final cardCol  = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final txtColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final fieldFill = isDark ? const Color(0xFF2A2A3E) : Colors.grey[50]!;
    final borderCol = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey[200]!;

    final categoryEmoji = switch (widget.category) {
      'nutrition' => '🥗',
      'exercise'  => '💪',
      _           => '😴',
    };

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: cardCol,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(categoryEmoji,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Task',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: txtColor)),
                        Text('Customise or ask AI for a better fit.',
                            style: TextStyle(
                                fontSize: 12, color: subColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Tab bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF454D6E)
                        : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: subColor,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: '✏️  Manual'),
                    Tab(text: '✨  Ask AI'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Tab views ──
            SizedBox(
              height: 260,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Manual Edit tab ────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Task',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xFF454D6E))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _taskCtrl,
                          style: TextStyle(fontSize: 14, color: txtColor),
                          maxLength: 80,
                          decoration: InputDecoration(
                            hintText: 'e.g. Drink 2.5 L of water today',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                            filled: true,
                            fillColor: fieldFill,
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF1A1A2E),
                                    width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('Detail / Note',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xFF454D6E))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _detailCtrl,
                          style: TextStyle(fontSize: 14, color: txtColor),
                          maxLength: 100,
                          decoration: InputDecoration(
                            hintText: 'Optional extra info or reason',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                            filled: true,
                            fillColor: fieldFill,
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF1A1A2E),
                                    width: 1.5)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Ask AI tab ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Describe what you want instead',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xFF454D6E))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _aiPromptCtrl,
                          style: TextStyle(fontSize: 14, color: txtColor),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText:
                                'e.g. "I prefer swimming over running" or "Make this easier for me"',
                            hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                                height: 1.4),
                            filled: true,
                            fillColor: fieldFill,
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF1A1A2E),
                                    width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (_aiError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(_aiError!,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.red.shade400)),
                          ),

                        if (_aiSuggestedTask != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF4CAF50)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.auto_awesome,
                                      size: 13, color: Color(0xFF4CAF50)),
                                  const SizedBox(width: 5),
                                  Text('AI Suggestion',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? const Color(0xFF81C784)
                                              : const Color(0xFF388E3C))),
                                ]),
                                const SizedBox(height: 6),
                                Text(_aiSuggestedTask!,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: txtColor)),
                                if (_aiSuggestedDetail != null &&
                                    _aiSuggestedDetail!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(_aiSuggestedDetail!,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: subColor)),
                                ],
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _applyAISuggestion,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4CAF50),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    child: const Text('Use this suggestion',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _aiLoading ? null : _askAI,
                              icon: _aiLoading
                                  ? const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Icon(Icons.auto_awesome, size: 16),
                              label: Text(
                                _aiLoading
                                    ? 'Thinking...'
                                    : 'Get AI Suggestion',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF454D6E)
                                    : const Color(0xFF1A1A2E),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    isDark ? Colors.grey[800] : Colors.grey[300],
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Save button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final task   = _taskCtrl.text.trim();
                    final detail = _detailCtrl.text.trim();
                    if (task.isEmpty) return;
                    widget.onSave(task, detail);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF454D6E)
                        : const Color(0xFF1A1A2E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Save Task',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}