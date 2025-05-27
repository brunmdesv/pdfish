// pdfish/lib/models/recent_pdf_item.dart
class RecentPdfItem {
  final String filePath; // Caminho do cache ATUAL para abrir o arquivo
  final String fileName;
  final DateTime lastOpened;
  final String? originalIdentifier; // URI do arquivo original (pode ser null)
  final int? fileSize; // Tamanho do arquivo (pode ser null)
  String? transientPassword; // Senha carregada temporariamente, não salva no JSON principal

  RecentPdfItem({
    required this.filePath,
    required this.fileName,
    required this.lastOpened,
    this.originalIdentifier,
    this.fileSize,
    this.transientPassword,
  });

  // Chave de identificação para comparação e para o secure storage
  String get uniqueKeyForPersistence {
    // Prioriza o identifier original, que é o mais estável
    // Fallback para nome + tamanho (mais estável que o path do cache sozinho)
    // Se nem identifier nem tamanho estiverem disponíveis, só nome (menos ideal)
    if (originalIdentifier != null && originalIdentifier!.isNotEmpty) {
      return originalIdentifier!;
    }
    if (fileSize != null) {
      return "${fileName}_$fileSize";
    }
    return fileName; // Fallback final
  }

  Map<String, dynamic> toJson() { // Para SharedPreferences (sem a senha)
    return {
      'filePath': filePath, // Salva o path do cache atual
      'fileName': fileName,
      'lastOpened': lastOpened.toIso8601String(),
      'originalIdentifier': originalIdentifier,
      'fileSize': fileSize,
    };
  }

  factory RecentPdfItem.fromJson(Map<String, dynamic> json) {
    return RecentPdfItem(
      filePath: json['filePath'] as String,
      fileName: json['fileName'] as String,
      lastOpened: DateTime.parse(json['lastOpened'] as String),
      originalIdentifier: json['originalIdentifier'] as String?,
      fileSize: json['fileSize'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentPdfItem &&
          runtimeType == other.runtimeType &&
          uniqueKeyForPersistence == other.uniqueKeyForPersistence;

  @override
  int get hashCode => uniqueKeyForPersistence.hashCode;
}