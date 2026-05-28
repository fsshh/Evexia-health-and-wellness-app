import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';

// *** Contributions in the file: Acier Jan Andres, Andrei Deseo ***

// -- Design System ------------------------------------------
class _C {
  static const navyDark  = Color(0xFF2E3450);
  static const cream     = Color(0xFFF1EFEE);
  static const olive     = Color(0xFF999A5E);
  static const slate     = Color(0xFF989CAD);
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.navyDark,
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative orbs
            Positioned(
              top: -80, right: -80,
              child: Container(
                width: 320, height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _C.cream.withValues(alpha: 0.08), width: 1),
                ),
              ),
            ),
            Positioned(
              bottom: 120, left: -60,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _C.olive.withValues(alpha: 0.18), width: 1),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 80),

                  // Logo
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.olive, width: 1.5),
                    ),
                    child: Center(
                      child: Text('E',
                          style: GoogleFonts.dmSerifDisplay(
                              fontSize: 28, color: _C.cream)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('EVEXIA',
                      style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                          color: _C.cream)),
                  const SizedBox(height: 10),
                  Text(
                    'Your AI-powered health companion.\nTrack habits, earn EXP, level up your health.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: _C.slate,
                        height: 1.6),
                  ),

                  const Spacer(),

                  // Get Started
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const OnboardingScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.olive,
                        foregroundColor: _C.cream,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text('Get Started',
                          style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Login
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen())),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _C.cream,
                        side: BorderSide(
                            color: _C.cream.withValues(alpha: 0.25), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Login',
                          style: GoogleFonts.dmSans(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
