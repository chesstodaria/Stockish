import '../../models/draft.dart';
import '../repositories/draft_repository.dart';
import '../../services/session_store.dart';

/// Draf transaksi di perangkat, tanpa server.
///
/// `CONTEXT` §8 mencatat bahwa tempat draf belum diputuskan kelompok. Sampai
/// keputusan itu diambil, draf tetap di perangkat seperti teks laporan:
/// disimpan di memori selama app berjalan, dan hilang saat app ditutup.
/// Kontraknya sama, jadi memindahkannya ke Supabase nanti tidak menyentuh
/// layar.
class LocalDraftRepository implements DraftRepository {
  final SessionStore _session;
  final Map<String, Map<String, Draft>> _byNik = {};

  LocalDraftRepository(this._session);

  Future<Map<String, Draft>> _store() async {
    final nik = await _session.readNik() ?? '';
    return _byNik.putIfAbsent(nik, () => {});
  }

  @override
  Future<Draft?> getDraft(String documentNumber) async {
    final store = await _store();
    return store[documentNumber];
  }

  @override
  Future<Set<String>> getDocumentNumbersWithDraft() async {
    final store = await _store();
    return store.keys.toSet();
  }

  @override
  Future<void> saveDraft(Draft draft) async {
    final store = await _store();
    store[draft.documentNumber] = draft;
  }

  @override
  Future<void> deleteDraft(String documentNumber) async {
    final store = await _store();
    store.remove(documentNumber);
  }
}
