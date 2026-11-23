# Stockisi

Aplikasi mobile WMS (Warehouse Management System) untuk operator gudang
manufaktur. Operator menerima barang dari vendor (**Receiving**), mengeluarkan
atau mentransfer barang (**Intransit**), memeriksa stok lewat kartu stok, dan
membuka label QR barang.

Final project mata kuliah Teknologi Berkembang, kelas B, Kelompok 2,
Departemen Sistem Informasi ITS, tahun ajaran 2026/2027.

## Isi repo

| Path | Isi |
| :--- | :--- |
| `stockisi/` | Aplikasi Flutter yang dikerjakan sekarang |
| `stockish/` | Aplikasi lama milik salah satu anggota. **Hanya dibaca** sebagai referensi perilaku, tidak dijalankan dan tidak diubah |
| `docs/` | Dokumen kerja kelompok |
| `AGENTS.md` | Aturan kerja untuk agen AI yang membuka repo ini |

## Dokumen

| Berkas | Isi |
| :--- | :--- |
| [`docs/CONTEXT.md`](docs/CONTEXT.md) | Fakta dan keputusan yang sudah disepakati: cakupan, aturan bisnis, customer journey, rancangan data, arah desain |
| [`docs/PLAN.md`](docs/PLAN.md) | Urutan tahap pengerjaan beserta syarat "selesai kalau" |
| [`docs/PROGRESS.md`](docs/PROGRESS.md) | Catatan kemajuan antarsesi: apa yang sudah jadi, keputusan teknis, pertanyaan terbuka |
| [`docs/PENGEMBANGAN-UI.md`](docs/PENGEMBANGAN-UI.md) | Backlog perbaikan tampilan yang belum dijadwalkan |
| [`docs/referensi/`](docs/referensi/) | Laporan kelompok (Bab 2 jadi acuan cakupan) |

`docs/referensi/arsip/` berisi dokumen lama yang **tidak normatif**. Jangan
pakai isinya sebagai acuan.

## Menjalankan aplikasi

Prasyarat: Flutter stable dengan Dart **3.12.2 atau lebih baru** (diuji di
Flutter 3.44.5). Batas versi di `stockisi/pubspec.yaml` sengaja dilonggarkan
supaya bisa jalan di Flutter 3.44.5 maupun 3.47.9.

```bash
cd stockisi
flutter pub get
flutter run -d chrome     # target utama untuk demo dan pengujian
```

Target lain yang tersedia: `flutter run -d windows`, atau emulator Android
(`flutter emulators --launch Medium_Tablet`).

Pemeriksaan sebelum demo atau sebelum commit:

```bash
cd stockisi
flutter analyze
flutter test
```

## Akun demo

Data berasal dari repository tiruan di memori, jadi **isi ulang halaman akan
mengembalikan semua data ke kondisi awal**.

| NIK | Nama | Gudang | Status |
| :--- | :--- | :--- | :--- |
| `210457` | Budi Santoso | WH01 Gudang Bahan Baku Sidoarjo | aktif |
| `210512` | Rina Wulandari | WH01 | aktif |
| `220118` | Siti Rahmawati | WH02 Gudang Barang Jadi Pasuruan | aktif |
| `198803` | Agus Prasetyo | WH01 | nonaktif |

Kata sandi semua akun: `stockisi123`.

## Status

13 layar pada Tabel 2.1 laporan. **Semuanya sudah jalan** (tidak ada lagi
layar placeholder). Rincian per tahap ada di
[`docs/PROGRESS.md`](docs/PROGRESS.md), dan skrip presentasi di
[`docs/DEMO.md`](docs/DEMO.md).

Data masih tiruan (mock). Layer data Supabase dikerjakan anggota kelompok lain
di tahap berikutnya; layar tidak tahu dari mana datanya berasal, jadi
perpindahan cukup dengan mengganti implementasi repository.
