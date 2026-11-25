/// Klaim sementara atas satu dokumen referensi (tabel `document_claims`).
///
/// Kunci bersifat lunak: hanya mencegah dua operator mengerjakan dokumen
/// yang sama pada saat bersamaan. Penjaga sebenarnya tetap `version` pada
/// dokumen saat submit.
class DocumentClaim {
  final String documentNumber;
  final String holderNik;
  final String holderName;
  final DateTime claimedAt;
  final DateTime expiresAt;

  const DocumentClaim({
    required this.documentNumber,
    required this.holderNik,
    required this.holderName,
    required this.claimedAt,
    required this.expiresAt,
  });

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  Duration remainingAt(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}

/// Hasil percobaan mengklaim dokumen.
class ClaimOutcome {
  /// true kalau klaim sekarang dipegang pemanggil.
  final bool granted;

  /// Klaim yang berlaku setelah percobaan: milik sendiri (kalau granted)
  /// atau milik operator lain (kalau ditolak).
  final DocumentClaim? claim;

  const ClaimOutcome({required this.granted, this.claim});
}
