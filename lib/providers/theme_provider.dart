// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier with ChangeNotifier {
  final String key = "theme_mode";
  SharedPreferences? _prefs;
  late ThemeMode _themeMode;

  ThemeNotifier() {
    _themeMode = ThemeMode.dark; // Padrão para escuro
    _loadFromPrefs();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  _loadFromPrefs() async {
    await _initPrefs();
    String? themeString = _prefs!.getString(key);
    if (themeString == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.dark; // Ou ThemeMode.system se preferir
    }
    notifyListeners();
  }

  _saveToPrefs(ThemeMode themeMode) async {
    await _initPrefs();
    _prefs!.setString(key, themeMode == ThemeMode.light ? 'light' : 'dark');
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    _saveToPrefs(_themeMode);
    notifyListeners();
  }

  // Helper para gradiente do corpo
  LinearGradient get bodyGradient {
    if (isDarkMode) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF000000),
          Color(0xFF111111),
          Color(0xFF222222),
          Color(0xFF1a1a1a),
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      );
    } else {
      // Gradiente claro para o corpo
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF), // Branco
          Color(0xFFF5F5F5), // Um cinza muito claro
          Color(0xFFEEEEEE), // Outro cinza claro
          Color(0xFFE0E0E0), // Cinza um pouco mais escuro
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      );
    }
  }

  // Helper para cores de cards e elementos secundários
  Color get cardBackgroundColor {
    return isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.03);
  }
  Color get cardBorderColor {
     return isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08);
  }
  Color get secondaryTextColor {
    return isDarkMode ? Colors.white70 : Colors.black54;
  }
  Color get primaryTextColorOnCard {
    return isDarkMode ? Colors.white : Colors.black87;
  }
   Color get subtleIconColor {
    return isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6);
  }
}