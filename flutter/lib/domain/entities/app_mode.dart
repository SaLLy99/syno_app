import 'package:flutter/material.dart';

enum AppMode { dating, bff }

extension AppModeExtension on AppMode {
  String get value => this == AppMode.dating ? 'dating' : 'bff';
  
  String get label => this == AppMode.dating ? 'Dating' : 'BFF';
  
  String get icon => this == AppMode.dating ? '\u{1F494}' : '\u{1F91D}';
  
  Color get color => this == AppMode.dating ? const Color(0xFFDB2777) : const Color(0xFF4A90D9);
  
  Color get lightColor => this == AppMode.dating ? const Color(0xFFFDF2F8) : const Color(0xFFEFF6FF);
  
  String get discoverLabel => this == AppMode.dating ? 'Discover' : 'Find Friends';
  
  String get matchFoundTitle => this == AppMode.dating ? "It's a Match!" : "You're Now Friends!";
  
  String get matchFoundSubtitle => this == AppMode.dating 
      ? 'You and {name} liked each other' 
      : 'You and {name} want to be friends';

  static AppMode fromString(String value) {
    return value == 'bff' ? AppMode.bff : AppMode.dating;
  }
}
