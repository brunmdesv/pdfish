// pdfish/lib/main.dart
import 'package:flutter/material.dart';
import 'package:pdfish/screens/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart'; // Importar

void main() async { // 1. Transformar main em async
  // 2. Garantir que os bindings do Flutter estão inicializados antes de qualquer plugin
  WidgetsFlutterBinding.ensureInitialized();
  // 3. Inicializar os dados de formatação de data para pt_BR (Português Brasil)
  await initializeDateFormatting('pt_BR', null);
  runApp(const PdfishApp());
}

class PdfishApp extends StatelessWidget {
  const PdfishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pdfish',
      theme: ThemeData(
        primarySwatch: Colors.red,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}