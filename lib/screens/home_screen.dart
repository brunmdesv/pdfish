// lib/screens/home_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdfish/screens/pdf_viewer_screen.dart';
import 'package:pdfish/models/recent_pdf_item.dart';
import 'package:pdfish/services/recent_pdfs_service.dart';
import 'package:pdfish/widgets/custom_app_bar.dart';

// Imports para permissão
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final RecentPdfsService _recentPdfsService = RecentPdfsService();
  List<RecentPdfItem> _recentPdfsList = [];
  bool _isLoadingRecents = true;
  bool _initialPermissionCheckDone = false;

  late AnimationController _fabController;
  late AnimationController _listController;
  late Animation<double> _fabAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadRecentPdfs();

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _listController, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _fabController.forward();
        _listController.forward();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestManageStoragePermissionIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fabController.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _initialPermissionCheckDone) {
      print("HomeScreen: App Resumed. Verificando status de MANAGE_EXTERNAL_STORAGE e recarregando recentes.");
      _checkManageStoragePermissionStatus(showDialogIfNeeded: false);
      _loadRecentPdfs(); // Recarrega recentes ao voltar para o app
    }
  }

  Future<void> _checkAndRequestManageStoragePermissionIfNeeded() async {
    if (_initialPermissionCheckDone || !Platform.isAndroid) {
      if (!Platform.isAndroid) setState(() => _initialPermissionCheckDone = true);
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool manageStorageDialogShownV1 = prefs.getBool('manage_storage_dialog_shown_v1') ?? false;

    var status = await Permission.manageExternalStorage.status;
    print("HomeScreen: Status inicial de MANAGE_EXTERNAL_STORAGE: $status");

    if (!status.isGranted && !manageStorageDialogShownV1) {
      if (mounted) {
        await _showManageStoragePermissionDialog();
        await prefs.setBool('manage_storage_dialog_shown_v1', true);
        status = await Permission.manageExternalStorage.status;
        if (status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Acesso a todos os arquivos concedido!')),
            );
          }
        }
      }
    } else if (status.isGranted) {
      print("HomeScreen: MANAGE_EXTERNAL_STORAGE já estava concedido.");
    }

    if (mounted) {
      setState(() {
        _initialPermissionCheckDone = true;
      });
    }
  }

  Future<void> _showManageStoragePermissionDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          // Estilos virão do DialogTheme no MaterialApp
          title: const Text('Permissão Importante'),
          content: const Text(
              'Para que o PDFish possa listar todos os seus documentos PDF no dispositivo (na tela "Todos os PDFs") e, futuramente, permitir edição, precisamos que você conceda a permissão de "Acesso para gerenciar todos os arquivos" nas configurações do sistema.\n\nEste acesso é fundamental para essas funcionalidades.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Agora não'),
              onPressed: () {
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('A funcionalidade "Todos os PDFs" pode ser limitada.')),
                  );
                }
              },
            ),
            ElevatedButton(
              child: const Text('Conceder Permissão'),
              onPressed: () async {
                Navigator.of(context).pop();
                await Permission.manageExternalStorage.request();
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkManageStoragePermissionStatus({bool showDialogIfNeeded = true}) async {
    if (!Platform.isAndroid) return true;

    var status = await Permission.manageExternalStorage.status;
    print("HomeScreen: Verificando status de MANAGE_EXTERNAL_STORAGE: $status");

    if (status.isGranted) {
      return true;
    } else {
      if (mounted && showDialogIfNeeded) {
        await _showManageStoragePermissionDialog();
        status = await Permission.manageExternalStorage.status;
        return status.isGranted;
      }
      return false;
    }
  }

  Future<void> _loadRecentPdfs() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRecents = true;
    });
    try {
      final recents = await _recentPdfsService.getRecentPdfs();
      if (mounted) {
        setState(() {
          _recentPdfsList = recents;
          _isLoadingRecents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRecents = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar PDFs recentes: $e'),
            backgroundColor: const Color(0xFFFF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      print("Erro ao carregar recentes: $e");
    }
  }

  Future<void> _openPdfViewer(RecentPdfItem itemToOpen, {String? knownPassword}) async {
    String? passwordForViewer = knownPassword;
    if (passwordForViewer == null || passwordForViewer.isEmpty) {
      passwordForViewer = await _recentPdfsService.getPasswordForRecentItem(itemToOpen);
      print("HomeScreen: Carregada senha '${passwordForViewer ?? "nenhuma"}' do secure storage para ${itemToOpen.fileName}");
    } else {
      print("HomeScreen: Usando senha conhecida '$passwordForViewer' para ${itemToOpen.fileName}");
    }

    if (mounted) {
      final returnedPassword = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            filePath: itemToOpen.filePath,
            initialPasswordAttempt: passwordForViewer,
          ),
        ),
      );

      print("HomeScreen: PdfViewerScreen retornou: '${returnedPassword ?? "null"}' para ${itemToOpen.fileName}");

      String? finalPasswordToSave;
      if (returnedPassword != null) {
        finalPasswordToSave = returnedPassword.isNotEmpty ? returnedPassword : null;
      } else {
        finalPasswordToSave = passwordForViewer;
      }

      await _recentPdfsService.addOrUpdateRecentPdf(
        itemToOpen.filePath,
        itemToOpen.fileName,
        itemToOpen.originalIdentifier,
        itemToOpen.fileSize,
        finalPasswordToSave,
      );
      await _loadRecentPdfs();
    }
  }

  Future<void> _pickAndOpenPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final PlatformFile file = result.files.single;

        final tempItemForInfo = RecentPdfItem(
            filePath: file.path!,
            fileName: file.name,
            originalIdentifier: file.identifier,
            fileSize: file.size,
            lastOpened: DateTime.now());

        String? existingPassword = await _recentPdfsService.getPasswordForRecentItem(tempItemForInfo);
        print("HomeScreen: Para PDF do picker '${file.name}', senha existente no storage: '${existingPassword ?? "nenhuma"}'");

        if (mounted) {
          final returnedPassword = await Navigator.push<String?>(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerScreen(
                filePath: tempItemForInfo.filePath,
                initialPasswordAttempt: existingPassword,
              ),
            ),
          );

          print("HomeScreen: PdfViewerScreen (após picker) retornou: '${returnedPassword ?? "null"}' para ${file.name}");

          String? finalPasswordToSave;
          if (returnedPassword != null) {
            finalPasswordToSave = returnedPassword.isNotEmpty ? returnedPassword : null;
          } else {
            finalPasswordToSave = existingPassword;
          }

          await _recentPdfsService.addOrUpdateRecentPdf(
            tempItemForInfo.filePath,
            tempItemForInfo.fileName,
            tempItemForInfo.originalIdentifier,
            tempItemForInfo.fileSize,
            finalPasswordToSave,
          );
          await _loadRecentPdfs();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Nenhum arquivo PDF selecionado.'),
              backgroundColor: const Color(0xFFFF9500),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar o arquivo: $e'),
            backgroundColor: const Color(0xFFFF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      print("Erro ao selecionar arquivo: $e");
    }
  }

  String _formatRecentDate(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Agora mesmo';
        }
        return 'Há ${difference.inMinutes}min';
      }
      return 'Há ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 7) {
      return 'Há ${difference.inDays} dias';
    } else {
      return DateFormat('dd/MM/yyyy', 'pt_BR').format(dt);
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Tamanho desconhecido';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar( // USANDO O CUSTOM APPBAR
      titleText: 'Documentos Recentes',
      actions: [
        // Apenas mostra o botão de limpar se houver recentes e não estiver carregando
        if (_recentPdfsList.isNotEmpty && !_isLoadingRecents)
          Container(
            margin: const EdgeInsets.only(right: 8.0), // Adiciona uma pequena margem à direita
            child: IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 24), // Cor virá do tema
              tooltip: 'Limpar Todos os Recentes',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  barrierColor: Colors.black.withOpacity(0.8),
                  builder: (BuildContext context) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9500).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9500)),
                          ),
                          const SizedBox(width: 12),
                          const Text('Limpar Recentes?'),
                        ],
                      ),
                      content: const Text(
                        'Isso removerá todos os PDFs da lista e suas senhas salvas.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Limpar Tudo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            onPressed: () => Navigator.of(context).pop(true),
                          ),
                        ),
                      ],
                    );
                  },
                );
                if (confirm == true) {
                  await _recentPdfsService.clearAllRecentPdfs();
                  _loadRecentPdfs();
                }
              },
            ),
          ),
      ],
    ),
      // DRAWER FOI REMOVIDO
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
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 5),
              if (!_initialPermissionCheckDone && Platform.isAndroid)
                const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.redAccent))),
              if (_initialPermissionCheckDone || !Platform.isAndroid)
                Expanded(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _listController,
                      child: _isLoadingRecents
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFFF6B6B),
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Carregando seus documentos...',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _recentPdfsList.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(40.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFFFF6B6B).withOpacity(0.2),
                                                const Color(0xFFFF8E53).withOpacity(0.1),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFFFF6B6B).withOpacity(0.3),
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.folder_open_outlined,
                                            size: 60,
                                            color: Color(0xFFFF6B6B),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        const Text(
                                          'Nenhum documento ainda',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'Comece sua jornada selecionando um arquivo PDF do seu dispositivo. Seus documentos aparecerão aqui para acesso rápido.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white.withOpacity(0.7),
                                            height: 1.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(24, 5, 24, 120), // Espaço para o FAB
                                  itemCount: _recentPdfsList.length,
                                  itemBuilder: (context, index) {
                                    final recentItem = _recentPdfsList[index];
                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: Duration(milliseconds: 300 + (index * 100)),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, child) {
                                        return Transform.translate(
                                          offset: Offset(0, 30 * (1 - value)),
                                          child: Opacity(
                                            opacity: value,
                                            child: Container(
                                              margin: const EdgeInsets.only(bottom: 16),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white.withOpacity(0.1),
                                                    Colors.white.withOpacity(0.05),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.1),
                                                  width: 1,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.3),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(20),
                                                  onTap: () async {
                                                    final file = File(recentItem.filePath);
                                                    if (await file.exists()) {
                                                      _openPdfViewer(recentItem);
                                                    } else {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('Arquivo "${recentItem.fileName}" não encontrado no cache ou local original.'),
                                                            backgroundColor: const Color(0xFFFF9500),
                                                            behavior: SnackBarBehavior.floating,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                            margin: const EdgeInsets.all(16),
                                                            action: SnackBarAction(
                                                              label: 'REMOVER',
                                                              textColor: Colors.white,
                                                              onPressed: () async {
                                                                await _recentPdfsService.removeSpecificRecent(recentItem);
                                                                _loadRecentPdfs();
                                                              },
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                recentItem.fileName,
                                                                maxLines: 2,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: Colors.white,
                                                                  letterSpacing: -0.2,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 8),
                                                              Row(
                                                                children: [
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                    decoration: BoxDecoration(
                                                                      color: const Color(0xFFFF6B6B).withOpacity(0.2),
                                                                      borderRadius: BorderRadius.circular(8),
                                                                    ),
                                                                    child: Text(
                                                                      _formatRecentDate(recentItem.lastOpened),
                                                                      style: const TextStyle(
                                                                        fontSize: 12,
                                                                        color: Color(0xFFFF6B6B),
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 12),
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors.white.withOpacity(0.1),
                                                                      borderRadius: BorderRadius.circular(8),
                                                                    ),
                                                                    child: Text(
                                                                      _formatFileSize(recentItem.fileSize),
                                                                      style: TextStyle(
                                                                        fontSize: 12,
                                                                        color: Colors.white.withOpacity(0.7),
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Icon(
                                                            Icons.arrow_forward_ios,
                                                            color: Colors.white.withOpacity(0.7),
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
                                      },
                                    );
                                  },
                                ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.redAccent, Color(0xFFE53935), Color(0xFFC62828)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14), // Ajuste para o FloatingActionButton.extended
          ),
          child: FloatingActionButton.extended(
            onPressed: _pickAndOpenPdf,
            backgroundColor: Colors.transparent, // O gradiente do container faz o efeito
            elevation: 0, // O container pode ter sombra se desejado
            icon: const Icon(Icons.add, color: Colors.white, size: 24),
            label: const Text(
              'Abrir PDF',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}