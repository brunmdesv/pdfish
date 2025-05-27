import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para SystemNavigator
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String? initialPasswordAttempt;
  final bool fromIntent; // Indica se o PDF foi aberto a partir de um intent externo

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    this.initialPasswordAttempt,
    this.fromIntent = false, // Por padrão, não é de intent externo
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final Completer<PDFViewController> _controller = Completer<PDFViewController>();
  int? pages = 0;
  int? currentPage = 0;
  bool isReady = false;
  String errorMessage = '';
  bool _isLandscape = false; // Controla a orientação do PDF

  String? _currentPassword;
  bool _isLoading = true;
  bool _passwordAttemptFailed = false;
  Key _pdfViewKey = UniqueKey();
  String _successfulPasswordUsed = ""; // "" -> sem senha ou falha; "senha_usada" -> sucesso

  @override
  void initState() {
    super.initState();
    if (widget.initialPasswordAttempt != null && widget.initialPasswordAttempt!.isNotEmpty) {
      _currentPassword = widget.initialPasswordAttempt;
      // Não definimos _successfulPasswordUsed aqui, apenas ao renderizar com sucesso
      print("PdfViewerScreen initState: Tentando com senha inicial: '$_currentPassword'");
    } else {
      print("PdfViewerScreen initState: Nenhuma senha inicial.");
    }
    // A primeira renderização do PDFView tentará com _currentPassword (que pode ser null ou preenchido)
  }

  String get _fileName {
    try {
      return widget.filePath.split('/').last;
    } catch (e) {
      return "Documento PDF";
    }
  }

  Future<void> _showPasswordDialog() async {
    String? enteredPasswordInDialog;
    final passwordController = TextEditingController();
    // Usamos uma variável local para o estado do erro no diálogo para que o StatefulBuilder funcione corretamente
    bool displayDialogFailedAttemptMessage = _passwordAttemptFailed;

    if (mounted) {
      setState(() {
        errorMessage = ''; // Limpa erro principal da tela
      });
    }

    final String? resultPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('PDF Protegido por Senha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Este arquivo PDF requer uma senha para ser aberto.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: displayDialogFailedAttemptMessage ? 'Senha incorreta. Tente novamente.' : null,
                    ),
                    onChanged: (value) {
                      enteredPasswordInDialog = value;
                      if (displayDialogFailedAttemptMessage) {
                        setDialogState(() {
                          displayDialogFailedAttemptMessage = false;
                        });
                      }
                    },
                    onSubmitted: (value) { // Permite submeter com Enter
                       Navigator.of(dialogContext).pop(enteredPasswordInDialog);
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(null); // Retorna null se cancelado
                  },
                ),
                ElevatedButton(
                  child: const Text('Abrir'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(enteredPasswordInDialog);
                  },
                ),
              ],
            );
          }
        );
      },
    );

    if (resultPassword != null && resultPassword.isNotEmpty) { // Senha digitada e confirmada
        if (mounted) {
          setState(() {
            _currentPassword = resultPassword;
            // _successfulPasswordUsed será setado no onRender
            _isLoading = true;
            _passwordAttemptFailed = false; // Reseta ao tentar nova senha
            _pdfViewKey = UniqueKey(); // Força reconstrução
            errorMessage = '';
          });
        }
      } else if (resultPassword == null) { // Usuário cancelou o diálogo (clicou em Cancelar)
        if (mounted && !isReady) { // Se PDF ainda não foi carregado
          setState(() {
            errorMessage = 'Abertura cancelada ou senha não fornecida.';
            _isLoading = false;
            _successfulPasswordUsed = ""; // Indica que nenhuma senha funcionou/foi usada
          });
          // Se cancelou e PDF não abriu, volta para HomeScreen informando que não houve senha bem-sucedida
          Navigator.of(context).pop("");
        }
      } else { // Senha vazia submetida (resultPassword == "")
         if (mounted && !isReady) {
             setState(() {
                errorMessage = 'Senha não pode ser vazia.';
                _isLoading = false;
                _passwordAttemptFailed = true; // Considera como tentativa falha para reabrir diálogo
                _successfulPasswordUsed = "";
             });
             // Reabre o diálogo se a senha foi vazia e o PDF não carregou
             Future.delayed(Duration.zero, _showPasswordDialog);
         }
      }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          print("PopScope onPopInvoked. _successfulPasswordUsed: '$_successfulPasswordUsed', fromIntent: ${widget.fromIntent}");
          
          // Se o PDF foi aberto a partir de um intent externo e o usuário está voltando,
          // precisamos garantir que o app seja fechado completamente
          if (widget.fromIntent) {
            print("Fechando o app após visualização de PDF de intent externo");
            // O sistema já está lidando com o pop, então não precisamos fazer nada aqui
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_fileName, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (widget.fromIntent) {
                // Se veio de intent externo, fecha o app completamente
                print("Fechando o app após visualização de PDF de intent externo (botão voltar)");
                Navigator.of(context).pop(_successfulPasswordUsed);
                // Adiciona um pequeno atraso antes de fechar o app para garantir que o pop seja processado
                Future.delayed(const Duration(milliseconds: 100), () {
                  SystemNavigator.pop(); // Fecha o app completamente
                });
              } else {
                // Comportamento normal - volta para a tela anterior com a senha usada
                Navigator.of(context).pop(_successfulPasswordUsed);
              }
            },
          ),
          actions: <Widget>[
            // Botão para alternar a orientação do PDF
            IconButton(
              icon: Icon(_isLandscape ? Icons.screen_rotation : Icons.screen_rotation_alt),
              tooltip: _isLandscape ? 'Mudar para orientação vertical' : 'Mudar para orientação horizontal',
              onPressed: () {
                setState(() {
                  _isLandscape = !_isLandscape;
                  // Força a reconstrução do PDFView
                  _pdfViewKey = UniqueKey();
                });
              },
            ),
            if (isReady && pages != null && pages! > 0 && currentPage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: Text('${currentPage! + 1}/$pages',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: <Widget>[
            PDFView(
              key: _pdfViewKey,
              filePath: widget.filePath,
              password: _currentPassword,
              enableSwipe: true,
              swipeHorizontal: _isLandscape, // Alterna entre orientação horizontal e vertical
              autoSpacing: true,
              pageFling: true,
              pageSnap: true,
              defaultPage: currentPage ?? 0,
              fitPolicy: FitPolicy.WIDTH, // Melhora a qualidade focando na largura
              preventLinkNavigation: false,
              // Configurações para melhorar a qualidade de renderização
              fitEachPage: true,
              onRender: (pagesCount) {
                if (mounted) {
                  setState(() {
                    pages = pagesCount;
                    isReady = true;
                    _isLoading = false;
                    errorMessage = '';
                    _passwordAttemptFailed = false;
                    _successfulPasswordUsed = _currentPassword ?? "";
                    print("PDF Renderizado. Senha usada: '$_successfulPasswordUsed'. Páginas: $pagesCount");
                  });
                }
              },
              onError: (error) {
                print("PDFView onError: $error. Senha tentada: '$_currentPassword'");
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    isReady = false;
                    _successfulPasswordUsed = ""; // Falhou, então nenhuma senha foi bem-sucedida
                  });

                  bool errorSuggestsPassword = error.toString().toLowerCase().contains('password');
                  
                  if (_currentPassword != null && _currentPassword!.isNotEmpty) { // Tentou com uma senha e falhou
                    setState(() { _passwordAttemptFailed = true; });
                    print("Falha ao abrir com senha fornecida: '$_currentPassword'. Mostrando diálogo.");
                    Future.delayed(Duration.zero, _showPasswordDialog);
                  } else if (errorSuggestsPassword) { // Erro sugere senha, e não tentamos uma (ou a inicial era null)
                     setState(() { _passwordAttemptFailed = false; }); // Não necessariamente falhou *com uma senha* ainda
                     print("Erro sugere senha. Mostrando diálogo.");
                     Future.delayed(Duration.zero, _showPasswordDialog);
                  } else { // Outro tipo de erro, não parece ser senha
                    setState(() { errorMessage = error.toString(); });
                    print("Erro não relacionado à senha: $errorMessage");
                  }
                }
              },
              onPageError: (page, error) {
                if (mounted) {
                  setState(() {
                    errorMessage = 'Erro na página $page: ${error.toString()}';
                    _isLoading = false;
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
                  });
                }
              },
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              ),
            if (!_isLoading && errorMessage.isNotEmpty && !isReady)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 60),
                      const SizedBox(height: 10),
                      Text(
                        'Erro ao carregar PDF',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),
                      if (!_passwordAttemptFailed && (errorMessage.toLowerCase().contains('password') || (pages == 0 && _currentPassword == null)))
                        ElevatedButton.icon(
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Digitar Senha'),
                          onPressed: _showPasswordDialog,
                        ),
                    ],
                  ),
                ),
              )
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
                      heroTag: "prevPage",
                      mini: true,
                      child: const Icon(Icons.arrow_back_ios_new),
                      onPressed: () async {
                        await snapshot.data!.setPage(currentPage! - 1);
                      },
                    ),
                  if (currentPage != null && currentPage! < pages! - 1) ...[
                    const SizedBox(width: 10),
                    FloatingActionButton(
                      heroTag: "nextPage",
                      mini: true,
                      child: const Icon(Icons.arrow_forward_ios),
                      onPressed: () async {
                        await snapshot.data!.setPage(currentPage! + 1);
                      },
                    ),
                  ]
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}