// lib/widgets/custom_app_bar.dart
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titleText;
  final List<Widget>? actions;
  final Widget? leading; // Para casos onde um botão de voltar customizado ou outro leading é necessário

  const CustomAppBar({
    super.key,
    required this.titleText,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    // Pega o tema da AppBar definido no MaterialApp para defaults
    final appBarTheme = AppBarTheme.of(context);
    final effectiveForegroundColor = appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onPrimary;

    return AppBar(
      backgroundColor: Colors.transparent, // Essencial para o gradiente no flexibleSpace
      elevation: 0, // Já definido no tema, mas reforçando aqui
      automaticallyImplyLeading: leading == null, // Deixa o Flutter decidir sobre o botão de voltar se leading não for fornecido
      leading: leading,
      centerTitle: true, // Padronizando a centralização
      title: Text(
        titleText,
        style: TextStyle( // Estilo padronizado do título
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: effectiveForegroundColor, // Usa a cor do tema
          letterSpacing: -0.3,
          fontFamily: 'WDXLLubrifontTC', // Garante a fonte correta
        ),
      ),
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
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight); // Altura padrão da AppBar
}