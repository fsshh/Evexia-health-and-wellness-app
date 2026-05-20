import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'onboarding_screen.dart';
import 'dashboard_screen.dart';
import '../widgets/auth_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    final err = await AuthService.signIn(email: email, password: password);
    if (!mounted) return;

    if (err != null) {
      setState(() { _loading = false; _error = err; });
      return;
    }

    // Load saved user data and navigate to dashboard
    setState(() => _loading = false);
    final uid = AuthService.currentUid!;
    final profile = await DatabaseService.loadSurvey(uid);
    if (!mounted) return;

    if (profile == null) {
      // No survey yet — go to onboarding
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } else {
      // Has survey — load EXP + week data then go to dashboard
      final userProfile = await DatabaseService.getUserProfile(uid);
      final totalExp   = (userProfile?['totalExp']   as int?) ?? 0;
      final weekNumber = (userProfile?['weekNumber'] as int?) ?? 1;
      final weekData   = await DatabaseService.loadWeekData(
          uid: uid, weekNumber: weekNumber);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            userProfile: profile,
            savedTotalExp: totalExp,
            savedWeekNumber: weekNumber,
            savedRecommendations: weekData,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF1A1A2E)),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              const Text('Welcome back',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 6),
              Text('Sign in to continue your health journey.',
                  style: TextStyle(fontSize: 15, color: Colors.grey[500])),
              const SizedBox(height: 40),

              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 20),
              ],

              const FieldLabel('Email'),
              const SizedBox(height: 8),
              InputField(
                controller: _emailCtrl,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              const FieldLabel('Password'),
              const SizedBox(height: 8),
              InputField(
                controller: _passwordCtrl,
                hint: '••••••••',
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20, color: Colors.grey[400],
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SignupScreen())),
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      children: const [
                        TextSpan(text: 'Sign up',
                            style: TextStyle(
                                color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}
