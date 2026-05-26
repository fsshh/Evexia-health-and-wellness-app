import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'providers/theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const EvexiaApp());
}

class EvexiaApp extends StatelessWidget {
  const EvexiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Evexia',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A1A2E),
            brightness: Brightness.light,
          ),
          fontFamily: 'Georgia',
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF7F8FA),
          cardColor: Colors.white,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4A90D9),
            brightness: Brightness.dark,
          ),
          fontFamily: 'Georgia',
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
          cardColor: const Color(0xFF1E1E2E),
        ),
        home: const AuthGate(),
      ),
    );
  }
}