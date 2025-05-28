// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdfish/providers/theme_provider.dart';
import 'package:pdfish/themes/app_themes.dart';
import 'package:provider/provider.dart';

// Seus imports de telas
import 'package:pdfish/screens/main_layout_screen.dart';
import 'package:pdfish/screens/pdf_viewer_screen.dart';
import 'package:pdfish/services/recent_pdfs_service.dart'; // Embora não usado diretamente aqui, bom manter se PdfViewerScreen usa

// Imports de permissão e device_info
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  final PlatformChannel platformChannelHandler = PlatformChannel();
  final String? initialFilePath = await platformChannelHandler.getInitialFilePath();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: PdfishApp(initialPdfPath: initialFilePath),
    ),
  );
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

class PdfishApp extends StatefulWidget {
  final String? initialPdfPath;

  const PdfishApp({super.key, this.initialPdfPath});

  @override
  State<PdfishApp> createState() => _PdfishAppState();
}

class _PdfishAppState extends State<PdfishApp> {
  Widget? _finalHomeWidget;
  bool _isLoadingInitialSetup = true; // Nome da variável corrigido

  @override
  void initState() {
    super.initState();
    _determineInitialRoute();
  }

  Future<void> _determineInitialRoute() async {
    if (widget.initialPdfPath != null && widget.initialPdfPath!.isNotEmpty) {
      // App aberto via intent com um caminho de arquivo
      bool permissionGranted = await _checkAndRequestStoragePermissionForIntent();
      File file = File(widget.initialPdfPath!);
      bool fileExists = await file.exists();

      if (permissionGranted && fileExists) {
        // Permissão concedida e arquivo existe, mostrar o visualizador
        print("Main: Permissão OK e arquivo existe. Abrindo PDFViewerScreen para: ${widget.initialPdfPath}");
        if (mounted) {
          setState(() {
            _finalHomeWidget = _buildPdfViewerFromIntent(widget.initialPdfPath!);
            // _isLoadingInitialSetup será setado para false no final
          });
        }
      } else {
        // Permissão negada para o intent ou arquivo não existe.
        // Redirecionar para MainLayoutScreen.
        if (!permissionGranted) {
          print("Main: Permissão negada para abrir o arquivo do intent. Redirecionando para MainLayoutScreen.");
        }
        if (!fileExists) {
          print("Main: Arquivo do intent não encontrado: ${widget.initialPdfPath}. Redirecionando para MainLayoutScreen.");
        }
        if (mounted) {
          setState(() {
            _finalHomeWidget = const MainLayoutScreen();
             // _isLoadingInitialSetup será setado para false no final
          });
        }
      }
    } else {
      // Abertura normal do app (sem intent de arquivo)
      print("Main: Abertura normal do app. Redirecionando para MainLayoutScreen.");
      if (mounted) {
        setState(() {
          _finalHomeWidget = const MainLayoutScreen();
           // _isLoadingInitialSetup será setado para false no final
        });
      }
    }

    // Esta linha deve ser alcançada em todos os caminhos lógicos dentro de _determineInitialRoute
    // e após qualquer setState que defina _finalHomeWidget.
    if (mounted) {
      setState(() {
        _isLoadingInitialSetup = false;
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

  // Método para construir o PdfViewerScreen quando o app é aberto a partir de um arquivo PDF
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
            null, // originalIdentifier
            await file.length(), // fileSize
            null, // password
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
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    if (_isLoadingInitialSetup || _finalHomeWidget == null) { // Variável correta usada aqui
      // Tela de carregamento inicial, antes mesmo do MaterialApp estar totalmente configurado
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeNotifier.themeMode,
        theme: AppThemes.lightTheme, // Define o tema claro como base
        darkTheme: AppThemes.darkTheme, // Define o tema escuro
        home: Scaffold(
          // A cor de fundo do Scaffold será definida pelo tema claro/escuro
          // e pelo scaffoldBackgroundColor definido em AppThemes
          body: Center(
            child: CircularProgressIndicator(
              // A cor do indicator virá do tema (ProgressIndicatorThemeData)
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'PDFish',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeNotifier.themeMode,
      debugShowCheckedModeBanner: false,
      home: _finalHomeWidget,
    );
  }
}