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

class _AllPdfsScreenState extends State<AllPdfsScreen> with WidgetsBindingObserver {
  List<FileSystemEntity> _pdfFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _permissionInitiallyChecked = false;
  String _currentSearchPath = "Nenhum";

  // INSTANCIAR RecentPdfsService
  final RecentPdfsService _recentPdfsService = RecentPdfsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_permissionInitiallyChecked) {
        _checkAndRequestFullStoragePermission();
      }
    });
  }

  @override
  void dispose() {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissão para gerenciar todos os arquivos ainda é necessária.'),
            backgroundColor: Colors.orange,
          ),
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
        bool? goToSettings = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
                  title: const Text("Permissão Necessária"),
                  content: const Text(
                      "Para listar todos os PDFs em seu dispositivo, este aplicativo precisa da permissão para 'Gerenciar todos os arquivos'.\n\nVocê será redirecionado para as configurações do sistema para concedê-la."),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text("Cancelar")),
                    ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text("Ir para Configurações")),
                  ],
                ));
        
        if (goToSettings == true) {
            await Permission.manageExternalStorage.request();
        } else {
             if(mounted) {
                setState(() => _isLoading = false);
                 ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Permissão cancelada. Não é possível listar todos os PDFs.'),
                    backgroundColor: Colors.grey,
                ),
                );
             }
        }
      } else {
          if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _findPdfFiles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _pdfFiles.clear();
      _currentSearchPath = "Buscando...";
    });
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível determinar diretórios para busca.')),
          );
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
        if (_pdfFiles.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nenhum arquivo PDF encontrado no dispositivo após a varredura.')),
            );
        }
      }

    } catch (e, s) {
      print("AllPdfsScreen: Erro catastrófico ao buscar arquivos: $e\n$s");
      if (mounted) {
        setState(() {
            _isLoading = false;
            _currentSearchPath = "Erro na busca";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar arquivos: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

  List<FileSystemEntity> get _filteredPdfFiles {
    if (_searchQuery.isEmpty) return _pdfFiles;
    return _pdfFiles.where((file) {
      return file.path.split('/').last.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // NOVO MÉTODO: PARA ABRIR PDF E ADICIONAR/ATUALIZAR RECENTES
  Future<void> _openPdfAndUpdateRecents(String filePath, String fileName, int fileSize) async {
    if (!mounted) return;

    // 1. Tenta obter uma senha existente para este arquivo
    // Para isso, precisamos de um RecentPdfItem temporário, pois a chave de senha é baseada nele.
    // O 'originalIdentifier' será null aqui, pois não vem de um FilePicker.
    // O 'lastOpened' não é crucial para buscar a senha, mas é necessário para o construtor.
    final tempItemForPasswordLookup = RecentPdfItem(
        filePath: filePath,
        fileName: fileName,
        originalIdentifier: null, // Não temos do FilePicker aqui
        fileSize: fileSize,
        lastOpened: DateTime.now()); // A data será atualizada ao salvar

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
    if (returnedPassword != null) { // Se algo foi retornado (mesmo string vazia)
      finalPasswordToSave = returnedPassword.isNotEmpty ? returnedPassword : null; // string vazia -> remove senha
    } else { // Se nada foi retornado (usuário cancelou/voltou sem interagir com senha no PdfViewerScreen)
      finalPasswordToSave = existingPassword; // Mantém a senha que já existia
    }

    await _recentPdfsService.addOrUpdateRecentPdf(
      filePath,
      fileName,
      null, // originalIdentifier (não temos do FilePicker aqui)
      fileSize,
      finalPasswordToSave,
    );
    print("AllPdfsScreen: PDF '${fileName}' adicionado/atualizado nos recentes com senha: '${finalPasswordToSave ?? "nenhuma"}'");
    
    // Opcional: Se você quiser que a HomeScreen (Recentes) atualize imediatamente
    // quando o usuário voltar para ela, você precisará de um mecanismo
    // para notificá-la (ex: Provider, Riverpod, ou passando um callback).
    // Por ora, ela atualizará na próxima vez que _loadRecentPdfs for chamado em HomeScreen.
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
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Recarregar Lista",
            onPressed: _isLoading ? null : _checkAndRequestFullStoragePermission,
          )
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Pesquisar pelo nome do arquivo...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            if (_isLoading || (_pdfFiles.isEmpty && _searchQuery.isEmpty)) // Mostrar caminho apenas se carregando ou lista vazia sem filtro
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Text(
                        "Buscando em: ${_currentSearchPath.isNotEmpty ? _currentSearchPath : 'não definido'}",
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                    ),
                ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFFFF6B6B),
                          ),
                          SizedBox(height: 16),
                          Text("Buscando PDFs no dispositivo...", style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    )
                  : _filteredPdfFiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.find_in_page_outlined,
                                size: 80,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? 'Nenhum PDF encontrado' : 'Nenhum PDF encontrado para "$_searchQuery"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              if (_searchQuery.isEmpty && _pdfFiles.isEmpty && _permissionInitiallyChecked)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "Verifique se a permissão 'Gerenciar todos os arquivos' foi concedida.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
                                  ),
                                )
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _filteredPdfFiles.length,
                          itemBuilder: (context, index) {
                            final fileEntity = _filteredPdfFiles[index];
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

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: Colors.white.withOpacity(0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              elevation: 0,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  // CHAMAR O NOVO MÉTODO AQUI
                                  _openPdfAndUpdateRecents(fileEntity.path, fileName, fileSize);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF6B6B).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.picture_as_pdf,
                                          color: Color(0xFFFF6B6B),
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
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
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              fileSize >=0 ? _formatFileSize(fileSize) : "Erro no tamanho",
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.6),
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              fileEntity.path,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.4),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.white30,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}