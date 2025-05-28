// pdfish/lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

// Removido: import 'package:pdfish/screens/home_screen.dart';
import 'package:pdfish/screens/main_layout_screen.dart'; // ADICIONADO
import 'package:pdfish/screens/pdf_viewer_screen.dart';
import 'package:pdfish/services/recent_pdfs_service.dart';
import 'package:pdfish/widgets/custom_app_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  final PlatformChannel platformChannelHandler = PlatformChannel();
  final String? initialFilePath = await platformChannelHandler.getInitialFilePath();

  runApp(PdfishApp(initialPdfPath: initialFilePath));
}

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

class PdfishApp extends StatefulWidget {
  final String? initialPdfPath;

  const PdfishApp({super.key, this.initialPdfPath});

  @override
  State<PdfishApp> createState() => _PdfishAppState();
}

class _PdfishAppState extends State<PdfishApp> {
  Widget? _finalHomeWidget;
  bool _isLoadingTheme = true;

  @override
  void initState() {
    super.initState();
    _determineInitialRoute();
  }

  Future<void> _determineInitialRoute() async {
    if (widget.initialPdfPath != null && widget.initialPdfPath!.isNotEmpty) {
      bool permissionGranted = await _checkAndRequestStoragePermissionForIntent();
      File file = File(widget.initialPdfPath!);
      bool fileExists = await file.exists();

      if (permissionGranted && fileExists) {
        print("Main: Permissão OK e arquivo existe. Abrindo PDFViewerScreen para: ${widget.initialPdfPath}");
        setState(() {
          _finalHomeWidget = _buildPdfViewerFromIntent(widget.initialPdfPath!);
          _isLoadingTheme = false;
        });
      } else {
        if (!permissionGranted) {
          print("Main: Permissão negada para abrir o arquivo do intent. Redirecionando para MainLayoutScreen.");
        }
        if (!fileExists) {
          print("Main: Arquivo do intent não encontrado: ${widget.initialPdfPath}. Redirecionando para MainLayoutScreen.");
        }
        setState(() {
          _finalHomeWidget = const MainLayoutScreen(); // MODIFICADO AQUI
          _isLoadingTheme = false;
        });
      }
    } else {
      print("Main: Abertura normal do app. Redirecionando para MainLayoutScreen.");
      setState(() {
        _finalHomeWidget = const MainLayoutScreen(); // MODIFICADO AQUI
        _isLoadingTheme = false;
      });
    }
  }

  Future<bool> _checkAndRequestStoragePermissionForIntent() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        print("Main: Android 13+ detectado para abertura via intent. Acesso ao URI específico geralmente concedido pelo sistema.");
        return true;
      }
    } catch (e) {
      print("Main: Erro ao obter informações do dispositivo Android: $e. Prosseguindo com a verificação de permissão padrão.");
    }

    PermissionStatus status = await Permission.storage.status;
    print("Main: Status inicial da permissão de armazenamento (para intent): $status");

    if (!status.isGranted) {
      status = await Permission.storage.request();
      print("Main: Status da permissão de armazenamento (para intent) após solicitação: $status");
    }
    return status.isGranted;
  }

  Widget _buildPdfViewerFromIntent(String filePath) {
    final file = File(filePath);
    final fileName = filePath.split('/').last;
    final recentPdfsService = RecentPdfsService();

    Future<void> addRecentPdfAfterIntentOpen() async {
      try {
        if (await file.exists()) {
          print("Main: Adicionando PDF aos recentes (aberto via intent): $filePath");
          await recentPdfsService.addOrUpdateRecentPdf(
            filePath,
            fileName,
            null,
            await file.length(),
            null,
          );
        } else {
          print("Main: Arquivo não encontrado ao tentar adicionar aos recentes (intent): $filePath");
        }
      } catch (e) {
        print("Main: Erro ao adicionar PDF aos recentes (aberto via intent): $e");
      }
    }
    addRecentPdfAfterIntentOpen();

    return PdfViewerScreen(
      filePath: filePath,
      initialPasswordAttempt: null,
      fromIntent: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTheme || _finalHomeWidget == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Center(
            child: CircularProgressIndicator(
              color: Colors.redAccent,
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'PDFish',
      theme: ThemeData(
        primarySwatch: Colors.red,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'WDXLLubrifontTC',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          displayMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          // ... outros estilos de texto ...
          labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ).apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme( // Tema base para AppBar
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true, // Default para centralizar
          titleTextStyle: TextStyle( // Estilo base que CustomAppBar pode refinar
            fontSize: 20, // CustomAppBar usará 24, mas é bom ter um base
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'WDXLLubrifontTC',
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontFamily: 'WDXLLubrifontTC', fontWeight: FontWeight.w600),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color(0xFF1E1E1E),
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.white60,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'WDXLLubrifontTC'),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontFamily: 'WDXLLubrifontTC'),
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          elevation: 8,
        ),
        dialogTheme: DialogTheme(
          backgroundColor: const Color(0xFF1E1E1E),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'WDXLLubrifontTC'),
          contentTextStyle: const TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'WDXLLubrifontTC'),
        )
      ),
      debugShowCheckedModeBanner: false,
      home: _finalHomeWidget,
    );
  }
}