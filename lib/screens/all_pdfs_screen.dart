// lib/screens/all_pdfs_screen.dart
import 'dart:async'; // Para Completer
import 'dart:io';
import 'dart:isolate'; // Para busca em background (opcional, mas bom para o futuro)

import 'package:flutter/foundation.dart'; // Para kDebugMode
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfish/models/recent_pdf_item.dart';
import 'package:pdfish/providers/theme_provider.dart';
import 'package:pdfish/screens/pdf_viewer_screen.dart';
import 'package:pdfish/services/recent_pdfs_service.dart';
import 'package:pdfish/widgets/custom_app_bar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class AllPdfsScreen extends StatefulWidget {
  const AllPdfsScreen({super.key});

  @override
  State<AllPdfsScreen> createState() => _AllPdfsScreenState();
}

class _AllPdfsScreenState extends State<AllPdfsScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  List<File> _pdfFiles = []; // Alterado para List<File> para clareza
  List<File> _filteredPdfFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _permissionInitiallyChecked = false;
  String _currentSearchPathMessage = "Nenhum diretório raiz definido.";
  int _totalFilesScanned = 0;
  int _totalDirectoriesScanned = 0; // Novo contador

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _searchController = TextEditingController();
  final RecentPdfsService _recentPdfsService = RecentPdfsService();
  final Set<String> _processedPaths = {}; // Para evitar re-escanear o mesmo diretório lógico

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _slideController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_permissionInitiallyChecked) {
        _checkAndRequestFullStoragePermission();
      }
    });
    _updateFilteredFiles(); // Inicializa a lista filtrada como vazia
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (mounted && state == AppLifecycleState.resumed && _permissionInitiallyChecked) {
      if (kDebugMode) print("AllPdfsScreen: App Resumed. Verificando permissão MANAGE_EXTERNAL_STORAGE novamente.");
      _handlePermissionStatusAfterReturn();
    }
  }

  void _updateFilteredFiles() {
    if (!mounted) return;
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredPdfFiles = List.from(_pdfFiles);
      } else {
        final query = _searchQuery.toLowerCase();
        _filteredPdfFiles = _pdfFiles.where((file) {
          final fileName = file.path.split('/').last.toLowerCase();
          return fileName.contains(query);
        }).toList();
      }
    });

    if (_filteredPdfFiles.isNotEmpty) {
      _slideController.reset();
      _slideController.forward();
    }
  }

  Future<void> _handlePermissionStatusAfterReturn() async {
    if (!Platform.isAndroid || !mounted) return;
    final status = await Permission.manageExternalStorage.status;
    if (status.isGranted) {
      if (_pdfFiles.isEmpty && !_isLoading) {
        if (kDebugMode) print("AllPdfsScreen: Permissão MANAGE_EXTERNAL_STORAGE concedida ao retornar. Iniciando busca de arquivos.");
        _initiateFileSearch();
      }
    } else {
      if (kDebugMode) print("AllPdfsScreen: Permissão MANAGE_EXTERNAL_STORAGE ainda não concedida ao retornar.");
      if (mounted && !_isLoading) {
        _showSnackBar('Permissão para gerenciar todos os arquivos ainda é necessária.', color: Colors.orange);
      }
    }
  }

  Future<void> _checkAndRequestFullStoragePermission() async {
    if (!mounted) return;
    setState(() { _permissionInitiallyChecked = true; });

    if (!Platform.isAndroid) {
      if (kDebugMode) print("AllPdfsScreen: Não é Android, assumindo permissão e buscando arquivos.");
      _initiateFileSearch();
      return;
    }

    var status = await Permission.manageExternalStorage.status;
    if (kDebugMode) print("AllPdfsScreen: Status inicial de MANAGE_EXTERNAL_STORAGE: $status");

    if (status.isGranted) {
      if (kDebugMode) print("AllPdfsScreen: MANAGE_EXTERNAL_STORAGE já concedido.");
      _initiateFileSearch();
    } else {
      if (kDebugMode) print("AllPdfsScreen: MANAGE_EXTERNAL_STORAGE não concedido. Solicitando...");
      if (mounted) {
        bool? goToSettings = await _showPermissionDialog();
        if (goToSettings == true) {
          await Permission.manageExternalStorage.request();
          // A verificação do status ocorrerá em didChangeAppLifecycleState ao retornar das configurações
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
            _showSnackBar('Permissão cancelada. Não é possível listar todos os PDFs.', color: Colors.grey);
          }
        }
      }
    }
  }

  Future<bool?> _showPermissionDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Permissão Necessária"),
        content: const Text("Para listar todos os PDFs em seu dispositivo, este aplicativo precisa da permissão para 'Gerenciar todos os arquivos'.\n\nVocê será redirecionado para as configurações do sistema para concedê-la."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("Cancelar", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)))),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Ir para Configurações")),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<List<Directory>> _getScanDirectories() async {
    final List<Directory> directories = [];
    _processedPaths.clear(); // Limpa paths processados para nova busca

    // 1. External storage directories (primary and SD cards)
    final List<Directory>? extStorageDirs = await getExternalStorageDirectories();
    if (kDebugMode) print("AllPdfsScreen: Raw externalStorageDirs: ${extStorageDirs?.map((d) => d.path).toList()}");
    if (extStorageDirs != null) {
      for (final dir in extStorageDirs) {
        String path = dir.path;
        // Tenta normalizar para a raiz do volume, removendo subpastas específicas do app
        if (path.contains('/Android/data/')) {
          path = path.substring(0, path.indexOf('/Android/data/'));
        } else if (path.contains('/Android/obb/')) {
          path = path.substring(0, path.indexOf('/Android/obb/'));
        }
        final Directory rootDir = Directory(path);
        if (await rootDir.exists() && !_processedPaths.contains(rootDir.path)) {
          directories.add(rootDir);
          _processedPaths.add(rootDir.path);
          if (kDebugMode) print("AllPdfsScreen: Added scan directory (from extStorageDirs processed): ${rootDir.path}");
        } else if (await dir.exists() && !_processedPaths.contains(dir.path)){
           // Fallback para o caminho original se o processamento falhar ou já for raiz
          directories.add(dir);
          _processedPaths.add(dir.path);
          if (kDebugMode) print("AllPdfsScreen: Added scan directory (from extStorageDirs original): ${dir.path}");
        }
      }
    }

    // 2. Primary external storage (geralmente /storage/emulated/0)
    //    Isso pode já estar coberto por extStorageDirs, mas adicionamos como fallback
    //    ou para garantir que a raiz principal seja escaneada.
    try {
      final Directory? primaryExtStorage = await getExternalStorageDirectory(); // Diretório específico do app
      if (primaryExtStorage != null) {
          String path = primaryExtStorage.path;
           if (path.contains('/Android/data/')) { // Ir para a raiz do volume
             path = path.substring(0, path.indexOf('/Android/data/'));
           }
          final Directory rootPrimary = Directory(path);
          if (await rootPrimary.exists() && !_processedPaths.contains(rootPrimary.path)) {
            directories.add(rootPrimary);
            _processedPaths.add(rootPrimary.path);
            if (kDebugMode) print("AllPdfsScreen: Added scan directory (primary root): ${rootPrimary.path}");
          }
      }
    } catch (e) {
       if (kDebugMode) print("AllPdfsScreen: Error getting primary external storage root: $e");
    }


    // 3. Download directory (comum para PDFs)
    //    No Android Q+, pode precisar de SAF para acesso irrestrito, mas MANAGE_EXTERNAL_STORAGE deve ajudar.
    final String downloadDirPath = '/storage/emulated/0/Download';
    final Directory downloadDir = Directory(downloadDirPath);
    if (await downloadDir.exists() && !_processedPaths.contains(downloadDir.path)) {
      directories.add(downloadDir);
      _processedPaths.add(downloadDir.path);
      if (kDebugMode) print("AllPdfsScreen: Added scan directory (Download): ${downloadDir.path}");
    }
    
    // Adicionar outros diretórios comuns se necessário, e.g., /storage/emulated/0/Documents
    final String documentsDirPath = '/storage/emulated/0/Documents';
    final Directory documentsDir = Directory(documentsDirPath);
    if (await documentsDir.exists() && !_processedPaths.contains(documentsDir.path)) {
      directories.add(documentsDir);
      _processedPaths.add(documentsDir.path);
      if (kDebugMode) print("AllPdfsScreen: Added scan directory (Documents): ${documentsDir.path}");
    }


    if (kDebugMode) print("AllPdfsScreen: Final list of directories to scan: ${directories.map((d) => d.path).toList()}");
    return directories.isEmpty ? [Directory('/storage/emulated/0/')] : directories; // Fallback para raiz se nada for encontrado
  }

  Future<void> _initiateFileSearch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _pdfFiles.clear();
      _filteredPdfFiles.clear();
      _currentSearchPathMessage = "Determinando diretórios de busca...";
      _totalFilesScanned = 0;
      _totalDirectoriesScanned = 0;
    });
    _fadeController.reset(); // Para animar o loader
    _fadeController.forward();

    try {
      List<Directory> dirsToScan = await _getScanDirectories();

      if (dirsToScan.isEmpty) {
        if (mounted) {
          setState(() {
            _currentSearchPathMessage = "Nenhum diretório de busca válido encontrado.";
            _isLoading = false;
          });
          _showSnackBar('Não foi possível determinar diretórios para busca. Verifique as permissões.');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _currentSearchPathMessage = "Buscando em:\n${dirsToScan.map((d) => d.path.length > 40 ? "...${d.path.substring(d.path.length - 37)}" : d.path).join('\n')}";
        });
      }

      List<File> allFoundPdfs = [];
      for (final Directory dirToScan in dirsToScan) {
        if (!mounted) break; // Verifica se o widget ainda está montado durante o loop longo
        if (kDebugMode) print("AllPdfsScreen: Iniciando varredura recursiva em: ${dirToScan.path}");
        List<File> filesInDir = await _findPdfFilesInDirectoryRecursive(dirToScan);
        allFoundPdfs.addAll(filesInDir);
        // Remove duplicatas por caminho após cada diretório raiz para evitar crescimento excessivo da lista em memória
        if (allFoundPdfs.isNotEmpty) {
            final seenPaths = <String>{};
            allFoundPdfs.retainWhere((file) => seenPaths.add(file.path));
        }
         if (kDebugMode) print("AllPdfsScreen: PDFs encontrados até agora após ${dirToScan.path}: ${allFoundPdfs.length}");
      }

      if (mounted) {
        _pdfFiles = allFoundPdfs;
        _updateFilteredFiles(); // Atualiza a lista filtrada e a UI
        setState(() { _isLoading = false; });
        if (_pdfFiles.isEmpty) {
          _showSnackBar('Nenhum arquivo PDF encontrado no dispositivo após a varredura.');
        } else {
          _slideController.forward(); // Anima a entrada da lista
        }
      }
    } catch (e, s) {
      if (kDebugMode) print("AllPdfsScreen: Erro catastrófico durante a busca de arquivos: $e\n$s");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentSearchPathMessage = "Erro durante a busca.";
        });
        _showSnackBar('Ocorreu um erro ao buscar arquivos: ${e.toString()}', color: Theme.of(context).colorScheme.error);
      }
    }
  }

  Future<List<File>> _findPdfFilesInDirectoryRecursive(Directory directory) async {
    final List<File> foundPdfFiles = [];
    if (!mounted) return foundPdfFiles; // Verifica antes de iniciar

    _totalDirectoriesScanned++;
    if (_totalDirectoriesScanned % 20 == 0 && mounted) { // Atualiza a UI com menos frequência
        // print("AllPdfsScreen: Dirs scanned: $_totalDirectoriesScanned, Files checked: $_totalFilesScanned");
        setState(() {}); // Para atualizar contadores na UI
    }

    Stream<FileSystemEntity>? entitiesStream;
    try {
      entitiesStream = directory.list(recursive: false, followLinks: false); // Não recursivo aqui, controlamos a recursão
      await for (final entity in entitiesStream) {
        if (!mounted) break; 

        if (entity is File) {
          _totalFilesScanned++;
          if (entity.path.toLowerCase().endsWith('.pdf')) {
            try {
              // Verificações básicas para validar o arquivo PDF
              if (await entity.exists() && (await entity.length()) > 0) { // Verifica tamanho > 0
                foundPdfFiles.add(entity);
              }
            } catch (eFileStat) {
              if (kDebugMode) print("AllPdfsScreen: Erro (stat/length) em ${entity.path}: $eFileStat. Ignorando arquivo.");
            }
          }
        } else if (entity is Directory) {
          // Chamada recursiva para subdiretórios
          // Verifica se o caminho já foi processado para evitar loops ou trabalho redundante (embora followLinks:false ajude)
          if (!_processedPaths.contains(entity.path)) {
            _processedPaths.add(entity.path); // Adiciona antes da chamada recursiva
             try {
                foundPdfFiles.addAll(await _findPdfFilesInDirectoryRecursive(entity));
             } catch (eSubDir) {
                 if (kDebugMode) print("AllPdfsScreen: Erro ao processar subdiretório ${entity.path}: $eSubDir. Ignorando este sub-ramo.");
             }
          } else {
             // if (kDebugMode) print("AllPdfsScreen: Subdiretório ${entity.path} já processado ou na lista de raízes. Pulando.");
          }
        }
      }
    } on FileSystemException catch (e) {
      // Erro ao listar o diretório atual (ex: permissão negada para este diretório específico)
      if (kDebugMode) print("AllPdfsScreen: FileSystemException ao listar ${directory.path}: ${e.osError?.message ?? e.message}. Ignorando este diretório.");
    } catch (e, s) {
      // Erro inesperado
      if (kDebugMode) print("AllPdfsScreen: Erro inesperado em ${directory.path}: $e\n$s. Ignorando este diretório.");
    }
    return foundPdfFiles;
  }


  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }

  Future<void> _openPdfAndUpdateRecents(String filePath, String fileName, int fileSize) async {
    if (!mounted) return;
    final tempItemForPasswordLookup = RecentPdfItem(filePath: filePath, fileName: fileName, originalIdentifier: null, fileSize: fileSize, lastOpened: DateTime.now());
    String? existingPassword = await _recentPdfsService.getPasswordForRecentItem(tempItemForPasswordLookup);
    
    final returnedPassword = await Navigator.push<String?>(context, MaterialPageRoute(builder: (context) => PdfViewerScreen(filePath: filePath, initialPasswordAttempt: existingPassword)));
    String? finalPasswordToSave = (returnedPassword != null && returnedPassword.isNotEmpty) ? returnedPassword : existingPassword;
    await _recentPdfsService.addOrUpdateRecentPdf(filePath, fileName, null, fileSize, finalPasswordToSave);
  }

  Widget _buildSearchBar(ThemeNotifier themeNotifier) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: themeNotifier.cardBackgroundColor,
        border: Border.all(color: themeNotifier.cardBorderColor, width: 1),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: themeNotifier.primaryTextColorOnCard, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Pesquisar pelo nome do arquivo...',
          prefixIcon: const Icon(Icons.search_rounded, size: 24), // Cor virá do InputDecorationTheme
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); _updateFilteredFiles(); })
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onChanged: (value) { setState(() => _searchQuery = value); _updateFilteredFiles(); },
      ),
    );
  }

  Widget _buildLoadingWidget(ThemeNotifier themeNotifier) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary.withOpacity(0.8), Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6)]),
              ),
              child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 3)),
            ),
            const SizedBox(height: 24),
            Text("Buscando PDFs no dispositivo...", style: TextStyle(color: themeNotifier.secondaryTextColor, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text("Diretórios: $_totalDirectoriesScanned | Arquivos: $_totalFilesScanned", style: TextStyle(color: themeNotifier.secondaryTextColor.withOpacity(0.7), fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeNotifier themeNotifier) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle, color: themeNotifier.cardBackgroundColor, border: Border.all(color: themeNotifier.cardBorderColor, width: 1.5)),
            child: Icon(Icons.find_in_page_rounded, size: 60, color: themeNotifier.subtleIconColor),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? 'Nenhum PDF encontrado' : 'Nenhum PDF encontrado para "$_searchQuery"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: themeNotifier.primaryTextColorOnCard.withOpacity(0.8)),
          ),
          if (_searchQuery.isEmpty && _pdfFiles.isEmpty && _permissionInitiallyChecked)
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(themeNotifier.isDarkMode ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(themeNotifier.isDarkMode ? 0.3 : 0.2), width: 1),
                ),
                child: Text(
                  "Verifique se a permissão 'Gerenciar todos os arquivos' foi concedida ou tente recarregar a lista.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.orange.shade700.withOpacity(0.9), fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfCard(File fileEntity, int index, ThemeNotifier themeNotifier) { // Alterado para File
    late int fileSize;
    try {
      fileSize = fileEntity.lengthSync(); // Mais simples se já é um File
    } catch (e) {
      fileSize = -1;
      if (kDebugMode) print("AllPdfsScreen: Erro ao obter lengthSync para ${fileEntity.path}: $e");
    }
    final fileName = fileEntity.path.split('/').last;
    final filePath = fileEntity.path;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation, // Deve ser _slideController para os itens da lista ou uma nova animação de item
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: themeNotifier.cardBackgroundColor,
            border: Border.all(color: themeNotifier.cardBorderColor, width: 1),
            boxShadow: [BoxShadow(color: themeNotifier.isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.15), blurRadius: themeNotifier.isDarkMode ? 10 : 6, offset: Offset(0, themeNotifier.isDarkMode ? 5 : 3))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              onTap: () => _openPdfAndUpdateRecents(filePath, fileName, fileSize),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Icon(Icons.picture_as_pdf_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fileName, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: themeNotifier.primaryTextColorOnCard, fontSize: 16, fontWeight: FontWeight.w600, height: 1.3)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: themeNotifier.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                                child: Text(fileSize >= 0 ? _formatFileSize(fileSize) : "Erro", style: TextStyle(color: themeNotifier.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(filePath, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: themeNotifier.secondaryTextColor.withOpacity(0.6), fontSize: 11, height: 1.2)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: themeNotifier.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                      child: Icon(Icons.arrow_forward_ios_rounded, color: themeNotifier.subtleIconColor.withOpacity(0.5), size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      appBar: CustomAppBar(
        titleText: 'Todos os PDFs do Dispositivo',
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: "Recarregar Lista", onPressed: _isLoading ? null : _initiateFileSearch)], // Alterado para _initiateFileSearch
      ),
      body: Container(
        decoration: BoxDecoration(gradient: themeNotifier.bodyGradient),
        child: Column(
          children: [
            _buildSearchBar(themeNotifier),
            if (_isLoading || (_pdfFiles.isEmpty && _searchQuery.isEmpty && _permissionInitiallyChecked)) // Adicionado _permissionInitiallyChecked
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: themeNotifier.cardBackgroundColor.withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: themeNotifier.cardBorderColor.withOpacity(0.5), width: 1)),
                  child: Row(
                    children: [
                      Icon(Icons.manage_search_outlined, color: themeNotifier.subtleIconColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_currentSearchPathMessage, style: TextStyle(color: themeNotifier.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 3, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ),
            if (!_isLoading && _pdfFiles.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 1)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [Icon(Icons.description_rounded, color: Theme.of(context).colorScheme.primary.withOpacity(0.8), size: 16), const SizedBox(width: 8), Text("${_pdfFiles.length} PDFs encontrados", style: TextStyle(color: Theme.of(context).colorScheme.primary.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600))]),
                    if (_searchQuery.isNotEmpty)
                      Row(children: [Icon(Icons.filter_list_rounded, color: Theme.of(context).colorScheme.primary.withOpacity(0.8), size: 16), const SizedBox(width: 4), Text("${_filteredPdfFiles.length} filtrados", style: TextStyle(color: Theme.of(context).colorScheme.primary.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600))]),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? _buildLoadingWidget(themeNotifier)
                  : _filteredPdfFiles.isEmpty
                      ? _buildEmptyState(themeNotifier)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: _filteredPdfFiles.length,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            return _buildPdfCard(_filteredPdfFiles[index], index, themeNotifier);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}