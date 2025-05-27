// pdfish/lib/screens/home_screen.dart
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

  Future<void> _openPdfViewer(RecentPdfItem itemToOpen) async {
    // Adiciona/Atualiza na lista de recentes ANTES de abrir
    // Usamos os dados do itemToOpen para garantir consistência na atualização
    await _recentPdfsService.addOrUpdateRecentPdf(
      itemToOpen.filePath, // Use o filePath (cache) do item salvo para abrir
      itemToOpen.fileName,
      itemToOpen.originalIdentifier,
      itemToOpen.fileSize,
    );
    await _loadRecentPdfs(); // Atualiza a UI da lista de recentes

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(filePath: itemToOpen.filePath), // Abre usando o filePath (cache)
        ),
      );
    }
  }

  Future<void> _pickAndOpenPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        // withData: false, // Não precisamos dos bytes do arquivo aqui, apenas metadados
        // withReadStream: false, // Também não
      );

      if (result != null && result.files.single.path != null) {
        final PlatformFile file = result.files.single;
        final filePath = file.path!; // Caminho do cache
        final fileName = file.name;
        final originalIdentifier = file.identifier; // Pode ser null
        final fileSize = file.size;

        print("FilePicker result: name='${file.name}', path='${file.path}', identifier='${file.identifier}', size=${file.size}");

        // Cria um RecentPdfItem temporário para passar para _openPdfViewer
        // ou diretamente para _recentPdfsService.addOrUpdateRecentPdf
        await _recentPdfsService.addOrUpdateRecentPdf(
          filePath,
          fileName,
          originalIdentifier,
          fileSize,
        );
        await _loadRecentPdfs(); // Atualiza a UI

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerScreen(filePath: filePath),
            ),
          );
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
                          'Isso removerá todos os PDFs da lista de abertos recentemente.'),
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
                        child: Padding( // Adicionado Padding para centralizar melhor o conteúdo
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
                                // Verificar se o arquivo no CAMINHO DO CACHE ainda existe
                                final file = File(recentItem.filePath);
                                if (await file.exists()) {
                                  _openPdfViewer(recentItem); // Passa o RecentPdfItem inteiro
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Arquivo "${recentItem.fileName}" não encontrado no cache. Pode ter sido limpo.'),
                                        action: SnackBarAction(
                                          label: 'REMOVER DA LISTA',
                                          textColor: Colors.amber,
                                          onPressed: () async {
                                            await _recentPdfsService.removeSpecificRecent(
                                              recentItem.fileName,
                                              recentItem.originalIdentifier,
                                              recentItem.fileSize
                                            );
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