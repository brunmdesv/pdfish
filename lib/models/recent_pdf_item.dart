// pdfish/lib/models/recent_pdf_item.dart
class RecentPdfItem {
  final String filePath; // Caminho do cache para abrir o arquivo
  final String fileName;
  final DateTime lastOpened;
  final String? originalIdentifier; // URI do arquivo original (pode ser null)
  final int? fileSize; // Tamanho do arquivo (pode ser null)

  RecentPdfItem({
    required this.filePath,
    required this.fileName,
    required this.lastOpened,
    this.originalIdentifier,
    this.fileSize,
  });

  // Chave de identificação para comparação
  String get uniqueComparisonKey {
    return originalIdentifier ?? (fileSize != null ? "${fileName}_$fileSize" : fileName);
  }

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
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

  // A comparação agora usa a uniqueComparisonKey
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentPdfItem &&
          runtimeType == other.runtimeType &&
          uniqueComparisonKey == other.uniqueComparisonKey;

  @override
  int get hashCode => uniqueComparisonKey.hashCode;
}