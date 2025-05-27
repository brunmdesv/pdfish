// pdfish/lib/services/recent_pdfs_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Importar
import 'package:pdfish/models/recent_pdf_item.dart';

class RecentPdfsService {
  static const String _recentsKey = 'recent_pdfs_list';
  static const int _maxRecents = 15;
  final _secureStorage = const FlutterSecureStorage(); // Instanciar

  // Chave para o secure storage prefixada para evitar colisões
  String _getSecureStorageKey(RecentPdfItem item) {
    return "pdf_password_${item.uniqueKeyForPersistence}";
  }

  Future<List<RecentPdfItem>> getRecentPdfs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? recentPdfsJson = prefs.getStringList(_recentsKey);

    if (recentPdfsJson == null) {
      return [];
    }
    try {
      return recentPdfsJson
          .map((jsonString) => RecentPdfItem.fromJson(jsonDecode(jsonString) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print("Erro ao decodificar PDFs recentes (shared_preferences): $e");
      await prefs.remove(_recentsKey);
      return [];
    }
  }

  Future<void> addOrUpdateRecentPdf(
    String filePath, // Caminho do cache atual
    String fileName,
    String? originalIdentifier,
    int? fileSize,
    String? password, // Nova adição: senha, se fornecida com sucesso
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<RecentPdfItem> recents = await getRecentPdfs();

    final newItem = RecentPdfItem(
      filePath: filePath,
      fileName: fileName,
      lastOpened: DateTime.now(),
      originalIdentifier: originalIdentifier,
      fileSize: fileSize,
    );

    // Remove o item se já existir (baseado na uniqueKeyForPersistence)
    recents.removeWhere((item) => item.uniqueKeyForPersistence == newItem.uniqueKeyForPersistence);
    recents.insert(0, newItem); // Adiciona/move para o topo

    if (recents.length > _maxRecents) {
      recents = recents.sublist(0, _maxRecents);
    }

    final List<String> recentPdfsJson =
        recents.map((item) => jsonEncode(item.toJson())).toList(); // Salva sem senha no shared_prefs
    await prefs.setStringList(_recentsKey, recentPdfsJson);

    // Salva a senha no secure storage se fornecida
    if (password != null && password.isNotEmpty) {
      try {
        await _secureStorage.write(key: _getSecureStorageKey(newItem), value: password);
        print("Senha salva no secure storage para: ${newItem.fileName}");
      } catch (e) {
        print("Erro ao salvar senha no secure_storage: $e");
      }
    } else {
      // Se não há senha (ou foi removida), garante que não há senha antiga no secure storage
      try {
        await _secureStorage.delete(key: _getSecureStorageKey(newItem));
      } catch (e) {
        print("Erro ao deletar senha antiga do secure_storage: $e");
      }
    }
  }

  // Carrega a senha para um item recente específico
  Future<String?> getPasswordForRecentItem(RecentPdfItem item) async {
    try {
      return await _secureStorage.read(key: _getSecureStorageKey(item));
    } catch (e) {
      print("Erro ao ler senha do secure_storage para ${item.fileName}: $e");
      return null;
    }
  }

  Future<void> removeSpecificRecent(RecentPdfItem itemToRemove) async {
    final prefs = await SharedPreferences.getInstance();
    List<RecentPdfItem> recents = await getRecentPdfs();

    recents.removeWhere((item) => item.uniqueKeyForPersistence == itemToRemove.uniqueKeyForPersistence);

    final List<String> recentPdfsJson =
        recents.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_recentsKey, recentPdfsJson);

    // Também remove a senha do secure storage
    try {
      await _secureStorage.delete(key: _getSecureStorageKey(itemToRemove));
      print("Senha removida do secure storage para: ${itemToRemove.fileName}");
    } catch (e) {
      print("Erro ao deletar senha do secure_storage ao remover recente: $e");
    }
  }

  Future<void> clearAllRecentPdfs() async {
    final prefs = await SharedPreferences.getInstance();
    List<RecentPdfItem> recents = await getRecentPdfs(); // Pega a lista antes de limpar
    await prefs.remove(_recentsKey);

    // Limpa todas as senhas associadas do secure storage
    for (var item in recents) {
      try {
        await _secureStorage.delete(key: _getSecureStorageKey(item));
      } catch (e) {
        // Ignora erros individuais aqui para tentar limpar o máximo possível
        print("Erro ao limpar senha do secure_storage para ${item.fileName}: $e");
      }
    }
    print("Todas as senhas de recentes foram removidas do secure storage.");
  }
}