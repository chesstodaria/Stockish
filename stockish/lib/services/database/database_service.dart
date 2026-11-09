import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, 'stockflow.db');

    print('====================================');
    print('Initializing SQLite...');
    print('Database Path: $path');
    print('====================================');

    return await openDatabase(
      path,
      // 🆕 (12 Agustus 2026) — bump 4 -> 5, tambah tabel audit_log_queue
      // (antrian retry kegagalan AuditLogRepository.addLog() Mobile, lihat
      // 02_Feature_AuditTrail.md Next Improvement poin 7-8, desain
      // disepakati 6 Agustus 2026).
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    print('Creating table transaction_progress...');

    await db.execute('''
      CREATE TABLE transaction_progress (
        reference_number TEXT NOT NULL,
        item_code TEXT NOT NULL,
        actual_quantity INTEGER NOT NULL,
        is_processed INTEGER NOT NULL,
        last_updated INTEGER NOT NULL,
        processed_by_nik TEXT,
        processed_by_name TEXT,
        PRIMARY KEY (reference_number, item_code)
      )
    ''');

    print('transaction_progress created successfully.');

    await _createAuthDebugLogTable(db);
    await _createAuditLogQueueTable(db);
  }

  /// Device yang masih di v1 otomatis lewat SEMUA blok berurutan
  /// (if oldVersion < 2, lalu if oldVersion < 3, lalu if oldVersion < 4,
  /// lalu if oldVersion < 5) — sqflite panggil onUpgrade sekali dengan
  /// oldVersion asli, bukan per-versi, makanya harus blok `if` terpisah,
  /// bukan `else if`.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from v$oldVersion to v$newVersion...');
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE transaction_progress ADD COLUMN processed_by_nik TEXT',
      );
      print('Column processed_by_nik added to transaction_progress.');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE transaction_progress ADD COLUMN processed_by_name TEXT',
      );
      print('Column processed_by_name added to transaction_progress.');
    }
    if (oldVersion < 4) {
      await _createAuthDebugLogTable(db);
    }
    if (oldVersion < 5) {
      await _createAuditLogQueueTable(db);
    }
  }

  Future<void> _createAuthDebugLogTable(Database db) async {
    print('Creating table auth_debug_log...');
    await db.execute('''
      CREATE TABLE auth_debug_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts INTEGER NOT NULL,
        event TEXT NOT NULL,
        nik TEXT,
        token_suffix TEXT,
        detail TEXT
      )
    ''');
    print('auth_debug_log created successfully.');
  }

  Future<void> _createAuditLogQueueTable(Database db) async {
    print('Creating table audit_log_queue...');
    await db.execute('''
      CREATE TABLE audit_log_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL,
        payload TEXT NOT NULL,
        token TEXT NOT NULL
      )
    ''');
    print('audit_log_queue created successfully.');
  }

  Future<void> saveProgress({
    required String referenceNumber,
    required String itemCode,
    required int actualQuantity,
    required bool isProcessed,
    String? processedByNik,
    String? processedByName,
  }) async {
    final db = await database;
    await db.insert(
      'transaction_progress',
      {
        'reference_number': referenceNumber,
        'item_code': itemCode,
        'actual_quantity': actualQuantity,
        'is_processed': isProcessed ? 1 : 0,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
        'processed_by_nik': processedByNik,
        'processed_by_name': processedByName,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getProgress(String referenceNumber) async {
    final db = await database;
    return db.query(
      'transaction_progress',
      where: 'reference_number = ?',
      whereArgs: [referenceNumber],
    );
  }

  Future<void> deleteProgress(String referenceNumber) async {
    final db = await database;
    await db.delete(
      'transaction_progress',
      where: 'reference_number = ?',
      whereArgs: [referenceNumber],
    );
  }

  // ---------------------------------------------------------------------
  // 🆕 11 Agustus 2026 — Auth Debug Log
  //
  // Log diagnostik persisten (bukan debugPrint yang hilang begitu app
  // ditutup) buat investigasi "kick sesi misterius" (hipotesis ke-3,
  // lihat 02_Feature_Authentication.md Known Issues). Ditulis dari
  // SessionService (start/polling/force-logout), AuthRepository
  // (token diterima dari backend), dan SessionStorageService (token
  // disimpan ke secure storage) — supaya kalau kejadian lagi, ada
  // bukti log presisi di device itu sendiri (bukan cuma dugaan),
  // termasuk di tablet lapangan yang tidak konek IDE/Logcat.
  //
  // SENGAJA never-throw ke pemanggil (try-catch internal) dan SELALU
  // dipanggil fire-and-forget (unawaited) dari titik pemanggilan —
  // logging ini TIDAK BOLEH menambah window race baru di alur
  // login/session yang justru lagi diselidiki.
  // ---------------------------------------------------------------------

  Future<void> insertAuthLog({
    required String event,
    String? nik,
    String? tokenSuffix,
    String? detail,
  }) async {
    try {
      final db = await database;
      await db.insert('auth_debug_log', {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'event': event,
        'nik': nik,
        'token_suffix': tokenSuffix,
        'detail': detail,
      });
    } catch (e) {
      // Never-throw — kegagalan tulis log murni housekeeping, tidak
      // boleh mengganggu alur auth/session yang sedang berjalan.
      print('⚠️ insertAuthLog gagal (diabaikan): $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAuthLogs({int limit = 300}) async {
    final db = await database;
    return db.query(
      'auth_debug_log',
      orderBy: 'ts DESC',
      limit: limit,
    );
  }

  /// Purge baris lebih lama dari [retention] — dipanggil opportunistic
  /// (mis. tiap SessionService.start(), bukan scheduler terpisah) biar
  /// tabel tidak numpuk selamanya. Aman dipanggil berkali-kali.
  Future<void> purgeOldAuthLogs({Duration retention = const Duration(days: 3)}) async {
    try {
      final db = await database;
      final cutoff = DateTime.now().subtract(retention).millisecondsSinceEpoch;
      final deleted = await db.delete(
        'auth_debug_log',
        where: 'ts < ?',
        whereArgs: [cutoff],
      );
      if (deleted > 0) {
        print('🧹 purgeOldAuthLogs: $deleted baris auth_debug_log lama dihapus.');
      }
    } catch (e) {
      print('⚠️ purgeOldAuthLogs gagal (diabaikan): $e');
    }
  }

  /// Format isi auth_debug_log jadi teks siap-share (mis. lewat
  /// share_plus dari tombol UI nanti — belum dipasang, lihat
  /// 02_Feature_Authentication.md Next Improvement). Placeholder
  /// akses UI untuk tim berikutnya, method-nya sudah siap dipanggil.
  Future<String> exportAuthLogsAsText({int limit = 300}) async {
    final rows = await getAuthLogs(limit: limit);
    final buffer = StringBuffer('=== StockFlow Auth Debug Log ===\n');
    for (final row in rows) {
      final ts = DateTime.fromMillisecondsSinceEpoch(row['ts'] as int).toIso8601String();
      buffer.writeln(
        '[$ts] ${row['event']} nik=${row['nik'] ?? '-'} '
        'token=${row['token_suffix'] ?? '-'} detail=${row['detail'] ?? '-'}',
      );
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------
  // 🆕 (12 Agustus 2026) — Audit Log Queue
  //
  // Antrian retry untuk kegagalan AuditLogRepository.addLog() (mis.
  // backend/jaringan mati saat aksi terjadi) — pengganti debugPrint yang
  // cuma kebaca pas development. Payload disimpan MENTAH (JSON string,
  // termasuk field 'source': 'MOBILE' dst yang sudah dirakit
  // AuditLogRepository) supaya bisa dikirim ulang persis apa adanya tanpa
  // AuditLogRepository perlu re-derive apapun. Token disimpan terpisah
  // (dipakai ulang untuk retry) — kalau token sudah expired/invalid saat
  // flush terjadi, retry itu akan gagal lagi & baris tetap di antrian,
  // dicoba lagi flush berikutnya (tidak ada TTL/expiry di sisi queue ini,
  // sesuai desain "opportunistic", bukan garansi delivery).
  // ---------------------------------------------------------------------

  Future<void> insertQueuedAuditLog({
    required String payload,
    required String token,
  }) async {
    try {
      final db = await database;
      await db.insert('audit_log_queue', {
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'payload': payload,
        'token': token,
      });
    } catch (e) {
      // Never-throw — kalau nyimpen ke antrian pun gagal, log ini
      // beneran hilang, tapi tetap tidak boleh mengganggu aksi utama
      // (konsisten prinsip best-effort AuditLogRepository.addLog()).
      print('⚠️ insertQueuedAuditLog gagal (diabaikan): $e');
    }
  }

  Future<List<Map<String, dynamic>>> getQueuedAuditLogs() async {
    final db = await database;
    return db.query('audit_log_queue', orderBy: 'created_at ASC');
  }

  Future<void> deleteQueuedAuditLog(int id) async {
    final db = await database;
    await db.delete('audit_log_queue', where: 'id = ?', whereArgs: [id]);
  }
}