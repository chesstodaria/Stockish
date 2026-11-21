/// Jarak, radius, dan ukuran sentuh. Semua dalam dp.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Jarak tepi layar kiri dan kanan.
  static const screen = 16.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

abstract final class AppSize {
  /// Target sentuh minimum (CONTEXT 9).
  static const minTouch = 48.0;

  /// Tinggi tombol aksi utama seperti Scan, Submit, Simpan.
  static const primaryButton = 56.0;

  static const iconSm = 18.0;
  static const iconMd = 24.0;
  static const iconLg = 48.0;
}
