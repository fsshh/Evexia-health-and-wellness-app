import 'package:flutter/material.dart';
import 'goals_screen.dart';

/// *** Contributions in the file: Acier Jan Andres, Andrei Deseo ***

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Welcome to Evexia!',
      'desc1': 'Earn EXP after completing goals',
      'desc2': 'Track your health and make plans',
      'desc3': 'AI powered recommendations',
    },
    {
      'title': 'Track Your Health',
      'desc1': 'Monitor your daily activity',
      'desc2': 'Stay on top of your wellness',
      'desc3': 'Reach your personal goals',
    },
    {
      'title': 'Personalized Plans',
      'desc1': 'Tailored recommendations',
      'desc2': 'Based on your lifestyle',
      'desc3': 'Achieve lasting results',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1EFEE),
      body: SafeArea(
        child: Column(
          children: [
            // Back button row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF454D6E)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Title
                    const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF454D6E),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? const Color(0xFF454D6E)
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    // Image placeholder
                    Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Content
                    Text(
                      _pages[_currentPage]['title']!,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF454D6E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ...[
                      _pages[_currentPage]['desc1']!,
                      _pages[_currentPage]['desc2']!,
                      _pages[_currentPage]['desc3']!,
                    ].map((text) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )),
                    const Spacer(),
                    // Next button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage < 2) {
                            setState(() => _currentPage++);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GoalsScreen(),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF454D6E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Skip
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GoalsScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Color(0xFF454D6E),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
