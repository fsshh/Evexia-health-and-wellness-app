import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/user_profile.dart';
import '../services/ai_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class DashboardScreen extends StatefulWidget {
  final UserProfile userProfile;
  const DashboardScreen({super.key, required this.userProfile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  List<AIRecommendation>? _recommendations;
  bool _isLoading = true;
  String? _error;
  String _loadingStatus = 'Generating your plan...';

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    setState(() { _isLoading = true; _error = null; _loadingStatus = 'Generating your plan...'; });
    try {
      // Listen for retry status updates via a simple polling approach
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

  Map<String, dynamic> _categoryConfig(String category) {
    switch (category) {
      case 'nutrition':
        return {'icon': Icons.restaurant_menu_rounded, 'color': const Color(0xFFE8F4F8), 'iconColor': const Color(0xFF2196F3)};
      case 'exercise':
        return {'icon': Icons.fitness_center_rounded, 'color': const Color(0xFFF0F8E8), 'iconColor': const Color(0xFF4CAF50)};
      case 'sleep':
      default:
        return {'icon': Icons.bedtime_rounded, 'color': const Color(0xFFF3EEF8), 'iconColor': const Color(0xFF9C27B0)};
    }
  }

  Widget _buildRecommendationsList() {
    if (_isLoading) {
      return Column(children: List.generate(3, (_) => _SkeletonCard()));
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
      children: _recommendations!.map((rec) {
        final config = _categoryConfig(rec.category);
        return _RecommendationCard(
          recommendation: rec,
          icon: config['icon'] as IconData,
          bgColor: config['color'] as Color,
          iconColor: config['iconColor'] as Color,
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                    // BMI Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your BMI',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
                                child: const Text('24.5',
                                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Normal',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF4CAF50))),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: 0.55, minHeight: 8,
                                        backgroundColor: Colors.grey[200],
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('16', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                        Text('40', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 60, height: 60,
                                child: CustomPaint(
                                  painter: _BMICirclePainter(value: 0.55),
                                  child: Center(child: Text('Chart',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey[600]))),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Survey chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SurveyChip(label: widget.userProfile.activityLevel, icon: Icons.directions_run_rounded),
                        _SurveyChip(label: widget.userProfile.sleepHours, icon: Icons.bedtime_rounded),
                        ...widget.userProfile.primaryGoals.map(
                          (g) => _SurveyChip(label: g, icon: Icons.track_changes_rounded)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Recommendations header
                    Row(
                      children: [
                        const Text('Recommendations for You',
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
                                    strokeWidth: 1.5,
                                    color: const Color(0xFF1A1A2E).withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(_loadingStatus,
                                    style: TextStyle(fontSize: 11,
                                        color: const Color(0xFF1A1A2E).withOpacity(0.6), fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        if (!_isLoading && _error == null)
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
                    ),

                    const SizedBox(height: 14),
                    _buildRecommendationsList(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Nav
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
    );
  }
}

// ─────────────────────────────────────────────
// Expandable AI Recommendation Card
// ─────────────────────────────────────────────
class _RecommendationCard extends StatefulWidget {
  final AIRecommendation recommendation;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  const _RecommendationCard({
    required this.recommendation,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // ── Header row (always visible) ──
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(color: widget.bgColor, borderRadius: BorderRadius.circular(14)),
                    child: Icon(widget.icon, color: widget.iconColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.recommendation.title,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                        const SizedBox(height: 4),
                        MarkdownBody(
                          data: widget.recommendation.summary,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                            strong: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                    child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded detail section ──
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Column(
              children: [
                Divider(height: 1, color: Colors.grey[100]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: widget.recommendation.bullets.map((bullet) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5),
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.iconColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: MarkdownBody(
                                data: bullet,
                                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                  p: TextStyle(fontSize: 13.5, color: Colors.grey[800], height: 1.5),
                                ),
                                selectable: false,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Skeleton loader
// ─────────────────────────────────────────────
class _SkeletonCard extends StatefulWidget {
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
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 52, height: 52,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(14))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(130, 14),
                    const SizedBox(height: 8),
                    _bar(double.infinity, 11),
                    const SizedBox(height: 5),
                    _bar(200, 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Survey chip
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
// Bottom nav item
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
// BMI circle painter
// ─────────────────────────────────────────────
class _BMICirclePainter extends CustomPainter {
  final double value;
  _BMICirclePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    canvas.drawCircle(center, radius,
        Paint()..color = Colors.grey.shade200..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2,
        2 * math.pi * value, false,
        Paint()..color = const Color(0xFF4CAF50)..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
