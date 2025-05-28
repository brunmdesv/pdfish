// lib/themes/app_themes.dart
import 'package:flutter/material.dart';

class AppThemes {
  static const String _fontFamily = 'WDXLLubrifontTC';
  static const Color _primaryColor = Colors.redAccent;
  static const Color _primaryDarkerColor = Color(0xFFE53935);
  static const Color _primaryDarkestColor = Color(0xFFC62828);

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.red,
    fontFamily: _fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
      // Cores para o tema claro
      primary: _primaryColor,
      onPrimary: Colors.white, // Texto/ícones sobre a cor primária (ex: botões vermelhos)
      secondary: _primaryDarkerColor,
      onSecondary: Colors.white,
      surface: const Color(0xFFF5F5F5), // Cor de superfície de cards, etc.
      onSurface: Colors.black87,      // Texto/ícones sobre a superfície
      background: Colors.white,       // Cor de fundo geral
      onBackground: Colors.black87,   // Texto/ícones sobre o fundo
      error: Colors.red.shade700,
      onError: Colors.white,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFFAFAFA), // Um branco levemente off-white para o fundo do scaffold
    appBarTheme: const AppBarTheme(
      foregroundColor: Colors.white, // Ícones e título da AppBar (que tem gradiente vermelho)
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 24, // Mantendo o tamanho da CustomAppBar
        fontWeight: FontWeight.w700,
        color: Colors.white,
        fontFamily: _fontFamily,
        letterSpacing: -0.3,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
      displayMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
      displaySmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
      headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
      headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
      headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54),
      bodyLarge: TextStyle(fontSize: 15, color: Colors.black87),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
      bodySmall: TextStyle(fontSize: 12, color: Colors.black54),
      labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600), // Para botões com fundo primário
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _primaryColor, // O container do FAB ainda usa gradiente
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFFFFFFFF), // Fundo branco para a barra
      selectedItemColor: _primaryColor,
      unselectedItemColor: Colors.grey.shade600,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: _fontFamily),
      unselectedLabelStyle: const TextStyle(fontSize: 12, fontFamily: _fontFamily),
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      elevation: 8,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: _fontFamily),
      contentTextStyle: const TextStyle(color: Colors.black54, fontSize: 16, fontFamily: _fontFamily),
    ),
    iconTheme: IconThemeData(color: Colors.grey.shade700), // Ícones gerais
    primaryIconTheme: const IconThemeData(color: _primaryColor), // Ícones que usam a cor primária
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _primaryColor,
    ),
    inputDecorationTheme: InputDecorationTheme( // Estilo para TextFields
      hintStyle: TextStyle(color: Colors.grey.shade500),
      prefixIconColor: Colors.grey.shade600,
      suffixIconColor: Colors.grey.shade600,
      border: InputBorder.none, // Se você usa bordas customizadas como na AllPdfsScreen
      // focusedBorder: OutlineInputBorder(...), // Adicione se necessário
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.red,
    fontFamily: _fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.dark,
      primary: _primaryColor,
      onPrimary: Colors.white,
      secondary: _primaryDarkerColor,
      onSecondary: Colors.white,
      surface: const Color(0xFF1E1E1E),
      onSurface: Colors.white,
      background: const Color(0xFF121212),
      onBackground: Colors.white,
      error: Colors.redAccent.shade100,
      onError: Colors.black,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        fontFamily: _fontFamily,
        letterSpacing: -0.3,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
      displayMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
      displaySmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
      headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70),
      bodyLarge: TextStyle(fontSize: 15, color: Colors.white),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.white),
      bodySmall: TextStyle(fontSize: 12, color: Colors.white70),
      labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ).apply(bodyColor: Colors.white, displayColor: Colors.white),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF1E1E1E),
      selectedItemColor: _primaryColor,
      unselectedItemColor: Colors.white60,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: _fontFamily),
      unselectedLabelStyle: const TextStyle(fontSize: 12, fontFamily: _fontFamily),
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      elevation: 8,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: _fontFamily),
      contentTextStyle: const TextStyle(color: Colors.white70, fontSize: 16, fontFamily: _fontFamily),
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
    primaryIconTheme: const IconThemeData(color: _primaryColor),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _primaryColor,
    ),
     inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      prefixIconColor: Colors.white.withOpacity(0.7),
      suffixIconColor: Colors.white.withOpacity(0.7),
      border: InputBorder.none,
    ),
  );
}