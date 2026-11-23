# Pengembangan UI Stockisi

Backlog perbaikan tampilan. **Belum dijadwalkan** dan tidak boleh dikerjakan
sebelum Tahap 5 selesai.

Dokumen ini bukan daftar keinginan. Isinya temuan yang bisa dibuktikan di kode,
beserta batas yang tidak boleh dilanggar saat mengerjakannya.

## Catatan penting: §2.6 laporan masih kosong

Laporan kelompok bagian **2.6 "Tampilan Screen"** ternyata belum berisi apa pun;
hanya judul, langsung disusul §2.7. Jadi belum ada rancangan tampilan resmi yang
bisa dipakai sebagai acuan visual.

Artinya pekerjaan ini punya dua hasil sekaligus: aplikasi yang lebih enak
dilihat, **dan** isi untuk §2.6 laporan. Kalau nanti ada anggota yang mengerjakan
bagian ini, tangkapan layar hasil D1–D4 adalah bahan siap pakai untuk bagian
tersebut.

## Batas keras

Perbaikan tampilan **tidak boleh** mengubah:

| Yang dijaga | Rujukan |
| :--- | :--- |
| Cakupan, termasuk tidak menghidupkan lagi fitur yang sudah dibuang | `docs/CONTEXT.md` §4, terutama §4.3 |
| Aturan bisnis: status Pending/Partial/Complete, aturan submit, format QR 3 field | `docs/CONTEXT.md` §6 |
| Perjalanan operator dan semua cabang "kalau tidak mulus" | `docs/CONTEXT.md` §7 |
| Kontrak repository dan state viewmodel | `stockisi/lib/data/`, `stockisi/lib/viewmodels/` |
| Syarat matkul: minimal 5 layar, CRUD, dua jenis data berhubungan | `docs/CONTEXT.md` §1 |

Yang **boleh** diubah: warna, jarak, ukuran, hierarki visual, susunan scaffold,
animasi, penamaan widget, dan penggabungan widget yang duplikat.

Kalau sebuah perubahan menuntut perubahan alur, itu bukan lagi pekerjaan UI —
bawa ke pemilik repo dulu.

## Kriteria "ramah di mata" yang bisa disepakati

Selera tidak bisa dinilai, jadi patokannya dibuat terukur:

1. **Hierarki tiga tingkat** yang terlihat jelas: aksi utama, konten, metadata.
   Mata harus tahu ke mana harus melihat lebih dulu tanpa membaca.
2. **Satu aksen warna per jenis dokumen.** Mint untuk Receiving, peach untuk
   Intransit. Tidak dipakai untuk hal lain di layar yang sama.
3. **Kontras teks minimal WCAG AA.** Sudah diuji di
   `stockisi/test/theme_contrast_test.dart`.
4. **Target sentuh minimal 48 dp**, tombol aksi utama sekitar 56 dp
   (`AppSize.minTouch`, `AppSize.primaryButton`).
5. **Maksimal dua kontrol filter** di atas daftar.
6. **Satu pola kartu utama dan satu varian redup.** Bukan semua kartu seragam
   dengan bobot yang sama.
7. **Status tidak pernah hanya disampaikan lewat warna.** Selalu ada ikon
   atau label.

## Temuan

Diurutkan dari yang paling berdampak.

### 1. Semua kartu berbobot sama

`stockisi/lib/widgets/document_card.dart:27` memakai `Card` dengan border 1 px
dan radius 12 untuk semua status. Dokumen OPEN yang butuh tindakan dan dokumen
SUBMITTED yang sudah selesai hanya dibedakan lewat warna latar.

Ini juga melanggar `docs/CONTEXT.md` §9 yang eksplisit menyebut "semua kartu
dengan bentuk serta bobot yang sama" sebagai hal yang dihindari.

**Arah perbaikan:** dokumen OPEN mendapat garis aksen kiri 3 dp (mint untuk RCV,
peach untuk INT) dan judul lebih besar. Dokumen SUBMITTED tanpa border, latar
`surfaceMuted`, teks redup.

### 2. Tidak ada header konteks

`stockisi/lib/screens/documents/document_list_screen.dart:75` memakai
`AppBar(title: Text('Dokumen'))`. Nama operator dan kode gudang baru muncul di
tab Profil, yaitu tab keempat.

Operator yang sedang berdiri di rak tidak punya cara cepat memastikan dia
melihat gudang yang benar. Untuk aplikasi gudang ini bukan soal estetika.

**Arah perbaikan:** header bersama berisi judul tab dan `WH01 · Budi Santoso`
dari `SessionController`, terlihat di keempat tab.

### 3. Sepuluh Scaffold bersarang

`stockisi/lib/screens/home_shell.dart:29` membuat satu `Scaffold`, lalu empat
tab di dalamnya masing-masing membuat `Scaffold` dan `AppBar` sendiri.

Akibatnya: tidak mungkin punya header bersama, `AppBar` memakan 56 dp di setiap
tab, tidak ada transisi antar tab, dan `SafeArea` bisa terpasang dua kali.

**Arah perbaikan:** `HomeShell` menjadi satu-satunya `Scaffold`. Empat tab
menjadi isi murni tanpa `Scaffold` dan tanpa `AppBar`.

### 4. Tiga lapis kontrol di atas daftar

`stockisi/lib/screens/documents/document_list_screen.dart:83-106` menumpuk
`SegmentedButton` (48 dp), jarak 12 dp, `TextField` (±56 dp), jarak 8 dp, lalu
baris `ChoiceChip` (48 dp). Total ±172 dp sebelum daftar dimulai.

Pada layar 390×844 dengan `AppBar` 56 dp dan `NavigationBar` 72 dp, sisa ruang
untuk daftar sekitar 324 dp, yaitu kira-kira dua kartu.

**Arah perbaikan:** `ChoiceChip` navy penuh diganti `FilterChip` ringan supaya
tidak bersaing dengan `SegmentedButton`, dan baris filter digabung dengan kolom
pencarian.

### 5. Tiga implementasi pill yang berbeda

- `_Tag` di `stockisi/lib/widgets/document_card.dart:119`
- `ItemStatusChip` di `stockisi/lib/widgets/item_status_chip.dart:10`
- `DocumentTypeBadge` di `stockisi/lib/widgets/document_type_badge.dart`

Padding, ikon, dan radiusnya sama, kodenya tiga kali. Perubahan kecil harus
dilakukan di tiga tempat.

**Arah perbaikan:** satu `AppPill` di `stockisi/lib/widgets/app_pill.dart`,
dipakai ketiganya.

### 6. Indikator bottom navigation nyaris tidak terlihat

`stockisi/lib/theme/app_theme.dart:117` memakai `indicatorColor: surfaceMuted`
(`#F1EEE7`) di atas `surface` putih (`#FFFFFF`). Kontrasnya sekitar 1,09:1.

**Arah perbaikan:** indikator memakai turunan navy yang lembut, atau
`NavigationBar` diganti pola tab dengan garis bawah.

### 7. Belum ada motion

Tidak ada transisi saat daftar berubah karena filter, saat membuka detail, atau
saat progress Partial berubah. Semua perubahan muncul seketika.

**Arah perbaikan:** `AnimatedSwitcher` pada daftar, `Hero` pada nomor dokumen,
`AnimatedContainer` pada progress bar.

## Rencana kerja

Dikerjakan berurutan. Setiap langkah harus lulus `flutter analyze` dan
`flutter test` sebelum lanjut.

### D1 — Token dan tema (±20 menit, risiko rendah)

Tidak menyentuh satu pun layar.

- `theme/app_colors.dart`: tambah navy lembut untuk indikator, mint dan peach
  versi solid untuk aksen
- `theme/app_dimens.dart`: tambah satu tingkat jarak dan satu tingkat radius
- `theme/app_theme.dart`: perbaiki `indicatorColor`, pertegas gaya label tab
  yang aktif, naikkan ketebalan border input saat fokus

### D2 — Satu Scaffold dan header bersama (±45 menit, 5 berkas)

- `screens/home_shell.dart`: satu-satunya `Scaffold`, header bersama, transisi
  antar tab
- `screens/documents/document_list_screen.dart`, `screens/stock/…`,
  `screens/history/…`, `screens/profile/profile_screen.dart`: hapus `Scaffold`
  dan `AppBar`, sisakan isi

### D3 — Hierarki kartu dan filter (±40 menit)

- `widgets/document_card.dart`: dua bobot kartu, garis aksen kiri
- `screens/documents/document_list_screen.dart`: dua kontrol filter saja
- `widgets/app_pill.dart` baru, lalu hapus `_Tag`, `ItemStatusChip`, dan
  `DocumentTypeBadge` sebagai kelas terpisah

### D4 — Motion (±20 menit)

- `AnimatedSwitcher` di daftar dokumen dan daftar kartu stok
- `Hero` pada nomor dokumen menuju detail
- `AnimatedContainer` pada progress Partial

## Selesai kalau

- `flutter analyze` bersih, `flutter test` lulus tanpa test yang dihapus.
- Ketujuh kriteria di atas terpenuhi dan bisa ditunjukkan di layar.
- `docs/CONTEXT.md` §4, §6, dan §7 tidak berubah satu baris pun.
- Tidak ada perubahan di `stockisi/lib/data/`, `stockisi/lib/viewmodels/`,
  `stockisi/lib/models/`, dan `stockisi/lib/services/`.
- Tangkapan layar keempat tab dilampirkan di `docs/PROGRESS.md`.

## Cara memakai dokumen ini

Kalau kamu anggota kelompok yang mengambil pekerjaan tampilan, baca
`docs/CONTEXT.md` §9 dulu. Bagian itu yang menetapkan arah desain; dokumen ini
hanya mencatat selisih antara arah itu dan kode yang ada sekarang.
