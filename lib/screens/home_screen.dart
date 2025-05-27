import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfish/screens/pdf_viewer_screen.dart';
// import 'package:permission_handler/permission_handler.dart'; // Importe se for gerenciar permissões manualmente

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _pickAndOpenPdf() async {
    // Opcional: Verificar e solicitar permissão de armazenamento manualmente.
    // O file_picker geralmente lida com a solicitação de permissão ao abrir o seletor de arquivos.
    /*
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de armazenamento negada.')),
        );
      }
      return;
    }
    */

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        if (mounted) { // Garante que o widget ainda está na árvore de widgets
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PdfViewerScreen(filePath: result.files.single.path!),
            ),
          );
        }
      } else {
        // Usuário cancelou o seletor de arquivos
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum arquivo PDF selecionado.')),
          );
        }
      }
    } catch (e) {
      // Tratar exceções do file_picker
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar o arquivo: $e')),
        );
      }
      print("Erro ao selecionar arquivo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pdfish - Leitor de PDF'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset( // Adicione um logo simples se desejar
              'assets/pdf_icon.png', // Você precisará adicionar esta imagem
              width: 100,
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.picture_as_pdf, size: 100, color: Colors.redAccent);
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Abrir PDF do Dispositivo'),
              onPressed: _pickAndOpenPdf,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      // Exemplo com FloatingActionButton:
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: _pickAndOpenPdf,
      //   label: const Text('Abrir PDF'),
      //   icon: const Icon(Icons.picture_as_pdf),
      // ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}