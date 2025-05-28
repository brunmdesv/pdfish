// lib/screens/all_pdfs_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfish/providers/theme_provider.dart'; // IMPORTAR
import 'package:pdfish/screens/pdf_viewer_screen.dart';
import 'package:pdfish/widgets/custom_app_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart'; // IMPORTAR
// IMPORTS PARA RECENTES
import 'package:pdfish/services/recent_pdfs_service.dart';
import 'package:pdfish/models/recent_pdf_item.dart';

class AllPdfsScreen extends StatefulWidget {
  const AllPdfsScreen({super.key});

  @override
  State<AllPdfsScreen> createState() => _AllPdfsScreenState();
}

class _AllPdfsScreenState extends State<AllPdfsScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  List<FileSystemEntity> _pdfFiles = [];
  List<FileSystemEntity> _filteredPdfFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _permissionInitiallyChecked = false;
  String _currentSearchPath = "Nenhum";
  int _totalFilesScanned = 0;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _searchController = TextEditingController();
  final RecentPdfsService _recentPdfsService = RecentPdfsService();

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_permissionInitiallyChecked) { // Adicionado 'mounted'
        _checkAndRequestFullStoragePermission();
      }
    });
    _updateFilteredFiles();
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
    if (mounted && state == AppLifecycleState.resumed && _permissionInitiallyChecked) { // Adicionado 'mounted'
      print("AllPdfsScreen: App Resumed. Verificando permissão MANAGE_EXTERNAL_STORAGE novamente.");
      _handlePermissionStatusAfterReturn();
    }
  }

  void _updateFilteredFiles() {
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
    if (!Platform.isAndroid || !mounted) return; // Adicionado !mounted
    final status = await Permission.manageExternalStorage.status;
    if (status.isGranted) {
      if (_pdfFiles.isEmpty && !_isLoading) {
        print("AllPdfsScreen: Permissão MANAGE_EXTERNAL_STORAGE concedida ao retornar. Iniciando busca de arquivos.");
        _findPdfFiles();
      }
    } else {
      print("AllPdfsScreen: Permissão MANAGE_EXTERNAL_STORAGE ainda não concedida ao retornar.");
      if (mounted && !_isLoading) {
        _showSnackBar(
          'Permissão para gerenciar todos os arquivos ainda é necessária.',
          color: Colors.orange,
        );
      }
    }
  }

  Future<void> _checkAndRequestFullStoragePermission() async {
    if (!mounted) return;
    setState(() {
      _permissionInitiallyChecked = true;
    });

    if (!Platform.isAndroid) {
      print("AllPdfsScreen: Não é Android, assumindo permissão e buscando arquivos.");
      _findPdfFiles();
      return;
    }

    var status = await Permission.manageExternalStorage.status;
    print("AllPdfsScreen: Status inicial de MANAGE_EXTERNAL_STORAGE: $status");

    if (status.isGranted) {
      print("AllPdfsScreen: MANAGE_EXTERNAL_STORAGE já concedido.");
      _findPdfFiles();
    } else {
      print("AllPdfsScreen: MANAGE_EXTERNAL_STORAGE não concedido. Solicitando...");
      if (mounted) { // Garantir que o widget ainda está montado
        bool? goToSettings = await _showPermissionDialog();
        if (goToSettings == true) {
          await Permission.manageExternalStorage.request();
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
            _showSnackBar(
              'Permissão cancelada. Não é possível listar todos os PDFs.',
              color: Colors.grey,
            );
          }
        }
      }
    }
  }

  Future<bool?> _showPermissionDialog() {
    // As cores e estilos do AlertDialog virão do DialogTheme global.
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Permissão Necessária"),
        content: const Text(
          "Para listar todos os PDFs em seu dispositivo, este aplicativo precisa da permissão para 'Gerenciar todos os arquivos'.\n\nVocê será redirecionado para as configurações do sistema para concedê-la.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              "Cancelar",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            // ElevatedButton usará o estilo do ElevatedButtonThemeData
            child: const Text("Ir para Configurações"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? Theme.of(context).colorScheme.error, // Usa a cor de erro do tema
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _findPdfFiles() async {
    // ... (lógica de _findPdfFiles permanece a mesma,
    // mas as saídas de print e a UI de loading já usarão cores do tema)
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _pdfFiles.clear();
      _filteredPdfFiles.clear();
      _currentSearchPath = "Buscando...";
      _totalFilesScanned = 0;
    });
    
    _fadeController.forward();
    print("AllPdfsScreen: Iniciando busca de arquivos PDF...");

    try {
      List<Directory> dirsToScan = [];
      // ... (lógica para determinar dirsToScan)
      final List<Directory>? externalStorageDirs = await getExternalStorageDirectories();
      if (externalStorageDirs != null && externalStorageDirs.isNotEmpty) {
        for (var dir in externalStorageDirs) {
            Directory actualDirToScan = dir;
            if (dir.path.contains('/Android/data/')) {
                List<String> segments = dir.path.split('/');
                if (segments.length > 3 && segments[1] == 'storage' && segments[2].startsWith('emulated')) { 
                    actualDirToScan = Directory('/${segments[1]}/${segments[2]}');
                } else if (segments.length > 2 && segments[1] == 'storage' && !segments[2].startsWith('emulated')) { 
                     actualDirToScan = Directory('/${segments[1]}/${segments[2]}');
                }
            }
            if (await actualDirToScan.exists() && !dirsToScan.any((d) => d.path == actualDirToScan.path)) {
                dirsToScan.add(actualDirToScan);
            }
        }
      }

      Directory downloadDir = Directory('/storage/emulated/0/Download'); 
      if (await downloadDir.exists() && !dirsToScan.any((d) => d.path == downloadDir.path)) {
        dirsToScan.add(downloadDir);
      }
      
      Directory? primaryDir = await getExternalStorageDirectory();
      if (primaryDir != null && await primaryDir.exists()) {
        Directory rootOfPrimary = primaryDir;
        if (primaryDir.path.contains('/Android/data/')) {
            List<String> segments = primaryDir.path.split('/');
            if (segments.length > 3 && segments[1] == 'storage' && segments[2].startsWith('emulated')) { 
                rootOfPrimary = Directory('/${segments[1]}/${segments[2]}');
            }
        }
        if (await rootOfPrimary.exists() && !dirsToScan.any((d) => d.path == rootOfPrimary.path)) {
           dirsToScan.add(rootOfPrimary);
        }
      }

      if (dirsToScan.isEmpty) {
        if (mounted) {
          setState(() {
            _currentSearchPath = "Nenhum diretório de busca";
            _isLoading = false;
          });
          _showSnackBar('Não foi possível determinar diretórios para busca.');
        }
        return;
      }

      if (mounted) {
          setState(() {
            _currentSearchPath = dirsToScan.map((d) => d.path).join(",\n");
          });
      }

      List<Future<List<FileSystemEntity>>> searchFutures = [];
      for (final Directory dirToScan in dirsToScan) {
        searchFutures.add(_findPdfFilesInDirectoryRecursive(dirToScan));
      }

      final List<List<FileSystemEntity>> results = await Future.wait(searchFutures);
      for (final List<FileSystemEntity> resultList in results) {
        _pdfFiles.addAll(resultList);
      }
      
      if (_pdfFiles.isNotEmpty) {
        final seenPaths = <String>{};
        _pdfFiles.retainWhere((file) => seenPaths.add(file.path));
      }

      if (mounted) {
        setState(() { _isLoading = false; });
        _updateFilteredFiles();
        if (_pdfFiles.isEmpty) {
          _showSnackBar('Nenhum arquivo PDF encontrado no dispositivo após a varredura.');
        } else {
          _slideController.forward();
        }
      }

    } catch (e, s) {
      print("AllPdfsScreen: Erro catastrófico ao buscar arquivos: $e\n$s");
      if (mounted) {
        setState(() {
            _isLoading = false;
            _currentSearchPath = "Erro na busca";
        });
        _showSnackBar('Erro ao buscar arquivos: $e', color: Theme.of(context).colorScheme.error);
      }
    }
  }

  Future<List<FileSystemEntity>> _findPdfFilesInDirectoryRecursive(Directory directory) async {
    // ... (lógica de _findPdfFilesInDirectoryRecursive permanece a mesma)
    final List<FileSystemEntity> pdfFiles = [];
    int fileCount = 0;
    int dirCount = 0;

    try {
      Stream<FileSystemEntity> entities = directory.list(recursive: true, followLinks: false);
      await for (final entity in entities) {
        if (entity is File) {
          fileCount++;
          _totalFilesScanned++;
          if (_totalFilesScanned % 100 == 0 && mounted) { setState(() {}); }
          
          if (entity.path.toLowerCase().endsWith('.pdf')) {
            try {
              if (await entity.exists()) {
                  FileStat stat = await entity.stat();
                  if (stat.type == FileSystemEntityType.file && stat.size > 0) {
                    pdfFiles.add(entity);
                  }
              } 
            } catch (e) { /* Silently ignore */ }
          }
        } else if (entity is Directory) {
          dirCount++;
        }
      }
    } catch (e) { /* Silently ignore */ }
    return pdfFiles;
  }

  String _formatFileSize(int bytes) {
    // ... (lógica de _formatFileSize permanece a mesma)
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openPdfAndUpdateRecents(String filePath, String fileName, int fileSize) async {
    // ... (lógica de _openPdfAndUpdateRecents permanece a mesma)
    if (!mounted) return;
    final tempItemForPasswordLookup = RecentPdfItem(
        filePath: filePath, fileName: fileName, originalIdentifier: null,
        fileSize: fileSize, lastOpened: DateTime.now());

    String? existingPassword = await _recentPdfsService.getPasswordForRecentItem(tempItemForPasswordLookup);
    
    final returnedPassword = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          filePath: filePath, initialPasswordAttempt: existingPassword,
        ),
      ),
    );

    String? finalPasswordToSave;
    if (returnedPassword != null) {
      finalPasswordToSave = returnedPassword.isNotEmpty ? returnedPassword : null;
    } else {
      finalPasswordToSave = existingPassword;
    }

    await _recentPdfsService.addOrUpdateRecentPdf(
      filePath, fileName, null, fileSize, finalPasswordToSave,
    );
  }

  Widget _buildSearchBar(ThemeNotifier themeNotifier) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: themeNotifier.cardBackgroundColor, // Usa cor do tema para fundo
        border: Border.all(
          color: themeNotifier.cardBorderColor, // Usa cor do tema para borda
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: themeNotifier.primaryTextColorOnCard, fontSize: 16), // Cor do texto
        decoration: InputDecoration(
          hintText: 'Pesquisar pelo nome do arquivo...',
          // hintStyle, prefixIconColor, suffixIconColor virão do InputDecorationTheme
          prefixIcon: Icon(Icons.search_rounded, size: 24),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _updateFilteredFiles();
                  },
                )
              : null,
          border: InputBorder.none, // Já definido no tema
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _updateFilteredFiles();
        },
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
            Container( // O CircularProgressIndicator já pega a cor do tema
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient( // Mantém o gradiente vermelho para o loader
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6),
                  ],
                ),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.onPrimary, // Cor sobre o primário
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Buscando PDFs no dispositivo...",
              style: TextStyle(
                color: themeNotifier.secondaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Arquivos verificados: $_totalFilesScanned",
              style: TextStyle(
                color: themeNotifier.secondaryTextColor.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
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
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: themeNotifier.cardBackgroundColor,
              border: Border.all(color: themeNotifier.cardBorderColor, width: 1.5)
            ),
            child: Icon(
              Icons.find_in_page_rounded,
              size: 60,
              color: themeNotifier.subtleIconColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? 'Nenhum PDF encontrado' : 'Nenhum PDF encontrado para "$_searchQuery"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: themeNotifier.primaryTextColorOnCard.withOpacity(0.8),
            ),
          ),
          if (_searchQuery.isEmpty && _pdfFiles.isEmpty && _permissionInitiallyChecked)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(themeNotifier.isDarkMode ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(themeNotifier.isDarkMode ? 0.3 : 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  "Verifique se a permissão 'Gerenciar todos os arquivos' foi concedida.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade700.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfCard(FileSystemEntity fileEntity, int index, ThemeNotifier themeNotifier) {
    late int fileSize;
    try {
      fileSize = (fileEntity is File) ? fileEntity.statSync().size : 0;
    } catch (e) {
      fileSize = -1;
    }
    final fileName = fileEntity.path.split('/').last;
    final filePath = fileEntity.path;

    return SlideTransition(
      position: _slideAnimation, // Animações permanecem
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: themeNotifier.cardBackgroundColor,
            border: Border.all(color: themeNotifier.cardBorderColor, width: 1),
            boxShadow: [ // Sombra adaptável
              BoxShadow(
                color: themeNotifier.isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
                blurRadius: themeNotifier.isDarkMode ? 10 : 6,
                offset: Offset(0, themeNotifier.isDarkMode ? 5 : 3),
              ),
            ],
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
                    Container( // Ícone PDF com gradiente primário
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primaryContainer,
                          ],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.picture_as_pdf_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: themeNotifier.primaryTextColorOnCard,
                              fontSize: 16, fontWeight: FontWeight.w600, height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: themeNotifier.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  fileSize >= 0 ? _formatFileSize(fileSize) : "Erro",
                                  style: TextStyle(
                                    color: themeNotifier.secondaryTextColor,
                                    fontSize: 12, fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            filePath, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: themeNotifier.secondaryTextColor.withOpacity(0.6),
                              fontSize: 11, height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: themeNotifier.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                      ),
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
    // Pega o ThemeNotifier do Provider
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      appBar: CustomAppBar(
        titleText: 'Todos os PDFs do Dispositivo',
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 0),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: "Recarregar Lista",
              onPressed: _isLoading ? null : _checkAndRequestFullStoragePermission,
            ),
          ),
        ],
      ),
      body: Container(
        // Usa o gradiente do corpo fornecido pelo ThemeNotifier
        decoration: BoxDecoration(gradient: themeNotifier.bodyGradient),
        child: Column(
          children: [
            _buildSearchBar(themeNotifier), // Passa o themeNotifier
            if (_isLoading || (_pdfFiles.isEmpty && _searchQuery.isEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: themeNotifier.cardBackgroundColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: themeNotifier.cardBorderColor.withOpacity(0.5), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_outlined, color: themeNotifier.subtleIconColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Buscando em: ${_currentSearchPath.isNotEmpty ? _currentSearchPath : 'não definido'}",
                          style: TextStyle(color: themeNotifier.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_isLoading && _pdfFiles.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description_rounded, color: Theme.of(context).colorScheme.primary.withOpacity(0.8), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "${_pdfFiles.length} PDFs encontrados",
                          style: TextStyle(color: Theme.of(context).colorScheme.primary.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (_searchQuery.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.filter_list_rounded, color: Theme.of(context).colorScheme.primary.withOpacity(0.8), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "${_filteredPdfFiles.length} filtrados",
                            style: TextStyle(color: Theme.of(context).colorScheme.primary.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? _buildLoadingWidget(themeNotifier) // Passa o themeNotifier
                  : _filteredPdfFiles.isEmpty
                      ? _buildEmptyState(themeNotifier) // Passa o themeNotifier
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: _filteredPdfFiles.length,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            return _buildPdfCard(_filteredPdfFiles[index], index, themeNotifier); // Passa o themeNotifier
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}