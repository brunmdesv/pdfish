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

class _PdfViewerScreenState extends State<PdfViewerScreen>
    with TickerProviderStateMixin {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  String? _password;
  bool _isPasswordDialogShown = false;
  bool _isLoading = true;
  String? _fileName;
  bool _isHorizontal = true;
  bool _isMenuVisible = true; // Menu sempre visível
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fileName = widget.filePath.split('/').last;
    _password = widget.initialPasswordAttempt;
    
    
    // Inicializar controlador de animação para FABs
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    
    // Iniciar animação dos FABs
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _rotatePdf() {
    // Funcionalidade de rotação - forçar orientação da tela
    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
Widget build(BuildContext context) {
  final themeNotifier = Provider.of<ThemeNotifier>(context);
  final isDarkMode = themeNotifier.isDarkMode;

  return PopScope(
    canPop: true,
    onPopInvoked: (didPop) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);

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
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [
                      const Color(0xFF8B0000),
                      const Color(0xFFB71C1C),
                      const Color(0xFFD32F2F),
                    ]
                  : [
                      const Color(0xFFE53935),
                      const Color(0xFFD32F2F),
                      const Color(0xFFC62828),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: themeNotifier.bodyGradient),
        child: Stack(
          children: [
            // Visualizador PDF
            Container(
              margin: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0, bottom: 100.0),
              decoration: BoxDecoration(
                color: themeNotifier.cardBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: themeNotifier.cardBorderColor,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.4)
                        : Colors.grey.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
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

            // Overlay de loading
            if (_isLoading)
              Container(
                decoration: BoxDecoration(
                  gradient: themeNotifier.bodyGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0, bottom: 100.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: themeNotifier.cardBackgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Colors.redAccent,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Carregando PDF...',
                          style: TextStyle(
                            color: themeNotifier.primaryTextColorOnCard,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Botões flutuantes
            Positioned(
              right: 16,
              bottom: 120,
              child: ScaleTransition(
                scale: _fabAnimation,
                child: Column(
                  children: [
                    _buildZoomButton(
                      icon: Icons.zoom_in,
                      tooltip: "Aumentar zoom",
                      onPressed: () {
                        _pdfViewerController.zoomLevel =
                            _pdfViewerController.zoomLevel + 0.25;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildZoomButton(
                      icon: Icons.zoom_out,
                      tooltip: "Diminuir zoom",
                      onPressed: () {
                        _pdfViewerController.zoomLevel =
                            _pdfViewerController.zoomLevel - 0.25;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildZoomButton(
                      icon: Icons.center_focus_strong,
                      tooltip: "Zoom normal",
                      onPressed: () {
                        _pdfViewerController.zoomLevel = 1.0;
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Menu inferior fixo
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomMenu(themeNotifier, isDarkMode),
            ),
          ],
        ),
      ),
    ),
  );
}


  Widget _buildZoomButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDarkMode = themeNotifier.isDarkMode;
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [
                  const Color(0xFF8B0000),
                  const Color(0xFFD32F2F),
                ]
              : [
                  const Color(0xFFE53935),
                  const Color(0xFFC62828),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMenuButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  required ThemeNotifier themeNotifier,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 24,
          color: themeNotifier.primaryTextColorOnCard,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: themeNotifier.secondaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}


  Widget _buildBottomMenu(ThemeNotifier themeNotifier, bool isDarkMode) {
    return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: themeNotifier.cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeNotifier.cardBorderColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.15)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMiniMenuButton(
            icon: _isHorizontal ? Icons.swap_vert : Icons.swap_horiz,
            label: 'Layout',
            onTap: () {
              setState(() {
                _isHorizontal = !_isHorizontal;
              });
            },
            themeNotifier: themeNotifier,
          ),
          _buildMiniMenuButton(
            icon: Icons.screen_rotation,
            label: 'Girar',
            onTap: _rotatePdf,
            themeNotifier: themeNotifier,
          ),
          _buildMiniMenuButton(
            icon: Icons.share,
            label: 'Compartilhar',
            onTap: () {
              Share.shareXFiles(
                [XFile(widget.filePath)],
                text: 'Veja este PDF: ${_fileName ?? ""}',
              );
            },
            themeNotifier: themeNotifier,
          ),
        ],
      ),
    ),
  );
}


  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ThemeNotifier themeNotifier,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: themeNotifier.isDarkMode
                        ? [
                            const Color(0xFF8B0000),
                            const Color(0xFFD32F2F),
                          ]
                        : [
                            const Color(0xFFE53935),
                            const Color(0xFFC62828),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: themeNotifier.primaryTextColorOnCard,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: themeNotifier.cardBorderColor,
              width: 2,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: themeNotifier.isDarkMode
                        ? [
                            const Color(0xFF8B0000),
                            const Color(0xFFD32F2F),
                          ]
                        : [
                            const Color(0xFFE53935),
                            const Color(0xFFC62828),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'PDF Protegido',
                  style: TextStyle(
                    color: themeNotifier.primaryTextColorOnCard,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            decoration: BoxDecoration(
              color: themeNotifier.isDarkMode 
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: themeNotifier.cardBorderColor,
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              style: TextStyle(color: themeNotifier.primaryTextColorOnCard),
              decoration: InputDecoration(
                labelText: 'Digite a senha',
                labelStyle: TextStyle(color: themeNotifier.secondaryTextColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: themeNotifier.cardBorderColor,
              width: 2,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Erro ao abrir PDF',
                  style: TextStyle(
                    color: themeNotifier.primaryTextColorOnCard,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeNotifier.isDarkMode 
                  ? Colors.red.withOpacity(0.1)
                  : Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Text(
              errorMessage,
              style: TextStyle(
                color: themeNotifier.primaryTextColorOnCard,
                fontSize: 14,
              ),
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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