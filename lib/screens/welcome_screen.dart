import 'package:flutter/material.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1A1A2E), width: 2),
                ),
                child: const Center(
                  child: Text('E',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                ),
              ),
              const SizedBox(height: 28),
              const Text('EVEXIA',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      letterSpacing: 6, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 8),
              Text('Your AI-powered health companion.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              const SizedBox(height: 6),
              Text('Track habits, earn EXP, level up your health.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400])),
              const Spacer(),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const OnboardingScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Get Started',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity, height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen())),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1A2E),
                    side: const BorderSide(color: Color(0xFF1A1A2E), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Login',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
