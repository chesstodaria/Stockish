import 'package:flutter/material.dart';

/// Token gerak (motion).
///
/// Nilainya mengikuti panduan Apple *Designing Fluid Interfaces*: respons
/// harus terasa seketika, perubahan kecil memakai kurva keluar yang cepat,
/// dan gerakan besar tidak boleh melebihi ~0,3 detik. Semua durasi di sini
/// dipangkas menjadi nol saat pengguna meminta gerak dikurangi
/// (`MediaQuery.disableAnimations`), supaya aksesibilitas tidak dilanggar.
abstract final class AppMotion {
  /// Umpan balik tekan. Harus terasa seketika (Apple: response on press).
  static const press = Duration(milliseconds: 120);

  /// Perubahan state kecil: chip, warna, opacity.
  static const quick = Duration(milliseconds: 180);

  /// Perpindahan konten standar: daftar berganti filter, sheet muncul.
  static const standard = Duration(milliseconds: 280);

  /// Gerakan besar yang butuh kesan tenang.
  static const gentle = Duration(milliseconds: 420);

  /// Kurva masuk. Setara spring damping 1,0 tanpa overshoot.
  static const enter = Curves.easeOutCubic;

  /// Kurva keluar. Cermin dari [enter] supaya jalur balik konsisten
  /// (Apple: mirror the easing on reversible transitions).
  static const exit = Curves.easeInCubic;

  /// Skala saat elemen ditekan. Kecil saja; ini isyarat, bukan animasi.
  static const pressedScale = 0.98;

  /// Durasi yang menghormati preferensi gerak dikurangi.
  static Duration of(BuildContext context, Duration duration) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return reduce ? Duration.zero : duration;
  }

  /// Kurva yang menghormati preferensi gerak dikurangi: tanpa kurva berarti
  /// perubahan langsung, yang justru lebih aman bagi pengguna vestibular.
  static Curve curveOf(BuildContext context, Curve curve) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return reduce ? Curves.linear : curve;
  }
}
