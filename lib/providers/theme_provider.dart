// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider pour gérer le mode du thème
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _themeModeKey = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  /// Charger le mode de thème depuis les préférences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString(_themeModeKey);

      if (themeModeString != null) {
        state = ThemeMode.values.firstWhere(
          (mode) => mode.name == themeModeString,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (e) {
      // En cas d'erreur, garder le mode système par défaut
      state = ThemeMode.system;
    }
  }

  /// Changer le mode du thème
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (e) {
      // Gérer l'erreur silencieusement
    }
  }

  /// Obtenir le label du mode actuel
  String get themeModeLabel {
    switch (state) {
      case ThemeMode.system:
        return 'Système';
      case ThemeMode.light:
        return 'Clair';
      case ThemeMode.dark:
        return 'Sombre';
    }
  }
}
