import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdfish/screens/pdf_viewer_screen.dart';
import 'package:pdfish/models/recent_pdf_item.dart';
import 'package:pdfish/services/recent_pdfs_service.dart';
import 'package:pdfish/screens/all_pdfs_screen.dart';

// Imports para permissão
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver { // Adicionado WidgetsBindingObserver
  final RecentPdfsService _recentPdfsService = RecentPdfsService();
  List<RecentPdfItem> _recentPdfsList = [];
  bool _isLoadingRecents = true;
  bool _initialPermissionCheckDone = false; // Para controlar a primeira verificação de permissão

  late AnimationController _fabController;
  late AnimationController _listController;
  late Animation<double> _fabAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Registrar observer

    _loadRecentPdfs(); // Carrega os recentes independentemente da permissão de acesso total

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

    // Agendar verificação de permissão após o primeiro frame
    // para garantir que o context está disponível para diálogos.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestManageStoragePermissionIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remover observer
    _fabController.dispose();
    _listController.dispose();
    super.dispose();
  }

  // Lidar com o retorno das configurações do app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _initialPermissionCheckDone) {
      // Usuário retornou ao app, e a verificação inicial já foi feita
      print("HomeScreen: App Resumed. Verificando status de MANAGE_EXTERNAL_STORAGE.");
      _checkManageStoragePermissionStatus(showDialogIfNeeded: false); // Apenas verifica, não força diálogo
    }
  }

  Future<void> _checkAndRequestManageStoragePermissionIfNeeded() async {
    if (_initialPermissionCheckDone || !Platform.isAndroid) {
      // Se já verificamos ou não é Android, não faz nada.
      // Marcamos como feito mesmo se não for Android para não repetir.
      if (!Platform.isAndroid) setState(() => _initialPermissionCheckDone = true);
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Usamos uma flag para saber se o diálogo de informação já foi mostrado alguma vez.
    // Isso evita mostrar o diálogo toda vez que o app é aberto se o usuário negou antes.
    // A lógica de "AllPdfsScreen" pode decidir mostrar o diálogo novamente se o usuário tentar acessar.
    bool manageStorageDialogShownV1 = prefs.getBool('manage_storage_dialog_shown_v1') ?? false;

    var status = await Permission.manageExternalStorage.status;
    print("HomeScreen: Status inicial de MANAGE_EXTERNAL_STORAGE: $status");

    if (!status.isGranted && !manageStorageDialogShownV1) {
      if (mounted) {
        await _showManageStoragePermissionDialog();
        await prefs.setBool('manage_storage_dialog_shown_v1', true); // Marcar que o diálogo foi mostrado
        // Após o diálogo, verifica o status novamente
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
                // O .request() para MANAGE_EXTERNAL_STORAGE abre as configurações do sistema.
                await Permission.manageExternalStorage.request();
                // A verificação se foi concedido ocorrerá no didChangeAppLifecycleState ao retornar.
              },
            ),
          ],
        );
      },
    );
  }

  // Verifica o status e opcionalmente mostra o diálogo (usado por AllPdfsScreen se necessário)
  Future<bool> _checkManageStoragePermissionStatus({bool showDialogIfNeeded = true}) async {
    if (!Platform.isAndroid) return true; // Assume concedido fora do Android

    var status = await Permission.manageExternalStorage.status;
    print("HomeScreen: Verificando status de MANAGE_EXTERNAL_STORAGE: $status");

    if (status.isGranted) {
      if (mounted && showDialogIfNeeded) { // showDialogIfNeeded aqui pode ser usado para um feedback positivo
         // Removido o SnackBar daqui para não ser repetitivo se chamado por AllPdfsScreen
      }
      return true;
    } else {
      if (mounted && showDialogIfNeeded) {
        await _showManageStoragePermissionDialog(); // Mostra o diálogo se for solicitado
        status = await Permission.manageExternalStorage.status; // Reverifica após diálogo
        return status.isGranted;
      }
      return false; // Não concedido e não mostrou diálogo ou não foi concedido após diálogo
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
    // FilePicker usa SAF, não precisa de MANAGE_EXTERNAL_STORAGE para esta ação.
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
          lastOpened: DateTime.now()
        );

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
      appBar: AppBar(
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
        centerTitle: true,
        title: const Text(
          'Documentos Recentes',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_recentPdfsList.isNotEmpty && !_isLoadingRecents)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white, size: 24),
                tooltip: 'Limpar Todos os Recentes',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    barrierColor: Colors.black.withOpacity(0.8),
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor: const Color(0xFF1a1a1a),
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
                            const Text('Limpar Recentes?', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                        content: const Text(
                          'Isso removerá todos os PDFs da lista e suas senhas salvas.',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
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
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        child: Container(
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
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.home, color: Colors.white, size: 24),
                  title: const Text('Início (Recentes)', style: TextStyle(color: Colors.white, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_copy_outlined, color: Colors.white, size: 24),
                  title: const Text('Todos os PDFs', style: TextStyle(color: Colors.white, fontSize: 16)),
                  onTap: () async {
                    Navigator.pop(context); // Fecha o drawer primeiro

                    bool permissionGranted = await _checkManageStoragePermissionStatus(showDialogIfNeeded: true);
                    
                    if (permissionGranted && mounted) {
                      // Navega para AllPdfsScreen e espera ela ser fechada (pop).
                      // Não precisamos de um valor de retorno específico da AllPdfsScreen aqui,
                      // apenas o fato de que ela foi visitada e pode ter modificado os recentes.
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AllPdfsScreen()),
                      );
                      // Quando AllPdfsScreen for fechada e voltarmos para HomeScreen,
                      // recarregamos os recentes.
                      print("HomeScreen: Retornou da AllPdfsScreen, recarregando recentes.");
                      _loadRecentPdfs(); // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ADICIONADO AQUI
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Acesso a todos os arquivos é necessário para esta funcionalidade.')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.white, size: 24),
                  title: const Text('Configurações', style: TextStyle(color: Colors.white, fontSize: 16)),
                  onTap: () {
                     Navigator.pop(context);
                    // Navegação futura para tela de configurações
                    // Se as configurações permitirem ativar/desativar MANAGE_EXTERNAL_STORAGE,
                    // pode ser útil chamar _checkManageStoragePermissionStatus aqui também
                    // ou ao retornar da tela de configurações.
                  },
                ),
              ],
            ),
          ),
        ),
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
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 5),
              if (!_initialPermissionCheckDone && Platform.isAndroid) // Mostra um loader enquanto a primeira verificação de permissão está pendente no Android
                 const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.redAccent))),
              if (_initialPermissionCheckDone || !Platform.isAndroid) // Mostra o conteúdo normal após a verificação ou se não for Android
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
                                  padding: const EdgeInsets.fromLTRB(24, 5, 24, 120),
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
            borderRadius: BorderRadius.circular(14),
          ),
          child: FloatingActionButton.extended(
            onPressed: _pickAndOpenPdf,
            backgroundColor: Colors.transparent,
            elevation: 0,
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