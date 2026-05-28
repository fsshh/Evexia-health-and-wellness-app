import 'package:flutter/material.dart';

/// *** Contributions in the file: Raign Vincent Rueda ***

/// A simple ValueNotifier that toggles between light and dark ThemeMode.
/// Wrap MaterialApp with a ValueListenableBuilder on this to react globally.
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light);

  bool get isDark => value == ThemeMode.dark;

  void toggle() {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}

/// Global singleton — import and use anywhere.
final themeNotifier = ThemeNotifier();