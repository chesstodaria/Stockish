// lib/utils/device_identifier.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 🆕 (12 Agustus 2026) — 3 komponen identifier device terpisah,
/// menggantikan 1 string gabungan yang susah dibaca di tabel Audit Trail.
class DeviceInfo {
  final String name;
  final String ip;
  final String id;
  const DeviceInfo({required this.name, required this.ip, required this.id});
}

/// Identifier device untuk Audit Trail Mobile.
/// ⚠️ Bukan production-grade, cukup buat pembeda kasar per-device di log.
///
/// 🆕 (12 Agustus 2026) — 2 revisi berturutan:
/// (1) Platform.operatingSystem → persisted UUID (yang lama SAMA PERSIS
///     untuk semua Android, bukan device identifier sama sekali).
/// (2) atas permintaan user (UUID mentah susah dibaca) — SEKARANG dipecah
///     jadi 3 komponen (getInfo(), dipetakan ke 3 field payload
///     device/deviceIp/deviceId → 3 kolom tabel Audit Trail Admin).
///
/// IP dicari FRESH tiap panggilan (bukan cache) lewat `dart:io`
/// NetworkInterface (built-in, tidak nambah dependency) — supaya kalau
/// device pindah jaringan, label ikut update. UUID (identity permanen)
/// tetap dibaca sekali dari secure storage lalu di-cache.
class DeviceIdentifier {
  static const _storageKey = 'stockflow_device_id';
  static const _storage = FlutterSecureStorage();

  static String? _cachedUuid;

  static Future<DeviceInfo> getInfo() async {
    final uuid = await _getPersistedUuid();
    final shortUuid = uuid.length >= 8 ? uuid.substring(0, 8) : uuid;
    final ip = await _getLocalIp();
    return DeviceInfo(name: Platform.operatingSystem, ip: ip, id: shortUuid);
  }

  static Future<String> _getPersistedUuid() async {
    if (_cachedUuid != null) return _cachedUuid!;

    try {
      final existing = await _storage.read(key: _storageKey);
      if (existing != null && existing.isNotEmpty) {
        _cachedUuid = existing;
        return _cachedUuid!;
      }

      final newId = _generateUuidV4();
      await _storage.write(key: _storageKey, value: newId);
      _cachedUuid = newId;
    } catch (e) {
      _cachedUuid = 'unknown-${_generateUuidV4()}';
    }

    return _cachedUuid!;
  }

  static Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      // fall through
    }
    return 'no-ip';
  }

  static String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}