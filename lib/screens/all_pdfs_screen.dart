// lib/screens/all_pdfs_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfish/screens/pdf_viewer_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
// IMPORTS PARA RECENTES
import 'package:pdfish/services/recent_pdfs_service.dart';
import 'package:pdfish/models/recent_pdf_item.dart'; // Para construir o RecentPdfItem

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
  
  // Controllers para animações
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Controller para busca com debounce
  final TextEditingController _searchController = TextEditingController();
  
  // INSTANCIAR RecentPdfsService
  final RecentPdfsService _recentPdfsService = RecentPdfsService();

  @override
  void initState() {
    super.initState();
    
    // Inicializar animações
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut)
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_permissionInitiallyChecked) {
        _checkAndRequestFullStoragePermission();
      }
    });
    
    // Inicializar lista filtrada
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
    if (state == AppLifecycleState.resumed && _permissionInitiallyChecked) {
      print("AllPdfsScreen: App Resumed. Verificando permissão MANAGE_EXTERNAL_STORAGE novamente.");
      _handlePermissionStatusAfterReturn();
    }
  }

  // Método otimizado para filtrar arquivos
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
    
    // Animar entrada dos resultados
    if (_filteredPdfFiles.isNotEmpty) {
      _slideController.reset();
      _slideController.forward();
    }
  }

  Future<void> _handlePermissionStatusAfterReturn() async {
    if (!Platform.isAndroid) return;
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
      if (mounted) {
        bool? goToSettings = await _showPermissionDialog();
        
        if (goToSettings == true) {
            await Permission.manageExternalStorage.request();
        } else {
             if(mounted) {
                setState(() => _isLoading = false);
                 _showSnackBar(
                  'Permissão cancelada. Não é possível listar todos os PDFs.',
                  color: Colors.grey,
                );
             }
        }
      } else {
          if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<bool?> _showPermissionDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Permissão Necessária",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Para listar todos os PDFs em seu dispositivo, este aplicativo precisa da permissão para 'Gerenciar todos os arquivos'.\n\nVocê será redirecionado para as configurações do sistema para concedê-la.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              "Cancelar",
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              "Ir para Configurações",
              style: TextStyle(color: Colors.white),
            ),
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
        backgroundColor: color ?? const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _findPdfFiles() async {
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
      
      final List<Directory>? externalStorageDirs = await getExternalStorageDirectories();
      if (externalStorageDirs != null && externalStorageDirs.isNotEmpty) {
        for (var dir in externalStorageDirs) {
            print("AllPdfsScreen: getExternalStorageDirectories retornou: ${dir.path}");
            Directory actualDirToScan = dir;
            if (dir.path.contains('/Android/data/')) {
                List<String> segments = dir.path.split('/');
                if (segments.length > 3 && segments[1] == 'storage' && segments[2].startsWith('emulated')) { 
                    actualDirToScan = Directory('/${segments[1]}/${segments[2]}');
                } else if (segments.length > 2 && segments[1] == 'storage' && !segments[2].startsWith('emulated')) { 
                     actualDirToScan = Directory('/${segments[1]}/${segments[2]}');
                }
            }
             print("AllPdfsScreen: Diretório candidato para escaneamento: ${actualDirToScan.path}");
            if (await actualDirToScan.exists() && !dirsToScan.any((d) => d.path == actualDirToScan.path)) {
                dirsToScan.add(actualDirToScan);
            }
        }
      } else {
         print("AllPdfsScreen: getExternalStorageDirectories() retornou nulo ou vazio.");
      }

      Directory downloadDir = Directory('/storage/emulated/0/Download'); 
      if (await downloadDir.exists() && !dirsToScan.any((d) => d.path == downloadDir.path)) {
        print("AllPdfsScreen: Adicionando diretório de Download manualmente: ${downloadDir.path}");
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
           print("AllPdfsScreen: Adicionando raiz do armazenamento primário: ${rootOfPrimary.path}");
           dirsToScan.add(rootOfPrimary);
        }
      }

      if (dirsToScan.isEmpty) {
        print("AllPdfsScreen: Nenhum diretório válido para escanear foi determinado.");
        if (mounted) {
          setState(() {
            _currentSearchPath = "Nenhum diretório de busca";
            _isLoading = false;
          });
          _showSnackBar('Não foi possível determinar diretórios para busca.');
        }
        return;
      }

      print("AllPdfsScreen: Diretórios finais para escaneamento: ${dirsToScan.map((d) => d.path).toList()}");
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

      print("AllPdfsScreen: Busca concluída. Total de ${_pdfFiles.length} PDFs encontrados.");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _updateFilteredFiles();
        
        if (_pdfFiles.isEmpty) {
          _showSnackBar('Nenhum arquivo PDF encontrado no dispositivo após a varredura.');
        } else {
          // Animar entrada dos resultados
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
        _showSnackBar('Erro ao buscar arquivos: $e', color: Colors.red);
      }
    }
  }

  Future<List<FileSystemEntity>> _findPdfFilesInDirectoryRecursive(Directory directory) async {
    final List<FileSystemEntity> pdfFiles = [];
    print("AllPdfsScreen: [RECURSIVE] Iniciando varredura em ${directory.path}");
    int fileCount = 0;
    int dirCount = 0;

    try {
      Stream<FileSystemEntity> entities = directory.list(recursive: true, followLinks: false);
      await for (final entity in entities) {
        if (entity is File) {
          fileCount++;
          _totalFilesScanned++;
          
          // Atualizar UI periodicamente durante a busca
          if (_totalFilesScanned % 100 == 0 && mounted) {
            setState(() {});
          }
          
          if (entity.path.toLowerCase().endsWith('.pdf')) {
            try {
              if (await entity.exists()) {
                  FileStat stat = await entity.stat();
                  if (stat.type == FileSystemEntityType.file && stat.size > 0) {
                    pdfFiles.add(entity);
                  }
              } 
            } catch (e) {
              // Silenciosamente ignora erros de stat para arquivos individuais
            }
          }
        } else if (entity is Directory) {
          dirCount++;
        }
      }
    } on FileSystemException catch (e) {
      print("AllPdfsScreen: [RECURSIVE] Erro FileSystemException ao listar em ${e.path ?? directory.path}: ${e.message}.");
    } catch (e,s) {
      print("AllPdfsScreen: [RECURSIVE] Erro genérico ao listar em ${directory.path}: $e\n$s.");
    }
    
    print("AllPdfsScreen: [RECURSIVE] Concluída varredura em ${directory.path}. PDFs: ${pdfFiles.length}, Arquivos: $fileCount, Dirs: $dirCount");
    return pdfFiles;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // NOVO MÉTODO: PARA ABRIR PDF E ADICIONAR/ATUALIZAR RECENTES
  Future<void> _openPdfAndUpdateRecents(String filePath, String fileName, int fileSize) async {
    if (!mounted) return;

    // 1. Tenta obter uma senha existente para este arquivo
    final tempItemForPasswordLookup = RecentPdfItem(
        filePath: filePath,
        fileName: fileName,
        originalIdentifier: null,
        fileSize: fileSize,
        lastOpened: DateTime.now());

    String? existingPassword = await _recentPdfsService.getPasswordForRecentItem(tempItemForPasswordLookup);
    print("AllPdfsScreen: Para PDF '${fileName}', senha existente no storage: '${existingPassword ?? "nenhuma"}'");

    // 2. Navega para PdfViewerScreen
    final returnedPassword = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          filePath: filePath,
          initialPasswordAttempt: existingPassword,
        ),
      ),
    );

    print("AllPdfsScreen: PdfViewerScreen retornou: '${returnedPassword ?? "null"}' para ${fileName}");

    // 3. Processa o resultado e atualiza os recentes
    String? finalPasswordToSave;
    if (returnedPassword != null) {
      finalPasswordToSave = returnedPassword.isNotEmpty ? returnedPassword : null;
    } else {
      finalPasswordToSave = existingPassword;
    }

    await _recentPdfsService.addOrUpdateRecentPdf(
      filePath,
      fileName,
      null,
      fileSize,
      finalPasswordToSave,
    );
    print("AllPdfsScreen: PDF '${fileName}' adicionado/atualizado nos recentes com senha: '${finalPasswordToSave ?? "nenhuma"}'");
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Pesquisar pelo nome do arquivo...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withOpacity(0.7),
            size: 24,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _updateFilteredFiles();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          _updateFilteredFiles();
        },
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B6B).withOpacity(0.8),
                    const Color(0xFFE53935).withOpacity(0.6),
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Buscando PDFs no dispositivo...",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Arquivos verificados: $_totalFilesScanned",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.find_in_page_rounded,
              size: 60,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? 'Nenhum PDF encontrado' : 'Nenhum PDF encontrado para "$_searchQuery"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          if (_searchQuery.isEmpty && _pdfFiles.isEmpty && _permissionInitiallyChecked)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  "Verifique se a permissão 'Gerenciar todos os arquivos' foi concedida.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfCard(FileSystemEntity fileEntity, int index) {
    late int fileSize;
    try {
       if (fileEntity is File) {
          final fileStat = fileEntity.statSync();
          fileSize = fileStat.size;
       } else {
          fileSize = 0;
       }
    } catch(e) {
        fileSize = -1;
        debugPrint("Erro ao obter statSync para ${fileEntity.path} no build: $e");
    }
    
    final fileName = fileEntity.path.split('/').last;
    final filePath = fileEntity.path;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              splashColor: const Color(0xFFFF6B6B).withOpacity(0.1),
              highlightColor: const Color(0xFFFF6B6B).withOpacity(0.05),
              onTap: () => _openPdfAndUpdateRecents(filePath, fileName, fileSize),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF6B6B).withOpacity(0.8),
                            const Color(0xFFE53935).withOpacity(0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B6B).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  fileSize >= 0 ? _formatFileSize(fileSize) : "Erro",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            filePath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white30,
                        size: 16,
                      ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos os PDFs do Dispositivo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.redAccent,
                Color(0xFFE53935),
                Color(0xFFC62828),
              ],
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: "Recarregar Lista",
              onPressed: _isLoading ? null : _checkAndRequestFullStoragePermission,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF000000),
              Color(0xFF111111),
              Color(0xFF222222),
              Color(0xFF1a1a1a),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Column(
          children: [
            _buildSearchBar(),
            
            if (_isLoading || (_pdfFiles.isEmpty && _searchQuery.isEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        color: Colors.white.withOpacity(0.6),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Buscando em: ${_currentSearchPath.isNotEmpty ? _currentSearchPath : 'não definido'}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Stats bar quando não está carregando e tem arquivos
            if (!_isLoading && _pdfFiles.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF6B6B).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description_rounded,
                          color: const Color(0xFFFF6B6B).withOpacity(0.8),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${_pdfFiles.length} PDFs encontrados",
                          style: TextStyle(
                            color: const Color(0xFFFF6B6B).withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (_searchQuery.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            color: const Color(0xFFFF6B6B).withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${_filteredPdfFiles.length} filtrados",
                            style: TextStyle(
                              color: const Color(0xFFFF6B6B).withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            
            Expanded(
              child: _isLoading
                  ? _buildLoadingWidget()
                  : _filteredPdfFiles.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: _filteredPdfFiles.length,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            return _buildPdfCard(_filteredPdfFiles[index], index);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}