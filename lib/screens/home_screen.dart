import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdfish/screens/pdf_viewer_screen.dart';
import 'package:pdfish/models/recent_pdf_item.dart';
import 'package:pdfish/services/recent_pdfs_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RecentPdfsService _recentPdfsService = RecentPdfsService();
  List<RecentPdfItem> _recentPdfsList = [];
  bool _isLoadingRecents = true;

  @override
  void initState() {
    super.initState();
    _loadRecentPdfs();
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
      }
      print("Erro ao carregar recentes: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar PDFs recentes: $e')),
        );
      }
    }
  }

  Future<void> _openPdfViewer(RecentPdfItem itemToOpen, {String? knownPassword}) async {
    // Se uma senha é explicitamente conhecida (ex: vinda do picker + visualizador), usa ela.
    // Senão, tenta carregar do secure storage.
    String? passwordForViewer = knownPassword;
    if (passwordForViewer == null || passwordForViewer.isEmpty) {
        passwordForViewer = await _recentPdfsService.getPasswordForRecentItem(itemToOpen);
        print("HomeScreen: Carregada senha '${passwordForViewer ?? "nenhuma"}' do secure storage para ${itemToOpen.fileName}");
    } else {
        print("HomeScreen: Usando senha conhecida '$passwordForViewer' para ${itemToOpen.fileName}");
    }

    if (mounted) {
      final returnedPassword = await Navigator.push<String?>( // Espera String?
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            filePath: itemToOpen.filePath,
            initialPasswordAttempt: passwordForViewer,
          ),
        ),
      );

      print("HomeScreen: PdfViewerScreen retornou: '${returnedPassword ?? "null"}' para ${itemToOpen.fileName}");

      // Se retornou uma string (pode ser vazia se a senha foi "esquecida" ou PDF não tinha senha)
      // ou null (se voltou por gesto do sistema e o PDF abriu com sucesso com senha inicial/sem senha)
      String? finalPasswordToSave;
      if (returnedPassword != null) {
        finalPasswordToSave = returnedPassword.isNotEmpty ? returnedPassword : null;
      } else {
        // Se voltou por gesto (null retornado) e o PDF tinha uma senha inicial que funcionou,
        // devemos manter essa senha.
        // Isso é complicado porque a PdfViewerScreen não "sabe" como foi fechada.
        // Uma melhoria seria a PdfViewerScreen sempre retornar a senha que funcionou,
        // mesmo que seja a inicial. O PopScope customizado ajuda nisso.
        // Por ora, se retornou null, e uma senha inicial foi tentada, podemos re-buscar.
        // Mas a lógica atual do PdfViewerScreen com botão de voltar customizado deve retornar a senha.
        // Se ainda for null, significa que o PDF não precisou de senha ou a senha inicial não funcionou
        // e o usuário não forneceu uma nova.
         finalPasswordToSave = passwordForViewer; // Re-usa a senha que tentamos inicialmente.
                                                 // Se essa senha abriu o PDF, é a correta.
                                                 // Se não abriu e o usuário não forneceu nova, é null.
                                                 // Se `returnedPassword` foi `""`, significa que o usuário
                                                 // limpou/esqueceu a senha.
      }


      // Atualiza o item nos recentes e sua senha no secure storage
      await _recentPdfsService.addOrUpdateRecentPdf(
        itemToOpen.filePath, // filePath pode ter sido atualizado se o arquivo foi re-selecionado
        itemToOpen.fileName,
        itemToOpen.originalIdentifier,
        itemToOpen.fileSize,
        finalPasswordToSave,
      );
      await _loadRecentPdfs(); // Atualiza a UI da lista de recentes
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
          lastOpened: DateTime.now()
        );

        // Tenta carregar uma senha existente para este arquivo ANTES de abrir o visualizador
        String? existingPassword = await _recentPdfsService.getPasswordForRecentItem(tempItemForInfo);
        print("HomeScreen: Para PDF do picker '${file.name}', senha existente no storage: '${existingPassword ?? "nenhuma"}'");

        if (mounted) {
           final returnedPassword = await Navigator.push<String?>( // Espera String?
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
          if (returnedPassword != null) { // Usuário interagiu com diálogo ou voltou com botão custom
            finalPasswordToSave = returnedPassword.isNotEmpty ? returnedPassword : null;
          } else { // Voltou por gesto do sistema
            // Se uma senha existente funcionou, ela deve ser mantida.
            // Se não havia senha existente e o PDF abriu, é null.
            // Se havia senha existente mas falhou e usuário não digitou nova, é null.
            finalPasswordToSave = existingPassword; // Melhor palpite, mas PdfViewerScreen deveria ser a fonte da verdade.
                                                // A lógica do botão de voltar customizado no PdfViewerScreen
                                                // é crucial aqui.
          }
          
          // Salva/Atualiza o item recente e sua senha no secure storage
          await _recentPdfsService.addOrUpdateRecentPdf(
            tempItemForInfo.filePath, // O filePath do cache atual
            tempItemForInfo.fileName,
            tempItemForInfo.originalIdentifier,
            tempItemForInfo.fileSize,
            finalPasswordToSave,
          );
          await _loadRecentPdfs(); // Atualiza a lista de recentes na UI
        }

      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum arquivo PDF selecionado.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar o arquivo: $e')),
        );
      }
      print("Erro ao selecionar arquivo: $e");
    }
  }

  String _formatRecentDate(DateTime dt) {
    return DateFormat('dd/MM/yyyy | HH\'h\'mm\'min\'', 'pt_BR').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pdfish'),
        actions: [
          if (_recentPdfsList.isNotEmpty && !_isLoadingRecents)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Limpar Todos os Recentes',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Limpar Recentes?'),
                      content: const Text(
                          'Isso removerá todos os PDFs da lista e suas senhas salvas.'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancelar'),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Limpar Tudo'),
                          onPressed: () => Navigator.of(context).pop(true),
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
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _isLoadingRecents
                ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                : _recentPdfsList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.find_in_page_outlined, size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 20),
                              Text(
                                'Nenhum PDF aberto recentemente.',
                                style: TextStyle(fontSize: 17, color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Toque no botão + abaixo para selecionar e abrir um arquivo PDF do seu dispositivo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: 80.0),
                        itemCount: _recentPdfsList.length,
                        itemBuilder: (context, index) {
                          final recentItem = _recentPdfsList[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                            child: ListTile(
                              leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
                              title: Text(
                                recentItem.fileName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(_formatRecentDate(recentItem.lastOpened)),
                              onTap: () async {
                                final file = File(recentItem.filePath);
                                if (await file.exists()) {
                                  _openPdfViewer(recentItem);
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Arquivo "${recentItem.fileName}" não encontrado no cache. Pode ter sido limpo.'),
                                        action: SnackBarAction(
                                          label: 'REMOVER DA LISTA',
                                          textColor: Colors.amber,
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
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndOpenPdf,
        tooltip: 'Abrir PDF',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}