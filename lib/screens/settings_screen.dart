// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:pdfish/widgets/custom_app_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use o tema do AppBar global, mas com um fundo consistente se precisar.
    // Seu AppBarTheme já define cores.
    return Scaffold(
      appBar: const CustomAppBar( // USANDO O CUSTOM APPBAR
      titleText: 'Configurações',
      // Nenhum 'actions' ou 'leading' customizado aqui.
      // Assim como na AllPdfsScreen, o botão de voltar (se houver navegação para esta tela)
      // seria gerenciado automaticamente pelo Navigator. No contexto da BottomNavigationBar,
      // não haverá botão de voltar, o que é o esperado.
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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings_suggest_outlined, size: 80, color: Colors.white54),
              SizedBox(height: 20),
              Text(
                'Configurações em Breve',
                style: TextStyle(fontSize: 22, color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Funcionalidades de personalização e opções do app estarão aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}