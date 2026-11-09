// lib/constants/api_constants.dart (REPLACE FULL — auto-detect physical vs emulator, tanpa dependency baru)
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  static const String _lanIp = "10.10.50.84";
  static bool? _isPhysicalDeviceCache;

  /// Deteksi otomatis sekali (di-cache) — device fisik → true, emulator → false.
  /// Emulator Android (AVD) SELALU dapat IP 10.0.2.15 dari subnet NAT
  /// internalnya (10.0.2.0/24) — signature dikenal luas, tidak butuh
  /// package tambahan (konsisten pola `DeviceIdentifier` yang sudah pakai
  /// `dart:io` NetworkInterface, bukan device_info_plus).
  static Future<bool> _isPhysicalDevice() async {
    if (_isPhysicalDeviceCache != null) return _isPhysicalDeviceCache!;
    if (!Platform.isAndroid) {
      _isPhysicalDeviceCache = true; // iOS/desktop fallback aman
      return _isPhysicalDeviceCache!;
    }
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final isEmulator = interfaces.any((i) => i.addresses
          .any((a) => a.address.startsWith('10.0.2.')));
      _isPhysicalDeviceCache = !isEmulator;
    } catch (e) {
      _isPhysicalDeviceCache = true; // fallback aman kalau gagal deteksi
    }
    return _isPhysicalDeviceCache!;
  }

  /// Dipanggil SEKALI saat startup (main()), simpan hasilnya biar
  /// baseUrl (sync getter) bisa tetap dipakai di tempat lain tanpa
  /// perlu diubah jadi async semua.
  static Future<void> init() async {
  await _isPhysicalDevice();
  print('🔍 DEBUG baseUrl resolved: $baseUrl'); // 🆕 sementara, hapus nanti
}

  static String get baseUrl {
    if (kIsWeb) return "http://localhost:8080/api/v1";
    if (Platform.isAndroid) {
      final isPhysical = _isPhysicalDeviceCache ?? true;
      return isPhysical
          ? "http://$_lanIp:8080/api/v1"
          : "http://10.0.2.2:8080/api/v1";
    }
    return "http://localhost:8080/api/v1";
  }
}