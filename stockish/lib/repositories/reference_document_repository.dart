import 'dart:convert';
import '../models/reference_document.dart';
import '../services/api/api_service.dart';
import 'package:flutter/foundation.dart';

/// Dilempar khusus saat lockDocument() gagal karena error koneksi/server
/// (mis. timeout, connection refused) ATAU business rule spesifik yang
/// perlu pesan beda dari SnackBar "Locked" generik (mis. rule "1 NIK = 1
/// lock aktif", 5 Agustus 2026) — dibedakan dari `return false`
/// (kasus "sudah locked/completed", itu business logic normal, bukan error).
class DocumentLockException implements Exception {
  final String message;
  DocumentLockException(this.message);

  @override
  String toString() => message;
}

/// 22 Juli 2026 — Hasil lockDocument(). Sebelumnya cuma `bool`, sekarang
/// bawa pulang `expiresAt` dari server juga — supaya LockTimerService di HP
/// menghitung mundur dari JAM YANG SAMA dengan yang dipegang server (1
/// sumber angka), bukan menghitung ulang +15 menit versinya sendiri.
class LockResult {
  final bool locked;
  final DateTime? expiresAt;
  // 🆕 FIX (clock drift) — jam SERVER saat expiresAt dihitung. Dipakai
  // LockTimerService buat kompensasi selisih jam device vs server (device
  // gudang sering tidak akurat, sync NTP jarang/tidak stabil).
  final DateTime? serverTime;
  const LockResult(this.locked, this.expiresAt, [this.serverTime]);
}

class ReferenceDocumentRepository {
  final ApiService _apiService = ApiService();

  // Cache in-memory hasil GET List terakhir — dipakai getDocument() supaya
  // tidak perlu request ulang.
  // Static supaya "nempel" antar instance Repository yang dibuat di
  // Screen berbeda, sama semangatnya dengan versi mock sebelumnya.
  static List<ReferenceDocument> _documents = [];
  static final Map<String, DocumentStatus> _statusBeforeLock = {};

  // Endpoint asli stockflow-backend (CONFIRMED PASSED 22 Juli 2026, lihat
  // 02_Feature_Reference_Document.md). warehouseName diisi dari User yang
  // login — lihat catatan factory ReferenceDocument.fromJson.
  Future<List<ReferenceDocument>> getList(String token, {String warehouseName = ''}) async {
    final response = await _apiService.get('/reference-document', token: token);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && decoded['success'] == true) {
      final data = decoded['data'] as List<dynamic>;
      _documents = data
          .map((e) => ReferenceDocument.fromJson(e as Map<String, dynamic>, warehouseName: warehouseName))
          .toList();
      return List.from(_documents);
    }

    final message = decoded['message'] as String? ?? 'Gagal mengambil daftar dokumen.';
    throw Exception(message);
  }

  /// Ambil satu dokumen by referenceNumber dari cache List terakhir. Dipakai
  /// TransactionItemRepository buat baca receivedQuantitySoFar saat generate
  /// item list.
  Future<ReferenceDocument?> getDocument(String referenceNumber) async {
    final index = _documents.indexWhere((doc) => doc.referenceNumber == referenceNumber);
    if (index == -1) return null;
    return _documents[index];
  }

  /// Dipanggil saat operator membuka dokumen. `LockResult.locked == false`
  /// kalau dokumen sudah `locked`/`completed` di server (business logic
  /// normal, pesan generik ditampilkan Screen). Throw DocumentLockException
  /// kalau gagal koneksi/server, ATAU business rule spesifik yang perlu
  /// pesan beda (mis. NIK_ALREADY_LOCKING_OTHER_DOCUMENT).
  Future<LockResult> lockDocument(String referenceNumber, String token) async {
    try {
      final response = await _apiService.post(
        '/reference-document/lock',
        {'referenceDocNo': referenceNumber},
        token: token,
        // 🆕 (5 Agustus 2026) — dedupeKey spesifik PER-DOKUMEN, bukan generik
        // per-endpoint. Dedupe generik ("POST:/reference-document/lock")
        // bikin lock dokumen A & lock dokumen B (2 aksi independen, kebetulan
        // sama-sama nembak endpoint yang sama) bisa saling cancel satu sama
        // lain — beda dari kasus Login yang memang cuma 1 concept "login"
        // yang sah cancel dirinya sendiri.
        dedupeKey: 'lock:$referenceNumber',
      );
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && decoded['success'] == true) {
        final data = decoded['data'] as Map<String, dynamic>;
        final expiresAtRaw = data['expiresAt'] as String?;
        final expiresAt = expiresAtRaw != null ? DateTime.parse(expiresAtRaw) : null;
        // 🆕 FIX (clock drift)
        final serverTimeRaw = data['serverTime'] as String?;
        final serverTime = serverTimeRaw != null ? DateTime.parse(serverTimeRaw) : null;

        final index = _documents.indexWhere((doc) => doc.referenceNumber == referenceNumber);
        if (index != -1) {
          _statusBeforeLock[referenceNumber] = _documents[index].status;
          _documents[index].status = DocumentStatus.locked;
        }
        debugPrint('🔍[LOCK] lockDocument SUKSES (server) ref=$referenceNumber expiresAt=$expiresAt serverTime=$serverTime');
        return LockResult(true, expiresAt, serverTime);
      }

      final errorCode = decoded['errorCode'] as String?;
      final message = decoded['message'] as String? ?? 'Dokumen tidak dapat dikunci.';

      // 🆕 (5 Agustus 2026) — rule "1 NIK = 1 lock aktif" butuh pesan SPESIFIK
      // (beda dari "sudah locked device lain" generik), supaya operator tahu
      // dia sendiri yang masih pegang lock di dokumen lain, bukan orang lain.
      if (errorCode == 'NIK_ALREADY_LOCKING_OTHER_DOCUMENT') {
        debugPrint('🔍[LOCK] lockDocument DITOLAK (rule 1 NIK=1 lock) ref=$referenceNumber: $message');
        throw DocumentLockException(message);
      }

      // Business logic gagal generik (sudah locked/completed oleh NIK lain)
      // — bukan error koneksi, Screen tampilkan SnackBar generik.
      debugPrint('🔍[LOCK] lockDocument DITOLAK server ref=$referenceNumber: $message');
      return const LockResult(false, null);
    } catch (e) {
      if (e is DocumentLockException) rethrow;
      debugPrint('🔍[LOCK] lockDocument GAGAL (exception) ref=$referenceNumber: $e');
      throw DocumentLockException(
        'Gagal terhubung ke server saat mengunci dokumen "$referenceNumber".',
      );
    }
  }

  // repositories/reference_document_repository.dart — TAMBAH method ini (di dalam class ReferenceDocumentRepository, tidak perlu ganti apapun yang lain)

  /// 🆕 (7 Agustus 2026) — Realtime ERP Sync. Dipanggil dari tombol Refresh
  /// List SEBELUM reload data. BEST-EFFORT — exception ditelan di sini,
  /// TIDAK dilempar ke caller, supaya refresh List TETAP jalan normal
  /// meski sync ERP gagal total (server ERP maintenance, network, dst) —
  /// konsisten prinsip "gudang tetap bisa kerja walau ERP maintenance".
  Future<void> syncAllFromErp(String token) async {
    try {
      final response = await _apiService.post('/erp-adapter/sync-all', {}, token: token);
      debugPrint('🔍[ERP SYNC] syncAllFromErp status=${response.statusCode}');
    } catch (e) {
      debugPrint('🔍[ERP SYNC] syncAllFromErp GAGAL (diabaikan, lanjut reload List): $e');
    }
  }

  /// Dipanggil saat operator keluar dari Detail tanpa submit (back manual),
  /// Cancel Lock, atau Lock Expired. Guard: hanya proses kalau status cache
  /// lokal masih `locked` — sama seperti versi mock, mencegah override status
  /// completed/partial kalau kepanggil telat/dobel.
  Future<void> unlockDocument(String referenceNumber, String token) async {
    debugPrint('🔍[LOCK] unlockDocument DIPANGGIL ref=$referenceNumber');
    final index = _documents.indexWhere((doc) => doc.referenceNumber == referenceNumber);
    if (index == -1) {
      debugPrint('🔍[LOCK] unlockDocument: dokumen tidak ketemu di cache! ref=$referenceNumber');
      return;
    }
    if (_documents[index].status != DocumentStatus.locked) {
      debugPrint('🔍[LOCK] unlockDocument DIABAIKAN (guard gagal) — status bukan locked');
      return;
    }

    try {
      final response = await _apiService.post(
        '/reference-document/unlock',
        {'referenceDocNo': referenceNumber},
        token: token,
        // 🆕 (5 Agustus 2026) — pola sama lockDocument(), spesifik per-dokumen.
        dedupeKey: 'unlock:$referenceNumber',
      );
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && decoded['success'] == true) {
        final target = _statusBeforeLock[referenceNumber] ?? DocumentStatus.available;
        _documents[index].status = target;
        debugPrint('🔍[LOCK] unlockDocument SUKSES (server) revert ref=$referenceNumber -> $target');
      } else {
        debugPrint('🔍[LOCK] unlockDocument DITOLAK server ref=$referenceNumber: ${decoded['message']}');
      }
    } catch (e) {
      debugPrint('🔍[LOCK] unlockDocument GAGAL (exception) ref=$referenceNumber: $e');
    }
    _statusBeforeLock.remove(referenceNumber);
  }
}