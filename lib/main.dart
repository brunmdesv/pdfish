// pdfish/lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfish/screens/home_screen.dart';
import 'package:pdfish/screens/pdf_viewer_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdfish/services/recent_pdfs_service.dart';
import 'package:flutter/services.dart';

void main() async {
  // Garantir que os bindings do Flutter estão inicializados antes de qualquer plugin
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar os dados de formatação de data para pt_BR (Português Brasil)
  await initializeDateFormatting('pt_BR', null);
  
  // Verificar se o app foi aberto a partir de um arquivo PDF
  final PlatformChannel platformChannel = PlatformChannel();
  final String? initialFilePath = await platformChannel.getInitialFilePath();
  
  runApp(PdfishApp(initialPdfPath: initialFilePath));
}

// Canal de plataforma para receber o caminho do arquivo inicial
class PlatformChannel {
  static const platform = MethodChannel('com.example.pdfish/file_intent');
  
  Future<String?> getInitialFilePath() async {
    try {
      final String? path = await platform.invokeMethod('getInitialFilePath');
      print('PlatformChannel: Recebido caminho inicial: $path');
      return path;
    } on PlatformException catch (e) {
      print('PlatformChannel: Erro ao obter caminho inicial: ${e.message}');
      return null;
    }
  }
}

class PdfishApp extends StatelessWidget {
  final String? initialPdfPath;
  
  const PdfishApp({super.key, this.initialPdfPath});

  // Método para construir o PdfViewerScreen quando o app é aberto a partir de um arquivo PDF
  Widget _buildPdfViewerFromIntent(String filePath) {
    final file = File(filePath);
    final fileName = filePath.split('/').last;
    
    // Registrar o arquivo nos recentes ao abrir via intent
    final recentPdfsService = RecentPdfsService();
    
    // Garantir que o arquivo seja adicionado aos recentes
    try {
      print("Adicionando PDF aos recentes: $filePath");
      recentPdfsService.addOrUpdateRecentPdf(
        filePath,
        fileName,
        null, // originalIdentifier
        file.lengthSync(), // fileSize
        null, // password
      );
    } catch (e) {
      print("Erro ao adicionar PDF aos recentes: $e");
    }
    
    // Usamos MaterialApp.router para evitar a tela preta
    return PdfViewerScreen(
      filePath: filePath,
      initialPasswordAttempt: null,
      fromIntent: true, // Indicar que veio de intent externo
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDFish',
      theme: ThemeData(
        primarySwatch: Colors.red,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Aplicando a fonte personalizada em todo o aplicativo
        fontFamily: 'WDXLLubrifontTC',
        // Definindo tamanhos de texto menores para todo o aplicativo
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontSize: 15),
          bodyMedium: TextStyle(fontSize: 14),
          bodySmall: TextStyle(fontSize: 12),
        ),
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
      home: initialPdfPath != null && initialPdfPath!.isNotEmpty && File(initialPdfPath!).existsSync()
          ? _buildPdfViewerFromIntent(initialPdfPath!)
          : const HomeScreen(),
    );
  }
}