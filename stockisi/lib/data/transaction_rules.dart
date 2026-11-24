import '../models/document_type.dart';
import '../models/draft.dart';
import '../models/reference_document.dart';

/// Aturan bisnis transaksi (CONTEXT bagian 6) dalam bentuk fungsi murni.
///
/// Dipakai dua pihak: layar memakainya untuk umpan balik langsung, dan
/// repository memakainya untuk menegakkan aturan saat submit. Implementasi
/// Supabase tetap wajib menegakkan aturan yang sama di RPC submit.

/// Status item, dihitung dari input dan tidak disimpan terpisah.
enum ItemStatus {
  /// Belum diperiksa: belum ada input dan belum ditandai "Tidak tersedia".
  pending('Belum'),

  /// Input lebih dari 0 tetapi kurang dari sisa, atau ditandai
  /// "Tidak tersedia".
  partial('Parsial'),

  /// Input sama dengan sisa.
  complete('Selesai'),

  /// Sisa sudah 0 sejak awal (terpenuhi di transaksi Partial sebelumnya).
  /// Tidak ikut dihitung dan tidak bisa diinput.
  fulfilled('Sudah terpenuhi');

  const ItemStatus(this.label);
  final String label;
}

ItemStatus itemStatusOf(ReferenceDocumentItem item, DraftLine? line) {
  if (item.isFulfilled) return ItemStatus.fulfilled;
  if (line == null) return ItemStatus.pending;
  if (line.markedUnavailable) return ItemStatus.partial;
  if (line.quantity <= 0) return ItemStatus.pending;
  if (line.quantity < item.remainingQuantity) return ItemStatus.partial;
  return ItemStatus.complete;
}

enum QuantityProblem { notPositive, exceedsRemaining, exceedsStock }

/// Pelanggaran batas kuantitas, beserta batasnya untuk ditampilkan.
class QuantityViolation {
  final QuantityProblem problem;
  final String itemCode;
  final int limit;
  final String uom;

  const QuantityViolation({
    required this.problem,
    required this.itemCode,
    required this.limit,
    required this.uom,
  });

  String get message {
    switch (problem) {
      case QuantityProblem.notPositive:
        return 'Kuantitas harus lebih dari 0.';
      case QuantityProblem.exceedsRemaining:
        return 'Melebihi sisa dokumen. Maksimal $limit $uom.';
      case QuantityProblem.exceedsStock:
        return 'Melebihi stok tersedia. Maksimal $limit $uom.';
    }
  }
}

/// Memeriksa total kuantitas baru untuk satu item.
///
/// [newTotal] adalah nilai akhir setelah input: hasil penjumlahan untuk
/// scan atau input manual, atau nilai pengganti untuk ubah dari kartu item.
QuantityViolation? checkQuantity(ReferenceDocumentItem item, int newTotal) {
  if (newTotal <= 0) {
    return QuantityViolation(
      problem: QuantityProblem.notPositive,
      itemCode: item.itemCode,
      limit: 0,
      uom: item.uom,
    );
  }
  if (newTotal > item.remainingQuantity) {
    return QuantityViolation(
      problem: QuantityProblem.exceedsRemaining,
      itemCode: item.itemCode,
      limit: item.remainingQuantity,
      uom: item.uom,
    );
  }
  final stock = item.availableStock;
  if (stock != null && newTotal > stock) {
    return QuantityViolation(
      problem: QuantityProblem.exceedsStock,
      itemCode: item.itemCode,
      limit: stock,
      uom: item.uom,
    );
  }
  return null;
}

enum SubmitProblem { pendingItems, missingDeliveryNo, invalidQuantity }

/// Hasil pemeriksaan syarat submit.
class SubmitCheck {
  final SubmitProblem problem;
  final int pendingCount;
  final QuantityViolation? quantityViolation;

  const SubmitCheck(
    this.problem, {
    this.pendingCount = 0,
    this.quantityViolation,
  });

  String get message {
    switch (problem) {
      case SubmitProblem.pendingItems:
        return 'Masih ada $pendingCount item Pending. Periksa semua item dulu.';
      case SubmitProblem.missingDeliveryNo:
        return 'Nomor surat jalan vendor wajib diisi.';
      case SubmitProblem.invalidQuantity:
        return quantityViolation!.message;
    }
  }
}

/// Memeriksa syarat submit. Mengembalikan null kalau boleh submit.
SubmitCheck? checkSubmit({
  required ReferenceDocument document,
  required Map<String, DraftLine> lines,
  String? vendorDeliveryNo,
}) {
  final pending = document.items
      .where((i) => itemStatusOf(i, lines[i.itemCode]) == ItemStatus.pending)
      .length;
  if (pending > 0) {
    return SubmitCheck(SubmitProblem.pendingItems, pendingCount: pending);
  }
  if (document.type == DocumentType.receiving &&
      (vendorDeliveryNo == null || vendorDeliveryNo.trim().isEmpty)) {
    return const SubmitCheck(SubmitProblem.missingDeliveryNo);
  }
  for (final item in document.items) {
    final line = lines[item.itemCode];
    if (item.isFulfilled || line == null || line.markedUnavailable) continue;
    final violation = checkQuantity(item, line.quantity);
    if (violation != null) {
      return SubmitCheck(
        SubmitProblem.invalidQuantity,
        quantityViolation: violation,
      );
    }
  }
  return null;
}

/// Jumlah item Partial. Kalau lebih dari 0, operator harus memilih
/// Simpan sebagai Partial atau Tandai Selesai.
int partialCountOf(ReferenceDocument document, Map<String, DraftLine> lines) {
  return document.items
      .where((i) => itemStatusOf(i, lines[i.itemCode]) == ItemStatus.partial)
      .length;
}
