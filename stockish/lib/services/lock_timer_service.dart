// lib/services/lock_timer_service.dart (REPLACE FULL — FIX clock drift, 19 Agustus 2026)
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/reference_document_repository.dart';
import 'app_settings_cache.dart';

enum LockTimerEventType { warning, expired, reset }

class LockTimerEvent {
  final LockTimerEventType type;
  final String referenceNumber;
  const LockTimerEvent(this.type, this.referenceNumber);
}

class LockTimerService extends ChangeNotifier {
  LockTimerService._internal();
  static final LockTimerService _instance = LockTimerService._internal();
  factory LockTimerService() => _instance;

  final ReferenceDocumentRepository _docRepository = ReferenceDocumentRepository();

  // 🆕 FIX (clock drift, 19 Agustus 2026) — selisih jam SERVER vs jam
  // DEVICE, dihitung tiap kali server ngasih serverTime (lock/reclaim).
  // Dipakai gantiin DateTime.now() mentah di SELURUH perhitungan timer —
  // supaya timer akurat berapapun jam device meleset (tablet gudang sering
  // jarang sync NTP stabil, "Automatic date & time" nyala pun bisa tetap
  // drift beberapa puluh detik).
  Duration _clockOffset = Duration.zero;

  DateTime _correctedNow() => DateTime.now().add(_clockOffset);

  void _updateClockOffset(DateTime? serverTime) {
    if (serverTime == null) return;
    _clockOffset = serverTime.difference(DateTime.now());
    debugPrint('🔍[LOCK] clock offset diupdate: $_clockOffset');
  }

  // 🔧 (18 Agustus 2026) — GANTI dari `static final` (dihitung sekali saat
  // class load) jadi GETTER (dihitung tiap dipanggil) — baca
  // AppSettingsCache dulu (Setting Sesi Mobile dari Admin), fallback ke
  // default 15 menit kalau cache belum ke-load/gagal. kDebugMode TETAP
  // diprioritaskan di atas server — iterasi testing lokal tidak terganggu
  // oleh nilai Admin, konsisten perilaku lama. TIDAK ADA titik pemanggilan
  // manapun yang perlu diubah — `LockTimerService.lockDuration` tetap
  // dipanggil persis sama seperti sebelumnya.
  static Duration get lockDuration {
    if (kDebugMode) return const Duration(seconds: 60);
    final minutes = AppSettingsCache().lockTimerMinutes;
    return minutes != null ? Duration(minutes: minutes) : const Duration(minutes: 15);
  }

  // 🔧 (26 Agustus 2026) — GANTI dari static final konstan (5 menit tetap)
// jadi getter PERSENTASE dari lockDuration — supaya proporsional ke
// berapapun Lock Timer di-set Admin, tidak lagi bisa "kebalik" (warning
// 5 menit padahal lock cuma 1 menit). 33% dipilih supaya angka default
// lama (5 menit dari 15 menit) tetap sama persis, tidak ada regresi
// perilaku production yang sudah CONFIRMED PASSED sebelumnya.
// kDebugMode TETAP hardcoded 10 detik (tidak diubah) — biar iterasi
// testing lokal tidak ikut kena efek AppSettingsCache, konsisten filosofi
// "kDebugMode diprioritaskan di atas server" yang sudah ada di lockDuration.
static Duration get warningBefore {
  if (kDebugMode) return const Duration(seconds: 10);
  final totalSeconds = lockDuration.inSeconds;
  final warningSeconds = (totalSeconds * 0.33).round();
  return Duration(seconds: warningSeconds);
}

  static final Duration retryWindow = kDebugMode
      ? const Duration(seconds: 20)
      : const Duration(minutes: 5);

  static const Duration _tickInterval = Duration(seconds: 1);

  String? _referenceNumber;
  // BARU (29 Juli 2026) — disimpan dari start(), dibutuhkan resetOnActivity()
  // buat nembak ulang lockDocument() ke backend di production (reclaim,
  // NIK sama, guard sudah ada di server — lihat ReferenceDocumentService.lock()).
  String? _token;
  Timer? _expiryTimer;
  Timer? _warningTimer;
  Timer? _tickTimer;
  bool _isFrozen = false;

  DateTime? _endTime;

  LockTimerEvent? _lastEvent;
  LockTimerEvent? get lastEvent => _lastEvent;

  String? get activeReferenceNumber => _referenceNumber;
  bool get isFrozen => _isFrozen;
  bool get isActive => _referenceNumber != null;

  Duration get remaining {
    if (_endTime == null || _isFrozen) return Duration.zero;
    // 🔧 FIX (clock drift) — pakai _correctedNow(), bukan DateTime.now() mentah.
    final diff = _endTime!.difference(_correctedNow());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// 29 Juli 2026 — tambah parameter token (opsional, disimpan buat
  /// resetOnActivity() di production). Kalau tidak dikasih, resetOnActivity()
  /// fallback ke local duration (sama seperti perilaku lama) — supaya titik
  /// pemanggilan lama yang belum sempat diupdate tidak langsung rusak.
  /// 🆕 FIX (clock drift, 19 Agustus 2026) — tambah parameter serverTime
  /// (opsional). Pemanggil lama yang belum sempat diupdate tetap jalan
  /// (fallback _clockOffset = Duration.zero, sama seperti perilaku lama).
  void start(String referenceNumber, {DateTime? expiresAt, String? token, DateTime? serverTime}) {
    debugPrint('🔍[LOCK] TimerService.start() ref=$referenceNumber expiresAt=$expiresAt @ ${DateTime.now()}');
    _referenceNumber = referenceNumber;
    _token = token;
    _isFrozen = false;
    _lastEvent = null;
    _updateClockOffset(serverTime); // 🆕 FIX

    final duration = expiresAt != null
        ? expiresAt.difference(_correctedNow()) // 🔧 FIX
        : lockDuration;
    _restartCycle(duration.isNegative ? Duration.zero : duration, withWarning: true);
  }

  /// 29 Juli 2026 — REDESAIN. Debug mode: TETAP lokal murni & instan (tidak
  /// nembak backend), biar iterasi testing tetap cepat. Production: nembak
  /// ulang lockDocument() ke server (reclaim), pakai expiresAt ASLI dari
  /// response — timer production sekarang 100% cerminan backend, tidak ada
  /// lagi 2 sumber angka yang bisa mismatch (dulu: lockDuration lokal vs
  /// expiresAt server, kebetulan sama-sama 15 menit di production, tapi
  /// rawan drift kalau salah satu diubah tanpa ubah yang lain).
  /// Async sekarang (dulu sync) — pemanggil (mis. onPressed Save Item) yang
  /// SUDAH async tidak perlu berubah, tinggal tambah `await`.
  Future<void> resetOnActivity() async {
    if (_referenceNumber == null || _isFrozen) return;

    if (kDebugMode) {
      _restartCycle(lockDuration, withWarning: true);
      _emit(LockTimerEventType.reset);
      return;
    }

    if (_token == null) {
      // Fallback aman kalau token somehow belum sempat di-set (titik
      // pemanggilan lama) — tetap jalan pakai local duration, bukan diam
      // tanpa reset sama sekali.
      debugPrint('🔍[LOCK] resetOnActivity: token null, fallback ke local duration');
      _restartCycle(lockDuration, withWarning: true);
      _emit(LockTimerEventType.reset);
      return;
    }

    try {
      final result = await _docRepository.lockDocument(_referenceNumber!, _token!);
      if (result.locked && result.expiresAt != null) {
        _updateClockOffset(result.serverTime); // 🆕 FIX
        final duration = result.expiresAt!.difference(_correctedNow()); // 🔧 FIX
        _restartCycle(duration.isNegative ? Duration.zero : duration, withWarning: true);
        _emit(LockTimerEventType.reset);
        debugPrint('🔍[LOCK] resetOnActivity: reclaim sukses, expiresAt=${result.expiresAt}');
      } else {
        // Reclaim ditolak (mis. lock somehow sudah lepas/diambil device lain
        // di antara waktu ini) — JANGAN reset timer lokal dengan angka
        // asal-asalan, biarkan timer lama tetap jalan apa adanya. Kalau
        // lock beneran sudah hilang, LockValidationService (polling
        // terpisah) yang akan mendeteksi & menangani lewat _handleLockLost().
        debugPrint('🔍[LOCK] resetOnActivity: reclaim DITOLAK server, timer TIDAK direset');
      }
    } catch (e) {
      debugPrint('🔍[LOCK] resetOnActivity: reclaim gagal (network), timer TIDAK direset: $e');
    }
  }

  void freeze() {
    debugPrint('🔍[LOCK] TimerService.freeze() ref=$_referenceNumber @ ${DateTime.now()}');
    _isFrozen = true;
    _cancelTimers();
  }

  void unfreezeToSliding() {
    if (_referenceNumber == null) return;
    debugPrint('🔍[LOCK] TimerService.unfreezeToSliding() ref=$_referenceNumber @ ${DateTime.now()}');
    _isFrozen = false;
    _restartCycle(lockDuration, withWarning: true);
    _emit(LockTimerEventType.reset);
  }

  void unfreezeWithRetryWindow() {
    if (_referenceNumber == null) return;
    debugPrint('🔍[LOCK] TimerService.unfreezeWithRetryWindow() ref=$_referenceNumber @ ${DateTime.now()} — mulai timer 5 menit');
    _isFrozen = false;
    _restartCycle(retryWindow, withWarning: false);
  }

  void cancel() {
    debugPrint('🔍[LOCK] TimerService.cancel() ref=$_referenceNumber @ ${DateTime.now()}');
    _cancelTimers();
    _referenceNumber = null;
    _token = null;
    _isFrozen = false;
    _endTime = null;
    _lastEvent = null;
  }

  void _restartCycle(Duration duration, {required bool withWarning}) {
    _cancelTimers();
    _endTime = _correctedNow().add(duration); // 🔧 FIX

    if (withWarning) {
      final warningAfter = duration - warningBefore;
      if (warningAfter > Duration.zero) {
        _warningTimer = Timer(warningAfter, () {
          final ref = _referenceNumber;
          if (ref != null) _emit(LockTimerEventType.warning, ref);
        });
      }
    }

    _expiryTimer = Timer(duration, () {
      final ref = _referenceNumber;
      debugPrint('🔍[LOCK] _expiryTimer FIRED ref=$ref duration=$duration @ ${DateTime.now()}');
      cancel();
      if (ref != null) _emit(LockTimerEventType.expired, ref);
    });

    _tickTimer = Timer.periodic(_tickInterval, (_) => notifyListeners());
  }

  void _cancelTimers() {
    _expiryTimer?.cancel();
    _warningTimer?.cancel();
    _tickTimer?.cancel();
    _expiryTimer = null;
    _warningTimer = null;
    _tickTimer = null;
  }

  void _emit(LockTimerEventType type, [String? referenceNumber]) {
    _lastEvent = LockTimerEvent(type, referenceNumber ?? _referenceNumber ?? '');
    debugPrint('🔍[LOCK] _emit() type=$type ref=${_lastEvent!.referenceNumber} @ ${DateTime.now()} — akan notifyListeners()');
    notifyListeners();
  }
}