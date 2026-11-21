import '../../models/document_type.dart';
import '../../models/reference_document.dart';

/// Dokumen referensi RCV dan INT di gudang operator.
abstract class ReferenceDocumentRepository {
  /// Semua dokumen satu jenis di gudang operator, OPEN maupun SUBMITTED,
  /// terbaru dulu. Pencarian dan filter status dilakukan di layar.
  ///
  /// Setiap item sudah membawa `processedQuantity`, sehingga sisa dan
  /// progres Partial bisa dihitung tanpa panggilan lain.
  ///
  /// Melempar `DataUnavailableException` kalau gagal memuat.
  Future<List<ReferenceDocument>> getDocuments(DocumentType type);

  /// Satu dokumen dalam kondisi terbaru. Untuk INT, setiap item membawa
  /// `availableStock` (saldo saat ini) sebagai batas pengeluaran.
  ///
  /// Melempar `NotFoundException` kalau dokumen tidak ada di gudang
  /// operator, dan `DataUnavailableException` kalau gagal memuat.
  Future<ReferenceDocument> getDocument(String number);
}
