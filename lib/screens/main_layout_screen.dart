// lib/screens/main_layout_screen.dart
import 'package:flutter/material.dart';
import 'package:pdfish/screens/home_screen.dart';
import 'package:pdfish/screens/all_pdfs_screen.dart';
import 'package:pdfish/screens/settings_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    AllPdfsScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Cada tela (HomeScreen, AllPdfsScreen, SettingsScreen)
      // gerenciará sua própria AppBar.
      // Usamos IndexedStack para preservar o estado de cada aba.
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            activeIcon: Icon(Icons.history_rounded), // Pode ser o mesmo ou um diferente
            label: 'Recentes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_copy_outlined),
            activeIcon: Icon(Icons.folder_copy_rounded),
            label: 'Todos os PDFs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Configurações',
          ),
        ],
        currentIndex: _selectedIndex,
        // As cores e estilos virão do BottomNavigationBarTheme no MaterialApp,
        // ou podem ser definidos aqui diretamente.
        // Exemplo de personalização direta:
        // backgroundColor: const Color(0xFF1a1a1a),
        // selectedItemColor: Colors.redAccent,
        // unselectedItemColor: Colors.white70,
        // type: BottomNavigationBarType.fixed, // Garante que os labels sempre apareçam
        // showUnselectedLabels: true,
        onTap: _onItemTapped,
      ),
    );
  }
}