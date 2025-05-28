// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:pdfish/widgets/custom_app_bar.dart';
import 'package:pdfish/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Pega o ThemeNotifier do Provider
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      appBar: const CustomAppBar(
        titleText: 'Configurações',
      ),
      body: Container(
        // Usa o gradiente do corpo fornecido pelo ThemeNotifier
        decoration: BoxDecoration(gradient: themeNotifier.bodyGradient),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            Container(
              // Adiciona uma margem inferior para separar de futuros itens
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                // CORREÇÃO APLICADA AQUI:
                // Usar themeNotifier.cardBackgroundColor diretamente, como nas outras telas.
                color: themeNotifier.cardBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: themeNotifier.cardBorderColor,
                  width: 1,
                ),
                // Adicionando uma sombra sutil para consistência visual com outros cards, se desejado
                boxShadow: [
                  BoxShadow(
                    color: themeNotifier.isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Ajuste no padding interno
                title: Text(
                  'Tema Escuro',
                  style: TextStyle(
                    color: themeNotifier.primaryTextColorOnCard, // Cor primária do texto no card
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  themeNotifier.isDarkMode ? 'Ativado' : 'Desativado',
                  style: TextStyle(
                    color: themeNotifier.secondaryTextColor, // Cor secundária do texto no card
                    fontSize: 13,
                  ),
                ),
                value: themeNotifier.isDarkMode,
                onChanged: (bool value) {
                  themeNotifier.toggleTheme();
                },
                activeColor: Theme.of(context).colorScheme.primary, // Cor primária para o switch ativo
                secondary: Icon(
                  themeNotifier.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: themeNotifier.isDarkMode ? Colors.amber.shade300 : Colors.orange.shade600,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 20), // Espaçamento antes do placeholder
            // Placeholder para mais configurações
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.build_circle_outlined, // Ícone diferente para variedade
                    size: 60,
                    color: themeNotifier.secondaryTextColor.withOpacity(0.7),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Mais opções em breve...',
                    style: TextStyle(
                        fontSize: 17,
                        color: themeNotifier.secondaryTextColor,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}