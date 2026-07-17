import 'package:flutter/material.dart';

class CosmicColors {
  static const Color cosmicPink = Color(0xFFD946EF);
  static const LinearGradient deepSpaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF1A1A2E),
      Color(0xFF2D1B4E),
      Color(0xFF0F0F1A),
    ],
  );
}

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Colors.blue,
  scaffoldBackgroundColor: Colors.white,
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  useMaterial3: true,
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: Colors.teal,
  scaffoldBackgroundColor: const Color(0xFF121212),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.teal,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
);

final ThemeData purpleTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: Colors.purple,
  scaffoldBackgroundColor: const Color(0xFF1A1A2E),
  cardColor: const Color(0xFF252540),
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.purple,
    brightness: Brightness.dark,
    background: const Color(0xFF1A1A2E),
    surface: const Color(0xFF1A1A2E),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
  ),
  useMaterial3: true,
);