// pdfish/lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart'; // Adicionado
import 'package:device_info_plus/device_info_plus.dart'; // Adicionado

import 'package:pdfish/screens/home_screen.dart';
import 'package:pdfish/screens/pdf_viewer_screen.dart';
import 'package:pdfish/services/recent_pdfs_service.dart';

void main() async {
  // Garantir que os bindings do Flutter estão inicializados antes de qualquer plugin
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar os dados de formatação de data para pt_BR (Português Brasil)
  await initializeDateFormatting('pt_BR', null);

  // Verificar se o app foi aberto a partir de um arquivo PDF
  final PlatformChannel platformChannelHandler = PlatformChannel(); // Renomeado para evitar conflito de nome
  final String? initialFilePath = await platformChannelHandler.getInitialFilePath();

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

class PdfishApp extends StatefulWidget {
  final String? initialPdfPath;

  const PdfishApp({super.key, this.initialPdfPath});

  @override
  State<PdfishApp> createState() => _PdfishAppState();
}

class _PdfishAppState extends State<PdfishApp> {
  Widget? _finalHomeWidget; // Widget a ser exibido como home
  bool _isLoadingTheme = true; // Para simular carregamento de tema se necessário

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
        setState(() {
          _finalHomeWidget = _buildPdfViewerFromIntent(widget.initialPdfPath!);
          _isLoadingTheme = false;
        });
      } else {
        // Permissão negada para o intent ou arquivo não existe.
        // Redirecionar para HomeScreen.
        // HomeScreen tem sua própria lógica para solicitar permissão na primeira vez que é exibida.
        if (!permissionGranted) {
          print("Main: Permissão negada para abrir o arquivo do intent. Redirecionando para HomeScreen.");
        }
        if (!fileExists) {
          print("Main: Arquivo do intent não encontrado: ${widget.initialPdfPath}. Redirecionando para HomeScreen.");
          // Opcional: Mostrar uma mensagem ao usuário se o arquivo do intent não foi encontrado
          // Isso pode ser feito na HomeScreen ou aqui, se _finalHomeWidget pudesse ser um Scaffold com SnackBar.
        }
        setState(() {
          _finalHomeWidget = const HomeScreen();
          _isLoadingTheme = false;
        });
      }
    } else {
      // Abertura normal do app (sem intent de arquivo)
      // HomeScreen lidará com a solicitação de permissão, se necessário.
      print("Main: Abertura normal do app. Redirecionando para HomeScreen.");
      setState(() {
        _finalHomeWidget = const HomeScreen();
        _isLoadingTheme = false;
      });
    }
  }

  Future<bool> _checkAndRequestStoragePermissionForIntent() async {
    if (!Platform.isAndroid) {
      // Para plataformas não-Android, geralmente não há esse tipo de permissão de armazenamento.
      return true;
    }

    // Lógica específica para Android
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13 (API 33) e superior:
        // Se READ_EXTERNAL_STORAGE tem maxSdkVersion="32", ele não é mais aplicável.
        // O acesso a arquivos via intent do seletor de arquivos do sistema (SAF)
        // concede permissão ao URI específico. Não há um diálogo de permissão de "armazenamento geral"
        // para este caso. A verificação `file.exists()` é a confirmação prática.
        // Se você precisasse de permissões de mídia (READ_MEDIA_IMAGES, etc.), seria diferente.
        print("Main: Android 13+ detectado para abertura via intent. Acesso ao URI específico geralmente concedido pelo sistema.");
        return true; // A existência do arquivo será a verificação principal.
      }
    } catch (e) {
      print("Main: Erro ao obter informações do dispositivo Android: $e. Prosseguindo com a verificação de permissão padrão.");
      // Continuar para a lógica de permissão padrão abaixo.
    }

    // Para Android < 13 ou se a verificação acima falhar
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

    // Registrar o arquivo nos recentes ao abrir via intent.
    // Esta operação é async e não bloqueia a UI.
    Future<void> addRecentPdfAfterIntentOpen() async {
      try {
        // Verifica novamente se o arquivo existe antes de tentar obter o tamanho
        if (await file.exists()) {
          print("Main: Adicionando PDF aos recentes (aberto via intent): $filePath");
          await recentPdfsService.addOrUpdateRecentPdf(
            filePath,
            fileName,
            null, // originalIdentifier (pode ser nulo se não vier de um picker interno)
            await file.length(), // fileSize (agora assíncrono)
            null, // password (inicialmente nulo)
          );
        } else {
          print("Main: Arquivo não encontrado ao tentar adicionar aos recentes (intent): $filePath");
        }
      } catch (e) {
        print("Main: Erro ao adicionar PDF aos recentes (aberto via intent): $e");
        // Considerar logar este erro de forma mais robusta ou notificar o usuário sutilmente se falhar.
      }
    }
    addRecentPdfAfterIntentOpen(); // Dispara a função async

    return PdfViewerScreen(
      filePath: filePath,
      initialPasswordAttempt: null, // PdfViewerScreen pode tentar carregar senhas de recentes
      fromIntent: true, // Indicar que veio de intent externo
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTheme || _finalHomeWidget == null) {
      // Enquanto determina a rota ou carrega algo inicial, mostra um loader.
      // Você pode personalizar esta tela de carregamento.
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
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
          brightness: Brightness.light, // Mude para Brightness.dark para um tema escuro base
        ),
        useMaterial3: true,
        fontFamily: 'WDXLLubrifontTC',
        textTheme: const TextTheme( // Seus estilos de texto personalizados
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
      home: _finalHomeWidget,
    );
  }
}