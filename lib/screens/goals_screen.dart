import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'dashboard_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  // Q1 — up to 2 selections
  final List<String> _primaryGoalOptions = [
    'Lose weight',
    'Maintain current weight',
    'Gain weight',
    'Gain muscle',
    'Modify/Improve my diet',
    'Stay active & improve endurance',
  ];
  final Set<String> _selectedGoals = {};

  // Q2 — multi-select
  final List<String> _struggleOptions = [
    'Lack of time (busy schedule)',
    'Intense food cravings',
    'Emotional eating (stress, boredom, anxiety)',
    'Lack of motivation or consistency',
    'Social events and dining out',
    'Difficulty planning or cooking meals',
    'Lack of energy / feeling tired all the time',
    'Cost of healthy food',
  ];
  final Set<String> _selectedStruggles = {};

  // Q3 — single select
  final List<String> _mealPlanOptions = [
    'Never',
    'Rarely',
    'Occasionally',
    'Frequently',
    'Always',
  ];
  String? _selectedMealPlan;

  // Q4 — single select
  final List<Map<String, String>> _activityOptions = [
    {'label': 'Sedentary', 'sub': 'Desk job, very little intentional exercise.'},
    {'label': 'Lightly Active', 'sub': 'On your feet a bit, light walking/exercise 1–2 days a week.'},
    {'label': 'Moderately Active', 'sub': 'Moving regularly, intentional exercise 3–5 days a week.'},
    {'label': 'Very Active', 'sub': 'Heavy physical labor or intense daily athletic training.'},
  ];
  String? _selectedActivity;

  // Q5 — single select
  final List<String> _sleepOptions = [
    'Less than 5 hours',
    '5–6 hours',
    '7–8 hours',
    '9+ hours',
  ];
  String? _selectedSleep;

  // Q6 — multi-select
  final List<String> _dietOptions = [
    'No restrictions (Eat anything)',
    'Vegetarian / Vegan',
    'Pescatarian',
    'Keto / Low-Carb',
    'Gluten-Free / Dairy-Free',
  ];
  final Set<String> _selectedDiet = {};

  // Notes
  final TextEditingController _notesController = TextEditingController();

  // ─── Widgets ───────────────────────────────────────

  Widget _sectionHeader(String number, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26, height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E), height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _checkboxTile({
    required String label,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1A1A2E).withOpacity(0.06)
              : disabled
                  ? Colors.grey[50]
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF1A1A2E) : Colors.grey[300]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox box
            Container(
              width: 20, height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF1A1A2E) : Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: selected ? const Color(0xFF1A1A2E) : Colors.grey[400]!,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: disabled ? Colors.grey[400] : const Color(0xFF1A1A2E),
                      )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.3)),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _radioTile(String label, String? groupValue, ValueChanged<String?> onChanged) {
    final bool selected = groupValue == label;
    return GestureDetector(
      onTap: () => onChanged(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1A2E).withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF1A1A2E) : Colors.grey[300]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFF1A1A2E) : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: const Color(0xFF1A1A2E),
                  )),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canContinue =>
      _selectedGoals.isNotEmpty &&
      _selectedMealPlan != null &&
      _selectedActivity != null &&
      _selectedSleep != null;

  Future<void> _onContinue() async {
    final profile = UserProfile(
      primaryGoals: _selectedGoals.toList(),
      struggles: _selectedStruggles.toList(),
      mealPlanningFrequency: _selectedMealPlan!,
      activityLevel: _selectedActivity!,
      sleepHours: _selectedSleep!,
      dietaryPatterns: _selectedDiet.toList(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    // Save survey to Firestore if user is signed in
    final uid = AuthService.currentUid;
    if (uid != null) {
      await DatabaseService.saveSurvey(uid: uid, profile: profile);
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen(userProfile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF1A1A2E)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text('Your Goals',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Q1: Primary Goal ──────────────────
                    _sectionHeader('1', 'What is your primary goal? (Select up to 2)'),
                    ..._primaryGoalOptions.map((opt) {
                      final selected = _selectedGoals.contains(opt);
                      final disabled = !selected && _selectedGoals.length >= 2;
                      return _checkboxTile(
                        label: opt,
                        selected: selected,
                        disabled: disabled,
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedGoals.remove(opt);
                          } else if (_selectedGoals.length < 2) {
                            _selectedGoals.add(opt);
                          }
                        }),
                      );
                    }),

                    const SizedBox(height: 16),

                    // ── Q2: Struggles ─────────────────────
                    _sectionHeader('2', 'What are your biggest struggles when managing your health/weight? (Select all that apply)'),
                    ..._struggleOptions.map((opt) => _checkboxTile(
                          label: opt,
                          selected: _selectedStruggles.contains(opt),
                          onTap: () => setState(() {
                            _selectedStruggles.contains(opt)
                                ? _selectedStruggles.remove(opt)
                                : _selectedStruggles.add(opt);
                          }),
                        )),

                    const SizedBox(height: 16),

                    // ── Q3: Meal Planning ─────────────────
                    _sectionHeader('3', 'How frequently do you plan your meals in advance?'),
                    ..._mealPlanOptions.map((opt) => _radioTile(
                          opt,
                          _selectedMealPlan,
                          (val) => setState(() => _selectedMealPlan = val),
                        )),

                    const SizedBox(height: 16),

                    // ── Q4: Activity Level ────────────────
                    _sectionHeader('4', 'How would you describe your typical daily activity level?'),
                    ..._activityOptions.map((opt) => _checkboxTile(
                          label: opt['label']!,
                          subtitle: opt['sub'],
                          selected: _selectedActivity == opt['label'],
                          onTap: () => setState(() => _selectedActivity = opt['label']),
                        )),

                    const SizedBox(height: 16),

                    // ── Q5: Sleep ─────────────────────────
                    _sectionHeader('5', 'How many hours of sleep do you get on an average night?'),
                    ..._sleepOptions.map((opt) => _radioTile(
                          opt,
                          _selectedSleep,
                          (val) => setState(() => _selectedSleep = val),
                        )),

                    const SizedBox(height: 16),

                    // ── Q6: Diet ──────────────────────────
                    _sectionHeader('6', 'Do you follow any specific dietary patterns or have restrictions? (Select all that apply)'),
                    ..._dietOptions.map((opt) => _checkboxTile(
                          label: opt,
                          selected: _selectedDiet.contains(opt),
                          onTap: () => setState(() {
                            _selectedDiet.contains(opt)
                                ? _selectedDiet.remove(opt)
                                : _selectedDiet.add(opt);
                          }),
                        )),

                    const SizedBox(height: 16),

                    // ── Notes ─────────────────────────────
                    const Text('Additional notes (optional)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Type here...',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[300]!)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[300]!)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF1A1A2E), width: 1.5)),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Continue ──────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _canContinue ? () => _onContinue() : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A2E),
                          disabledBackgroundColor: Colors.grey[300],
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.grey[500],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Continue',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),

                    // Required fields hint
                    if (!_canContinue)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Please answer questions 1, 3, 4, and 5 to continue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                  ],
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
    _notesController.dispose();
    super.dispose();
  }
}
