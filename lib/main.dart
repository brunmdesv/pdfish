import 'package:flutter/material.dart';
import 'package:pdfish/screens/home_screen.dart';

void main() {
  runApp(const PdfishApp());
}

class PdfishApp extends StatelessWidget {
  const PdfishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pdfish',
      theme: ThemeData(
        primarySwatch: Colors.red, // Cor tema do app
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white, // Cor do texto e ícones na AppBar
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white, // Cor do texto do botão
          ),
        ),
      ),
      debugShowCheckedModeBanner: false, // Remove o banner de debug
      home: const HomeScreen(),
    );
  }
}