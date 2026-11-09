import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/reference_document.dart';
import '../repositories/reference_document_repository.dart';

/// Validasi ulang lock dokumen yang sedang dibuka di Transaction Detail —
/// menutup gap "operator tidak tahu dokumennya sudah di-force-unlock Admin,
/// baru ketahuan pas Submit ditolak" (Known Issues 02_Feature_ForceUnlockAdmin.md).
///
/// Pola SAMA PERSIS SessionService: singleton, ChangeNotifier, Timer.periodic
/// + WidgetsBindingObserver (cek ulang saat app resume), event-based (bukan
/// context.watch), fail-open (network error TIDAK dianggap lock hilang).
///
/// BEDA dari SessionService: start()/stop() di-scope ke SIKLUS HIDUP
/// Transaction Detail (initState/dispose), BUKAN global sepanjang app hidup
/// (sesi login) — karena validasi ini cuma relevan selagi operator sedang
/// mengerjakan 1 dokumen tertentu.
///
/// TIDAK ada endpoint baru — reuse GET /reference-document (List) yang sudah
/// ada, cari baris yang match referenceNumber, cek statusnya masih `locked`
/// atau tidak. Kalau berubah (force-unlock ATAU auto-expired di server ATAU
/// sebab lain), diperlakukan SAMA — operator sudah tidak lagi memegang lock
/// ini, apa pun sebabnya persis.
enum LockValidationEventType { lost, stillValid }

class LockValidationEvent {
  final LockValidationEventType type;
  final String referenceNumber;
  const LockValidationEvent(this.type, this.referenceNumber);
}

class LockValidationService extends ChangeNotifier with WidgetsBindingObserver {
  static final LockValidationService _instance = LockValidationService._internal();
  factory LockValidationService() => _instance;
  LockValidationService._internal();

  final ReferenceDocumentRepository _docRepository = ReferenceDocumentRepository();

  // Interval sama filosofinya dengan SessionService (window 3-5 menit
  // production, dipercepat kDebugMode biar gampang dites).
  static final Duration pollInterval =
      kDebugMode ? const Duration(seconds: 30) : const Duration(minutes: 4);

  Timer? _pollTimer;
  String? _referenceNumber;
  String? _token;
  bool _isActive = false;

  LockValidationEvent? _lastEvent;
  LockValidationEvent? get lastEvent => _lastEvent;
  bool get isActive => _isActive;

  /// Dipanggil dari initState() TransactionDetailScreen, setelah lock sukses.
  void start(String referenceNumber, String token) {
    _referenceNumber = referenceNumber;
    _token = token;
    _isActive = true;
    _lastEvent = null;
    WidgetsBinding.instance.addObserver(this);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => checkNow());
    debugPrint('🔍[LOCKCHECK] start() ref=$referenceNumber, interval=$pollInterval');
  }

  /// Dipanggil dari dispose() TransactionDetailScreen — WAJIB, supaya polling
  /// tidak nyangkut jalan setelah operator sudah keluar dari Detail.
  void stop() {
    debugPrint('🔍[LOCKCHECK] stop()');
    _pollTimer?.cancel();
    _pollTimer = null;
    _isActive = false;
    _referenceNumber = null;
    _token = null;
    _lastEvent = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isActive) return;
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔍[LOCKCHECK] app resumed, cek ulang');
      checkNow();
    }
  }

  /// Dipanggil polling internal (silent, tidak emit apa-apa kalau masih valid
  /// — sama filosofi SessionService: cuma ribut kalau ada masalah) MAUPUN
  /// tombol Refresh manual di AppBar Detail (silent:false, emit `stillValid`
  /// juga supaya operator dapat feedback eksplisit "sudah dicek, masih aman").
  ///
  /// Fail-open: network error/gagal koneksi TIDAK dianggap lock hilang —
  /// diam saja, sama seperti checkSessionOnce() unknown status.
  Future<void> checkNow({bool silent = true}) async {
    if (!_isActive || _referenceNumber == null || _token == null) return;

    try {
      final docs = await _docRepository.getList(_token!);
      final matches = docs.where((d) => d.referenceNumber == _referenceNumber);
      final stillLocked = matches.isNotEmpty && matches.first.status == DocumentStatus.locked;

      if (!stillLocked) {
        debugPrint('🔍[LOCKCHECK] ref=$_referenceNumber TIDAK locked lagi — trigger lost');
        _lastEvent = LockValidationEvent(LockValidationEventType.lost, _referenceNumber!);
        notifyListeners();
      } else if (!silent) {
        debugPrint('🔍[LOCKCHECK] ref=$_referenceNumber masih locked (refresh manual)');
        _lastEvent = LockValidationEvent(LockValidationEventType.stillValid, _referenceNumber!);
        notifyListeners();
      }
      // stillLocked && silent (polling normal) → diam, tidak emit apa-apa.
    } catch (e) {
      debugPrint('🔍[LOCKCHECK] gagal cek (network/server), diabaikan (fail-open): $e');
    }
  }
}