import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Identitas perangkat untuk pengecekan sesi tunggal.
///
/// Dibuat sekali lalu disimpan di penyimpanan aman perangkat. Nilainya bukan
/// rahasia, hanya penanda supaya server bisa membedakan "perangkat yang sama"
/// dari "perangkat lain".
class DeviceIdStore {
  static const _key = 'stockisi_device_id';
  static const _timeout = Duration(seconds: 3);

  final FlutterSecureStorage? _storage;
  final String? _fixed;
  String? _cached;

  DeviceIdStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage(),
        _fixed = null;

  /// Nilai tetap, dipakai di test supaya tidak bergantung pada plugin
  /// penyimpanan yang tidak tersedia di lingkungan pengujian.
  DeviceIdStore.fixed(String id)
      : _storage = null,
        _fixed = id;

  Future<String> read() async {
    final fixed = _fixed;
    if (fixed != null) return fixed;
    final cached = _cached;
    if (cached != null) return cached;

    final storage = _storage!;
    try {
      final existing = await storage.read(key: _key).timeout(_timeout);
      if (existing != null && existing.isNotEmpty) return _cached = existing;
    } catch (_) {
      // Penyimpanan tidak bisa dibaca atau terlalu lama: pakai id sementara.
      // Ini juga yang terjadi di lingkungan tanpa plugin penyimpanan.
    }
    final id = _generate();
    try {
      await storage.write(key: _key, value: id).timeout(_timeout);
    } catch (_) {
      // Gagal menyimpan tidak boleh menghalangi login.
    }
    return _cached = id;
  }

  static String _generate() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
