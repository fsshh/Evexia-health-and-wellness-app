import 'package:evexia_app/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'welcome_screen.dart';
import 'onboarding_screen.dart';
import 'dashboard_screen.dart';

/// Listens to Firebase auth state and routes accordingly:
///   - Not logged in  → WelcomeScreen
///   - Logged in, no survey → OnboardingScreen
///   - Logged in, survey done → DashboardScreen (with saved data)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // Still connecting to Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not signed in
        if (snapshot.data == null) {
          return const WelcomeScreen();
        }

        // Signed in — check if they have survey data
        final uid = snapshot.data!.uid;
        return FutureBuilder(
          future: DatabaseService.loadSurvey(uid),
          builder: (context, surveySnap) {
            if (surveySnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (surveySnap.data == null) {
              // No survey yet — go through onboarding
              return const OnboardingScreen();
            }
            // Has survey — load their saved dashboard
            return _SavedDashboardLoader(uid: uid, userProfile: surveySnap.data!);
          },
        );
      },
    );
  }
}

/// Loads saved EXP + week data from Firestore then opens DashboardScreen
class _SavedDashboardLoader extends StatefulWidget {
  final String uid;
  final dynamic userProfile;
  const _SavedDashboardLoader({required this.uid, required this.userProfile});

  @override
  State<_SavedDashboardLoader> createState() => _SavedDashboardLoaderState();
}

class _SavedDashboardLoaderState extends State<_SavedDashboardLoader> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await DatabaseService.getUserProfile(widget.uid);
    final totalExp   = (profile?['totalExp']   as int?) ?? 0;
    final weekNumber = (profile?['weekNumber'] as int?) ?? 1;
    final weekDataFull = await DatabaseService.loadWeekDataFull(uid: widget.uid, weekNumber: weekNumber);

    final weekData   = weekDataFull?['recommendations'] as List<dynamic>?;
    final claimedDays = weekDataFull?['claimedDays'] as Set<int>? ?? {};

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(
          userProfile: widget.userProfile,
          savedTotalExp: totalExp,
          savedWeekNumber: weekNumber,
          savedRecommendations: weekData != null ? weekData.cast<AIRecommendation>() : null,
          savedClaimedDays: claimedDays,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}