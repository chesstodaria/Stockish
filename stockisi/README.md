# Stockisi

Aplikasi Flutter untuk operator gudang manufaktur: Receiving, Intransit, Kartu
Stok, Label QR, dan Riwayat transaksi.

Dokumen proyek ada di folder [`../docs/`](../docs/), dan aturan kerja untuk
agen AI ada di [`../AGENTS.md`](../AGENTS.md).

## Menjalankan

Butuh Flutter stable dengan Dart **3.12.2 atau lebih baru**. Diuji di Flutter
3.44.5 (Dart 3.12.2) dan 3.47.9 (Dart 3.13.7).

```bash
flutter pub get
flutter run -d chrome
```

Target lain: `flutter run -d windows`, atau emulator Android
(`flutter emulators --launch Medium_Tablet`).

## Memeriksa

```bash
flutter analyze     # harus "No issues found!"
flutter test        # 127 test
```

## Akun demo

Kata sandi semua akun: `stockisi123`.

| NIK | Nama | Gudang | Status |
| :--- | :--- | :--- | :--- |
| `210457` | Budi Santoso | WH01 Gudang Bahan Baku Sidoarjo | aktif |
| `210512` | Rina Wulandari | WH01 | aktif |
| `220118` | Siti Rahmawati | WH02 Gudang Barang Jadi Pasuruan | aktif |
| `198803` | Agus Prasetyo | WH01 | nonaktif |

Data berasal dari repository tiruan di memori (`lib/data/mock/`), jadi isi
ulang halaman akan mengembalikan data ke kondisi awal.

## Struktur

```
lib/
├── main.dart              titik komposisi, satu-satunya tempat memilih
│                          implementasi repository
├── app.dart               MaterialApp + MultiProvider + locale id
├── models/                bentuk data, mengikuti 8 tabel laporan bagian 2.7
├── data/
│   ├── transaction_rules.dart   aturan bisnis CONTEXT bagian 6 sebagai
│   │                            fungsi murni
│   ├── repositories/            lima kontrak repository
│   └── mock/                    backend tiruan di memori + data dummy
├── screens/               layar, mengikuti Tabel 2.1 laporan
├── viewmodels/            state per layar (provider)
├── services/              format, sesi, peluncur scanner, payload QR
├── theme/                 satu-satunya sumber warna, jarak, dan gaya teks
└── widgets/               komponen yang dipakai lebih dari satu layar
```

Layar tidak tahu dari mana datanya berasal. Untuk pindah ke Supabase, cukup
buat lima kelas yang mengimplementasikan kontrak di
`lib/data/repositories/`, lalu ganti pembuatan `Repositories` di `main.dart`.

## Package

| Package | Dipakai untuk |
| :--- | :--- |
| `provider` | state management, sama dengan aplikasi lama |
| `flutter_localizations` | locale `id` |
| `flutter_secure_storage` | menyimpan sesi di perangkat |
| `mobile_scanner` | memindai QR barang |
| `barcode` | menggambar QR di layar Label QR |
| `intl` | format tanggal dan angka |

Batas versi `intl` dan `sdk` di `pubspec.yaml` sengaja lebih longgar dari yang
dipakai saat pengembangan, supaya proyek bisa dibuka di Flutter 3.44.5 maupun
3.47.9.
