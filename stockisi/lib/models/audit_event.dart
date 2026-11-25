/// Satu jejak aktivitas operator (tabel `audit_events` di Supabase).
///
/// Ditulis oleh sisi server (trigger dan RPC), bukan oleh layar. Aplikasi
/// hanya membacanya, jadi tidak ada cara bagi klien untuk memalsukan isinya.
class AuditEvent {
  final DateTime at;

  /// NIK pelaku. Ditulis apa adanya supaya jejak tetap terbaca walaupun
  /// akunnya kelak dinonaktifkan.
  final String actorNik;

  /// Kode aksi mesin: `login`, `logout`, `claim`, `release`, `submit`,
  /// `mark_unavailable`, `force_session`.
  final String action;

  /// Jenis objek yang disentuh: `session`, `reference_document`,
  /// `transaction`.
  final String entity;

  /// Nomor dokumen atau transaksi, kalau ada.
  final String? entityId;

  /// Kalimat siap tampil, sudah Bahasa Indonesia.
  final String summary;

  const AuditEvent({
    required this.at,
    required this.actorNik,
    required this.action,
    required this.entity,
    required this.summary,
    this.entityId,
  });
}
