// pdfish/lib/services/recent_pdfs_service.dart
import 'dart:convert'; // Para jsonEncode e jsonDecode
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdfish/models/recent_pdf_item.dart';

class RecentPdfsService {
  static const String _recentsKey = 'recent_pdfs_list';
  static const int _maxRecents = 15; // Aumentei um pouco, opcional

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
      print("Erro ao decodificar PDFs recentes: $e");
      await prefs.remove(_recentsKey);
      return [];
    }
  }

  // Modificado para aceitar path, name, e opcionalmente identifier e size
  Future<void> addOrUpdateRecentPdf(
    String filePath, // O caminho do cache, ainda necessário para abrir
    String fileName,
    String? originalIdentifier, // URI do arquivo original, se disponível
    int? fileSize // Tamanho do arquivo, para desambiguação se identifier não estiver disponível
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<RecentPdfItem> recents = await getRecentPdfs();

    // Chave de identificação única: prioriza originalIdentifier, depois uma combinação de fileName e fileSize
    // Se fileSize não for fornecido, apenas fileName.
    // A ideia é que fileName + fileSize é menos provável de colidir do que apenas fileName.
    final String uniqueKey = originalIdentifier ?? (fileSize != null ? "${fileName}_$fileSize" : fileName);

    print("Tentando adicionar/atualizar. Chave única: '$uniqueKey', Nome: '$fileName', Path cache: '$filePath'");
    print("Lista atual (chaves únicas): ${recents.map((e) => e.originalIdentifier ?? (e.fileSize != null ? "${e.fileName}_${e.fileSize}" : e.fileName)).toList()}");

    // Remove o item se já existir (baseado na chave única) para atualizá-lo e movê-lo para o topo
    final initialLength = recents.length;
    recents.removeWhere((item) {
      final String itemKey = item.originalIdentifier ?? (item.fileSize != null ? "${item.fileName}_${item.fileSize}" : item.fileName);
      return itemKey == uniqueKey;
    });

    if (recents.length < initialLength) {
      print("Item existente com chave única '$uniqueKey' removido para atualização.");
    } else {
      print("Nenhum item existente com chave única '$uniqueKey' encontrado para remover.");
    }

    final newItem = RecentPdfItem(
      filePath: filePath, // Sempre salve o caminho do cache para abrir
      fileName: fileName,
      lastOpened: DateTime.now(),
      originalIdentifier: originalIdentifier, // Salva o identifier original
      fileSize: fileSize, // Salva o tamanho do arquivo
    );
    recents.insert(0, newItem);
    print("Item adicionado no topo: Chave: '$uniqueKey', Path: ${newItem.filePath} - ${newItem.lastOpened}");

    if (recents.length > _maxRecents) {
      recents = recents.sublist(0, _maxRecents);
    }

    final List<String> recentPdfsJson =
        recents.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_recentsKey, recentPdfsJson);
    print("Lista de recentes salva. Total: ${recents.length}");
  }

  Future<void> removeSpecificRecent(
    String fileName,
    String? originalIdentifier,
    int? fileSize
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<RecentPdfItem> recents = await getRecentPdfs();
    final String uniqueKeyToRemove = originalIdentifier ?? (fileSize != null ? "${fileName}_$fileSize" : fileName);

    recents.removeWhere((item) {
      final String itemKey = item.originalIdentifier ?? (item.fileSize != null ? "${item.fileName}_${item.fileSize}" : item.fileName);
      return itemKey == uniqueKeyToRemove;
    });

    final List<String> recentPdfsJson =
        recents.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_recentsKey, recentPdfsJson);
    print("Item com chave '$uniqueKeyToRemove' removido. Nova lista salva.");
  }

  Future<void> clearAllRecentPdfs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentsKey);
  }
}