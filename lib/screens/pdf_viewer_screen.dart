import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../providers/theme_provider.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String? initialPasswordAttempt;
  final bool fromIntent;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    this.initialPasswordAttempt,
    this.fromIntent = false,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  String? _password;
  bool _isPasswordDialogShown = false;
  bool _isLoading = true;
  String? _fileName;
  bool _isHorizontal = true;

  @override
  void initState() {
    super.initState();
    _fileName = widget.filePath.split('/').last;
    _password = widget.initialPasswordAttempt;
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = themeNotifier.isDarkMode;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (widget.fromIntent && didPop) {
          Future.delayed(const Duration(milliseconds: 100), () {
            SystemNavigator.pop();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _fileName ?? "Documento PDF",
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (widget.fromIntent) {
                Navigator.of(context).pop();
                Future.delayed(const Duration(milliseconds: 100), () {
                  SystemNavigator.pop();
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: Icon(_isHorizontal ? Icons.swap_vert : Icons.swap_horiz),
              tooltip: "Alternar orientação",
              onPressed: () {
                setState(() {
                  _isHorizontal = !_isHorizontal;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              tooltip: "Aumentar zoom",
              onPressed: () {
                _pdfViewerController.zoomLevel =
                    _pdfViewerController.zoomLevel + 0.25;
              },
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out),
              tooltip: "Diminuir zoom",
              onPressed: () {
                _pdfViewerController.zoomLevel =
                    _pdfViewerController.zoomLevel - 0.25;
              },
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: "Compartilhar PDF",
              onPressed: () {
                Share.shareXFiles([XFile(widget.filePath)],
                    text: 'Veja este PDF: ${_fileName ?? ""}');
              },
            ),
          ],
          // Aplicando o gradiente customizado na AppBar
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [
                        const Color(0xFF8B0000), // Vermelho escuro
                        const Color(0xFFB71C1C), // Vermelho mais claro
                        const Color(0xFFD32F2F), // Vermelho padrão
                      ]
                    : [
                        const Color(0xFFE53935), // Vermelho claro
                        const Color(0xFFD32F2F), // Vermelho padrão
                        const Color(0xFFC62828), // Vermelho mais escuro
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Container(
          // Aplicando o gradiente de fundo igual às outras telas
          decoration: BoxDecoration(gradient: themeNotifier.bodyGradient),
          child: Stack(
            children: [
              // Container para o PDF com cantos arredondados e bordas
              Container(
                margin: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: themeNotifier.cardBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: themeNotifier.cardBorderColor,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode 
                          ? Colors.black.withOpacity(0.3) 
                          : Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11), // Um pouco menor que o container
                  child: SfPdfViewer.file(
                    File(widget.filePath),
                    key: _pdfViewerKey,
                    controller: _pdfViewerController,
                    password: _password,
                    canShowScrollHead: true,
                    canShowScrollStatus: true,
                    pageLayoutMode: _isHorizontal
                        ? PdfPageLayoutMode.continuous
                        : PdfPageLayoutMode.single,
                    onDocumentLoaded: (details) {
                      setState(() {
                        _isLoading = false;
                        _isPasswordDialogShown = false;
                      });
                    },
                    onDocumentLoadFailed: (details) {
                      setState(() {
                        _isLoading = false;
                      });

                      if (details.description.toLowerCase().contains('password')) {
                        if (!_isPasswordDialogShown) {
                          _showPasswordDialog();
                        }
                      } else {
                        _showErrorDialog(details.description);
                      }
                    },
                  ),
                ),
              ),
              if (_isLoading)
                Container(
                  decoration: BoxDecoration(gradient: themeNotifier.bodyGradient),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Carregando PDF...',
                          style: TextStyle(
                            color: themeNotifier.primaryTextColorOnCard,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPasswordDialog() {
    _isPasswordDialogShown = true;
    final passwordController = TextEditingController();
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);

    showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: themeNotifier.cardBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: themeNotifier.cardBorderColor,
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: themeNotifier.primaryTextColorOnCard,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'PDF Protegido por Senha',
                style: TextStyle(
                  color: themeNotifier.primaryTextColorOnCard,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Container(
            decoration: BoxDecoration(
              color: themeNotifier.isDarkMode 
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: themeNotifier.cardBorderColor,
                width: 1,
              ),
            ),
            child: TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              style: TextStyle(color: themeNotifier.primaryTextColorOnCard),
              decoration: InputDecoration(
                labelText: 'Senha',
                labelStyle: TextStyle(color: themeNotifier.secondaryTextColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: themeNotifier.subtleIconColor,
                ),
              ),
              onSubmitted: (value) {
                Navigator.of(dialogContext).pop(value);
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: themeNotifier.secondaryTextColor,
              ),
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop(null);
                if (widget.fromIntent) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    SystemNavigator.pop();
                  });
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Abrir'),
              onPressed: () {
                Navigator.of(dialogContext).pop(passwordController.text);
              },
            ),
          ],
        );
      },
    ).then((enteredPassword) {
      if (enteredPassword != null && enteredPassword.isNotEmpty) {
        setState(() {
          _password = enteredPassword;
          _isLoading = true;
        });
      } else {
        if (widget.fromIntent) {
          Future.delayed(const Duration(milliseconds: 100), () {
            SystemNavigator.pop();
          });
        } else {
          Navigator.of(context).pop();
        }
      }
    });
  }

  void _showErrorDialog(String errorMessage) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: themeNotifier.cardBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: themeNotifier.cardBorderColor,
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Erro ao abrir PDF',
                style: TextStyle(
                  color: themeNotifier.primaryTextColorOnCard,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeNotifier.isDarkMode 
                  ? Colors.red.withOpacity(0.1)
                  : Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              errorMessage,
              style: TextStyle(
                color: themeNotifier.primaryTextColorOnCard,
              ),
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Fechar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (widget.fromIntent) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    SystemNavigator.pop();
                  });
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}