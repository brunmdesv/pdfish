import 'dart:async'; // Para Completer
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;

  const PdfViewerScreen({super.key, required this.filePath});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final Completer<PDFViewController> _controller = Completer<PDFViewController>();
  int? pages = 0;
  int? currentPage = 0;
  bool isReady = false;
  String errorMessage = '';
  String get _fileName => widget.filePath.split('/').last;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName, style: const TextStyle(fontSize: 16)),
        actions: <Widget>[
          if (isReady && pages != null && pages! > 0 && currentPage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Text('${currentPage! + 1}/$pages',
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          PDFView(
            filePath: widget.filePath,
            enableSwipe: true,
            swipeHorizontal: false, // Rolagem vertical é mais comum
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            defaultPage: currentPage!,
            fitPolicy: FitPolicy.BOTH, // Ou FIT_WIDTH, FIT_HEIGHT
            preventLinkNavigation: false, // Define como true se não quiser que links no PDF abram no navegador
            onRender: (pagesCount) {
              if (mounted) {
                setState(() {
                  pages = pagesCount;
                  isReady = true;
                });
              }
            },
            onError: (error) {
              if (mounted) {
                setState(() {
                  errorMessage = error.toString();
                });
              }
              print(error.toString());
            },
            onPageError: (page, error) {
              if (mounted) {
                setState(() {
                  errorMessage = 'Erro na página $page: ${error.toString()}';
                });
              }
              print('$page: ${error.toString()}');
            },
            onViewCreated: (PDFViewController pdfViewController) {
              if (!_controller.isCompleted) {
                 _controller.complete(pdfViewController);
              }
            },
            onPageChanged: (int? page, int? total) {
              if (mounted) {
                setState(() {
                  currentPage = page;
                  // 'total' também informa o total de páginas, pode ser usado aqui também.
                  // if (pages == 0 && total != null) pages = total;
                });
              }
            },
          ),
          if (errorMessage.isNotEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Erro ao carregar PDF: $errorMessage',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            )
          else if (!isReady)
            const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),
        ],
      ),
      floatingActionButton: FutureBuilder<PDFViewController>(
        future: _controller.future,
        builder: (context, AsyncSnapshot<PDFViewController> snapshot) {
          if (snapshot.hasData && isReady && pages != null && pages! > 1) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (currentPage != null && currentPage! > 0)
                  FloatingActionButton(
                    heroTag: "prevPage", // Tags hero únicas são necessárias para múltiplos FABs
                    mini: true,
                    child: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () async {
                      if (currentPage! > 0) {
                        await snapshot.data!.setPage(currentPage! - 1);
                      }
                    },
                  ),
                const SizedBox(width: 10),
                if (currentPage != null && currentPage! < pages! - 1)
                  FloatingActionButton(
                    heroTag: "nextPage",
                    mini: true,
                    child: const Icon(Icons.arrow_forward_ios),
                    onPressed: () async {
                      if (currentPage! < pages! - 1) {
                        await snapshot.data!.setPage(currentPage! + 1);
                      }
                    },
                  ),
              ],
            );
          }
          return const SizedBox.shrink(); // Nenhum FAB se não estiver pronto ou só tiver 1 página
        },
      ),
    );
  }
}