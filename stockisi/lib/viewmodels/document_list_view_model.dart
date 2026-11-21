import 'package:flutter/foundation.dart';

import '../data/repositories/draft_repository.dart';
import '../data/repositories/reference_document_repository.dart';
import '../data/repository_exceptions.dart';
import '../models/document_type.dart';
import '../models/reference_document.dart';

enum DocumentStatusFilter {
  open('Terbuka'),
  submitted('Selesai'),
  all('Semua');

  const DocumentStatusFilter(this.label);
  final String label;
}

/// State tab Dokumen: segmen RCV/INT, pencarian, filter status, dan
/// penanda draf.
///
/// Diadaptasi dari `stockish/lib/viewmodels/reference_document_list_viewmodel.dart`
/// (pencarian lokal, filter status default menyembunyikan dokumen selesai,
/// guard `_disposed`). Status Locked dan polling tidak dibawa.
class DocumentListViewModel extends ChangeNotifier {
  final ReferenceDocumentRepository _documents;
  final DraftRepository _drafts;

  DocumentListViewModel(this._documents, this._drafts);

  DocumentType _type = DocumentType.receiving;
  String _query = '';
  DocumentStatusFilter _filter = DocumentStatusFilter.open;
  final Map<DocumentType, List<ReferenceDocument>> _cache = {};
  Set<String> _draftNumbers = {};
  bool _loading = false;
  String? _error;
  int _loadSeq = 0;
  bool _disposed = false;

  DocumentType get type => _type;
  String get query => _query;
  DocumentStatusFilter get filter => _filter;
  bool get loading => _loading;
  String? get error => _error;

  /// Semua dokumen jenis aktif, sebelum pencarian dan filter.
  List<ReferenceDocument>? get allOfType => _cache[_type];

  bool hasDraft(String number) => _draftNumbers.contains(number);

  bool get isFiltered =>
      _query.trim().isNotEmpty || _filter != DocumentStatusFilter.all;

  /// Dokumen yang tampil: OPEN dulu, lalu terbaru.
  List<ReferenceDocument> get visible {
    final q = _query.trim().toLowerCase();
    final list = (_cache[_type] ?? const <ReferenceDocument>[]).where((d) {
      final statusOk = switch (_filter) {
        DocumentStatusFilter.open => d.isOpen,
        DocumentStatusFilter.submitted => !d.isOpen,
        DocumentStatusFilter.all => true,
      };
      if (!statusOk) return false;
      if (q.isEmpty) return true;
      return d.number.toLowerCase().contains(q) ||
          d.counterparty.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        return b.documentDate.compareTo(a.documentDate);
      });
    return list;
  }

  /// Memuat dokumen jenis aktif. [silent] dipakai saat kembali dari detail:
  /// daftar lama tetap tampil selama data baru dimuat.
  Future<void> load({bool silent = false}) async {
    final seq = ++_loadSeq;
    final type = _type;
    if (!silent || _cache[type] == null) {
      _loading = true;
      _error = null;
      _notify();
    }
    try {
      final docs = await _documents.getDocuments(type);
      Set<String> drafts;
      try {
        drafts = await _drafts.getDocumentNumbersWithDraft();
      } catch (_) {
        drafts = _draftNumbers; // Penanda draf tidak boleh menggagalkan daftar.
      }
      if (seq != _loadSeq) return;
      _cache[type] = docs;
      _draftNumbers = drafts;
      _error = null;
    } on RepositoryException catch (e) {
      if (seq != _loadSeq) return;
      if (!silent || _cache[type] == null) _error = e.message;
    }
    _loading = false;
    _notify();
  }

  void setType(DocumentType type) {
    if (type == _type) return;
    _type = type;
    _error = null;
    _notify();
    load(silent: true);
  }

  void setQuery(String value) {
    _query = value;
    _notify();
  }

  void setFilter(DocumentStatusFilter value) {
    _filter = value;
    _notify();
  }

  void resetFilters() {
    _query = '';
    _filter = DocumentStatusFilter.all;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
