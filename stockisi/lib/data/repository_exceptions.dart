import 'transaction_rules.dart';

/// Kesalahan yang dilempar repository ke layar. Setiap jenis membawa pesan
/// Bahasa Indonesia yang siap ditampilkan, jadi implementasi repository
/// cukup memilih jenis yang tepat.
sealed class RepositoryException implements Exception {
  const RepositoryException();

  String get message;

  @override
  String toString() => message;
}

/// Server tidak bisa dihubungi atau gagal memproses permintaan.
class DataUnavailableException extends RepositoryException {
  const DataUnavailableException();

  @override
  String get message =>
      'Gagal memuat data. Periksa koneksi internet, lalu coba lagi.';
}

/// Tidak ada operator yang login, atau sesi sudah tidak berlaku.
class NotSignedInException extends RepositoryException {
  const NotSignedInException();

  @override
  String get message => 'Sesi berakhir. Silakan login lagi.';
}

/// Data tidak ditemukan di gudang operator.
class NotFoundException extends RepositoryException {
  const NotFoundException();

  @override
  String get message => 'Data tidak ditemukan di gudang Anda.';
}

enum AuthFailure { invalidCredentials, inactiveAccount }

class AuthException extends RepositoryException {
  final AuthFailure failure;
  const AuthException(this.failure);

  @override
  String get message {
    switch (failure) {
      case AuthFailure.invalidCredentials:
        // Satu pesan untuk NIK tidak terdaftar dan kata sandi salah.
        return 'NIK atau kata sandi salah.';
      case AuthFailure.inactiveAccount:
        return 'Akun Anda nonaktif. Hubungi admin gudang.';
    }
  }
}

enum SubmitFailure {
  /// Syarat submit belum terpenuhi. Detail di [SubmitException.check].
  rulesNotMet,

  /// Dokumen sudah SUBMITTED oleh operator lain.
  documentAlreadySubmitted,

  /// Sisa dokumen berubah sejak dibuka (ada submit lain di antaranya).
  documentChanged,
}

class SubmitException extends RepositoryException {
  final SubmitFailure failure;
  final SubmitCheck? check;

  const SubmitException(this.failure, {this.check});

  @override
  String get message {
    switch (failure) {
      case SubmitFailure.rulesNotMet:
        return check?.message ?? 'Transaksi belum bisa disubmit.';
      case SubmitFailure.documentAlreadySubmitted:
        return 'Dokumen ini sudah diselesaikan operator lain. '
            'Draf Anda dibuang.';
      case SubmitFailure.documentChanged:
        return 'Dokumen ini sudah diproses operator lain dan sisanya '
            'berubah. Draf Anda dibuang.';
    }
  }
}
