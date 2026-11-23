# Progress Stockisi

## Status tahap

| Tahap | Status | Commit |
| :--- | :--- | :--- |
| Persiapan: `.gitignore` dokumen kerja | Selesai, lalu diubah 2026-11-23 | `a0fb588` |
| Tahap 0: Membaca dan memetakan | Selesai, pertanyaan terjawab | tidak ada commit (tidak ada file ter-track yang berubah) |
| Tahap 1: Fondasi | Selesai, disetujui | `2bdd222` |
| Tahap 2: Masuk dan Profil | Selesai, disetujui | `c1f0833` |
| Tahap 3: Dokumen dan transaksi | Selesai, disetujui | `80cebee` |
| Perapian environment dan dokumen | Selesai (2026-11-23) | menyusul |
| Tahap 4: Kartu Stok dan Label QR | Selesai (2026-11-23), menunggu persetujuan | menyusul |
| Tahap 5: Riwayat | Selesai (2026-11-23), menunggu persetujuan | menyusul |
| Tahap 6: Pemeriksaan menyeluruh dan serah terima | Belum mulai | |

Catatan persiapan (diperbarui 2026-11-23): `.gitignore` root semula meng-ignore `CLAUDE.md`, `docs/CONTEXT.md`, `docs/PLAN.md`, `docs/PROGRESS.md`, dan `docs/referensi/`. Entri itu tidak pernah cocok dengan path sebenarnya, sehingga dokumen justru tidak terlindungi dan muncul sebagai untracked. Karena repo ini proyek kelompok, keputusan diubah: **semua dokumen di `docs/` sekarang di-track dan dibagi ke anggota**. `.gitignore` root hanya berisi artefak lokal. `stockish/.gitignore` tidak disentuh.

## Lingkungan

### Dicek 2026-11-21 (komputer tempat Tahap 0-3 dikerjakan)

- Flutter 3.47.9 stable, Dart 3.13.7, DevTools 2.60.0.
- Android toolchain OK (Android SDK 36.0.0). **Belum ada AVD** (`flutter emulators` kosong). Tidak ada HP fisik terhubung.
- Chrome 157 dan Edge 157 tersedia sebagai target web.
- Visual Studio tidak terpasang (hanya berpengaruh ke target Windows desktop, tidak dipakai).
- Kode lama: `environment.sdk ^3.12.2`, `mobile_scanner` dipin `5.2.3`. Kompatibilitas versi `mobile_scanner` dengan Flutter 3.47 dicek ulang di Tahap 1.
- Font Plus Jakarta Sans tidak ada di repo. Perlu diambil di Tahap 1 (lisensi OFL).

### Dicek 2026-11-23 (komputer ini, sebelum presentasi)

- Flutter **3.44.5** stable, Dart **3.12.2**, DevTools 2.57.0. Lebih rendah dari mesin Tahap 0-3.
- `stockisi/pubspec.yaml` semula `environment.sdk ^3.13.7` dan `intl ^0.20.3`, sehingga `flutter pub get` gagal di Dart 3.12.2.
- Semua dependency dicek ke pub.dev sebelum melonggarkan: `mobile_scanner 7.5.0` butuh `^3.7.0`, `flutter_secure_storage 11.2.0` butuh `>=3.8.0`, `intl 0.20.3` butuh `^3.9.0`, `provider 6.1.5+1` butuh `>=2.12.0`, `flutter_lints 6.0.0` butuh `^3.8.0`, `barcode 2.2.9` butuh `>=2.12.0`. **Tidak ada yang butuh di atas 3.12.2.**
- Batas dilonggarkan: `sdk ^3.12.2` dan `intl ^0.20.2`. Keduanya tetap menerima 3.13.7 / 0.20.3, jadi mesin Tahap 0-3 tidak rusak. `flutter upgrade` tidak diperlukan.
- `pubspec.lock`: `intl` turun ke 0.20.2 karena dipin `flutter_localizations` di Flutter 3.44.5.
- Target demo: Chrome 158, Edge 158, Windows desktop, dan **1 emulator Android** (`Medium_Tablet`). Catatan "belum ada AVD" di atas sudah tidak berlaku di mesin ini.
- `python 3.14.6` tersedia untuk mengekstrak teks PDF laporan bila diperlukan.
- `opencode` tidak ada di PATH. CLI-nya di `%LOCALAPPDATA%\Programs\ai.opencode.desktop\resources\opencode-cli.exe` (v2.3.2).

## Pemetaan file `stockish/lib/` (66 file)

Legenda: **A** = diadaptasi, **R** = referensi perilaku saja, **X** = tidak dibawa.

### constants/

| File | Nasib | Catatan |
| :--- | :--- | :--- |
| `app_colors.dart` | A | Navy `#1B2A5E` masuk ke sumber tema tunggal. |
| `api_constants.dart` | X | URL backend lama. |

### models/

| File | Nasib | Catatan |
| :--- | :--- | :--- |
| `reference_document.dart` | A | Ambil `TransactionType {receiving, intransit}`, nomor referensi, tipe, gudang, tanggal, nomor surat jalan vendor, nama vendor. Buang field kunci (`lockedByNik`, `lockedByName`) dan `fromJson`. Status diganti jadi OPEN/SUBMITTED. Field `receivedQuantitySoFar` tidak pernah diisi di kode lama (field mati), jadi diganti mekanisme sisa yang dihitung repository. |
| `transaction_item.dart` | A | Ambil kode, nama, kuantitas dokumen, satuan, rak, kuantitas input, stok tersedia (untuk INT), getter `status`, `outstandingQuantity`. Buang `extensionFields`, `processedByNik/Name`, `isProcessed`. Aturan status berubah, lihat bagian perilaku nomor 5. |
| `stock_item.dart` | A | Ambil kode, nama, satuan, saldo, kode gudang, rak. Buang `extensionFields` dan `hasQrCode` (khusus Print QR). |
| `stock_movement.dart` | A | Ambil tanggal, tipe, kuantitas, nomor referensi, saldo setelah. Tambah NIK operator pemroses (laporan 2.2.4 mewajibkan, kode lama tidak punya). |
| `user.dart` | A | Ambil NIK, nama, kode gudang, nama gudang. Tambah status aktif. Buang `roles`, tiga flag akses, `token`, `fromLoginResponse`. |
| `activity_log.dart` | X | Activity log (4.3). Riwayat baru memakai model transaksi. Bentuk header plus daftar item di sini mirip transaksi, boleh dilirik saat menyusun model transaksi. |
| `erp_push_status.dart` | X | Sinkronisasi ERP (4.3). |
| `item_extension_field.dart` | X | Lampiran/info tambahan kartu stok (4.3). |
| `performance_entry.dart` | X | Layar Performa (4.3). |
| `print_job.dart` | X | Print via jaringan (4.3). |

### repositories/

| File | Nasib | Catatan |
| :--- | :--- | :--- |
| `auth_repository.dart` | R | Pesan gagal default `NIK atau Password tidak valid.`. Logout best-effort. Hook audit dan log debug tidak dibawa. |
| `reference_document_repository.dart` | R | Seluruhnya REST dan kunci dokumen. Yang diambil hanya pola cache daftar dan `getDocument(ref)`. |
| `transaction_item_repository.dart` | R | Pola penting: draf lokal di-merge ke item dokumen saat dimuat; item dengan kuantitas dokumen `<= 0` otomatis dianggap selesai. Submit membawa `asPartial`. |
| `stock_card_repository.dart` | R | Filter per gudang dilakukan di repository (dekat sumber data), bukan di layar. Mutasi diurutkan terbaru dulu. |
| `activity_log_repository.dart` | X | 4.3. |
| `audit_log_repository.dart` | X | 4.3. |
| `erp_push_repository.dart` | X | 4.3. |
| `print_job_repository.dart` | X | 4.3. |
| `app_settings_repository.dart` | X | Setting timer kunci, polling, idle timeout dari server (4.3). |

### viewmodels/

| File | Nasib | Catatan |
| :--- | :--- | :--- |
| `transaction_detail_viewmodel.dart` | A | Ambil hitungan pending/partial/complete dan pola `saveItem` yang mengembalikan `String?` (null = sukses, selain itu pesan error spesifik). Semantik input diubah: scan/manual menambah, edit kartu mengganti. Penyimpanan SQLite diganti repository draf. |
| `transaction_summary_viewmodel.dart` | A (sebagian) | Ambil `submit(asPartial:)` dan alur sukses/gagal. Buang idempotency key, retry window, activity log, audit log, timer kunci. |
| `reference_document_list_viewmodel.dart` | A | Ambil pencarian, filter tipe, filter status, state memuat/gagal, hitungan item belum selesai, dan guard `_disposed` + `_safeNotify()`. Buang `Poller` dan status Locked. |
| `stock_card_viewmodel.dart` | A | Ambil filter pencarian (kode atau nama, case-insensitive, `contains`) dan `errorMessage`. |
| `transaction_history_viewmodel.dart` | R | Sumbernya activity log dan punya filter "Punya Saya/Semua Operator" yang bukan cakupan. Riwayat baru hanya transaksi SUBMITTED di gudang operator. |
| `profile_viewmodel.dart` | R | Urutan logout (bersihkan sesi lalu ke login). |
| `performa_viewmodel.dart` | X | 4.3. |
| `print_qr_viewmodel.dart` | X | 4.3. Satu fakta diambil: isi QR lama, lihat perilaku nomor 1. |
| `push_monitoring_viewmodel.dart` | X | 4.3. |

### screens/

| File | Nasib | Catatan |
| :--- | :--- | :--- |
| `qr_scanner_screen.dart` | A | Layar scanner generik yang mengembalikan string mentah lewat `Navigator.pop`. Ambil guard `_hasScanned` (sekali pop), tombol senter, `BoxFit.contain` di `Positioned.fill`. Tambah penanganan izin ditolak / kamera tidak tersedia (4.2). |
| `splash_screen.dart` | R | Kode lama selalu ke Login dan menghapus sesi lama. Stockisi justru memulihkan sesi (CONTEXT 6). |
| `login_screen.dart` | R | Validasi form, tombol loading. |
| `reference_document_list_screen.dart` | R | Chip tipe dan filter status, kartu dokumen dengan "x item belum selesai", dokumen selesai diredupkan. Semua yang terkait Locked dibuang. |
| `transaction_detail_screen.dart` | R | Lihat perilaku nomor 1, 4, 5, 6, 7. Timer kunci, reclaim, extension field, badge "oleh operator" dibuang. |
| `transaction_summary_screen.dart` | R | Lihat perilaku nomor 3. |
| `stock_card_search_screen.dart` | R | Pesan kosong `Item tidak ditemukan.`. |
| `stock_card_detail_screen.dart` | R | Saldo, rak, riwayat mutasi dengan tanda `+`/`-` dan saldo per baris. Tombol lampiran dibuang. Belum ada Label QR di kode lama. |
| `transaction_history_screen.dart` | R | Pola state gagal + tarik untuk coba lagi, state kosong. Filter kepemilikan dibuang. |
| `profile_screen.dart` | R | Dialog logout. Export log diagnostik dan riwayat aktivitas dibuang. |
| `dashboard_screen.dart` | X | Menu kotak diganti bottom navigation empat tab (CONTEXT 3 dan 4.1). |
| `performa_screen.dart` | X | 4.3. |
| `print_qr_screen.dart` | X | 4.3. |
| `push_monitoring_screen.dart` | X | 4.3. |
| `stock_card_3d_screen.dart` | X | 4.3. |
| `stock_card_engineering_drawings_screen.dart` | X | 4.3. |
| `stock_card_goods_screen.dart` | X | 4.3. |
| `stock_card_technical_info_screen.dart` | X | 4.3. |

### services/

| File | Nasib | Catatan |
| :--- | :--- | :--- |
| `session/session_storage_service.dart` | A | Pembungkus `flutter_secure_storage` (`encryptedSharedPreferences: true`). Di kode lama hanya tersisa `clearUser()`; Stockisi menambah simpan dan baca sesi. |
| `database/database_service.dart` | R | Skema `transaction_progress` (per dokumen per item: kuantitas, status) jadi acuan bentuk draf. Tabel `auth_debug_log` dan `audit_log_queue` tidak dibawa. `sqflite` tidak dibawa di tahap UI. |
| `session/session_service.dart` | X | Polling sesi, sesi tunggal, idle timeout (4.3). |
| `api/api_service.dart` | X | HTTP client backend lama. |
| `connectivity_service.dart` | X | Banner koneksi global (4.3). |
| `lock_timer_service.dart` | X | Timer kunci 15 menit (4.3). |
| `lock_validation_service.dart` | X | Validasi kunci (4.3). |
| `poller.dart` | X | Auto-refresh berkala, tidak ada di cakupan. |
| `post_login_navigator.dart` | X | Reclaim kunci setelah login (4.3). |
| `app_settings_cache.dart` | X | Setting kunci/polling dari server (4.3). |

### utils/, widgets/, main

| File | Nasib | Catatan |
| :--- | :--- | :--- |
| `main.dart` | R | Pola `MultiProvider` di root. Judul "StockFlow" diganti Stockisi. |
| `utils/device_identifier.dart` | X | Untuk audit log (4.3). |
| `utils/route_observer.dart` | X | Hanya dipakai untuk refresh setelah kembali dari layar lain. Dibuat ulang kalau ternyata perlu. |
| `widgets/refreshable_list_section.dart` | R | Pola tarik-untuk-segarkan. Indikator sinkronisasi tidak dibawa. |
| `widgets/user_info_banner.dart` | R | Kartu nama + NIK + gudang di Profil. |
| `widgets/sync_status_indicator.dart` | X | Indikator sinkronisasi, tidak ada di cakupan. |
| `widgets/activity_log_detail_dialog.dart` | X | 4.3. |
| `widgets/stock_card_attachment_placeholder.dart` | X | Lampiran kartu stok (4.3). |

## Perilaku kode lama yang dipetakan

1. **Format isi QR.**
   - Kode lama: QR berisi `itemCode` saja, tanpa pemisah (`print_qr_viewmodel.dart`, `BarcodeWidget(data: item.itemCode)`).
   - Pencocokan scan: string mentah dibandingkan `toLowerCase()` dengan `itemCode` item yang sedang dibuka (`transaction_detail_screen.dart` `handleScanTap`). Tidak di-`trim`.
   - Alur lama: operator membuka kartu item dulu, lalu scan sebagai verifikasi item itu. Stockisi: tombol Scan di bawah Detail Transaksi, hasil scan yang menentukan item.
   - Laporan 2.2.5: isi QR = kode barang, satuan, kode gudang (berurutan). Pemisahnya **tidak ada di kode lama maupun laporan**. Ditanyakan (pertanyaan 3).
2. **Sisa kuantitas.**
   - Kode lama tidak menghitung sisa di klien. `receivedQuantitySoFar` dideklarasikan tapi tidak pernah diisi atau dibaca. Server mengirim `referenceQuantity` yang sudah berupa sisa.
   - Item dengan `referenceQuantity <= 0` dianggap tidak ada pekerjaan: otomatis `actualQuantity = 0`, `isProcessed = true`.
   - `outstandingQuantity = max(0, referenceQuantity - actualQuantity)`.
   - Stockisi: repository tiruan menghitung `sisa = kuantitas dokumen - total yang sudah disubmit sebelumnya`. Item dengan sisa 0 tampil sebagai sudah terpenuhi dan tidak ikut dihitung Pending.
3. **Dialog Partial (Ringkasan).**
   - Muncul kalau ada item Partial saat Submit ditekan.
   - RCV: judul `Ada Item Partial`, isi menyebut jumlah item Partial, tombol `Batal` / `Simpan sebagai Partial` (outlined) / `Tandai Selesai` (utama).
   - INT di kode lama: hanya `Batal` / `Lanjutkan` (selalu jadi selesai). **Stockisi menyamakan INT dengan RCV** karena CONTEXT 6 dan laporan 2.2.3 berlaku untuk keduanya.
   - Guard `_isSubmitting` mencegah submit ganda. Dialog sukses `barrierDismissible: false`, tombol OK menutup Ringkasan dan Detail sekaligus kembali ke daftar.
   - Teks dialog lama menyebut ERP dan StockFlow, diganti.
4. **Penahan tombol kembali.**
   - Kode lama: `PopScope(canPop: true)` di Detail dan Ringkasan. **Tidak menahan apa pun**, hanya membersihkan kunci saat sudah pop. Progres tetap tersimpan di SQLite.
   - Konfirmasi pembuangan progres hanya ada di tombol `Batalkan Proses` (judul `Batalkan Proses?`, tombol `Tidak` / `Ya, Batalkan` merah).
   - Stockisi: `PopScope(canPop: false)` selama ada input, dengan dialog tiga pilihan simpan draf / buang / batal (CONTEXT 4.2, laporan 2.4). Yang dibawa dari kode lama: gaya konfirmasi aksi destruktif dan pembersihan state saat keluar.
5. **Status item.**
   - Kode lama: Pending = `isProcessed == false`. Complete = `actualQuantity == referenceQuantity`. Selain itu Partial, termasuk kuantitas 0 yang disimpan lewat tombol "Not Received".
   - Stockisi (CONTEXT 6): Pending = input 0, Partial = 0 < input < sisa, Complete = input == sisa. Tidak ada flag terpisah. Akibatnya barang yang sama sekali tidak datang tetap Pending dan memblok submit. Ditanyakan (pertanyaan 4).
6. **Validasi kuantitas.**
   - `saveItem` lama mengganti nilai, menolak `< 0` atau `> referenceQuantity` dengan pesan `Quantity tidak boleh melebihi {n} {uom}.`. Nilai 0 diterima.
   - INT: menolak `> availableStock` dengan pesan `Quantity tidak boleh melebihi stock tersedia ({n} {uom}).`. Validasi berjalan kalau `availableStock` tidak null (data-driven, bukan cek tipe dokumen).
   - Stockisi: wajib > 0, total input dibandingkan dengan sisa dan (INT) saldo stok, pesan menyebut batasnya.
7. **Input manual.**
   - Kode di-`trim`, dibandingkan case-insensitive.
   - Pesan: kosong `Kode barang wajib diisi.`; tidak cocok `Kode tidak sesuai dengan item ini ({kode}).`.
   - QR tidak cocok membuka dialog `QR Rusak/Tidak Terbaca` dengan pilihan `Coba lagi` / `Input Manual`. Pola "gagal scan menawarkan input manual" dipertahankan.
8. **Syarat sebelum Ringkasan.**
   - Kode lama memeriksa di Detail: masih ada Pending ditolak lewat SnackBar `Tidak bisa lanjut: masih ada item berstatus Pending.`; RCV tanpa nomor surat jalan ditolak.
   - Kolom nomor surat jalan lama ada di Detail. Laporan Tabel 2.1 menaruhnya di Ringkasan, Stockisi mengikuti laporan.
9. **Login dan sesi.**
   - Kode lama tidak punya pesan akun nonaktif di klien (memakai pesan server). Stockisi menambahkannya.
   - Remember Login di kode lama dimatikan (Splash selalu ke Login). Stockisi memulihkan sesi dari penyimpanan perangkat (CONTEXT 6).
10. **Daftar dokumen.** Filter status default menyembunyikan dokumen selesai. Kartu menampilkan "{n} item belum selesai". Dokumen selesai diredupkan (opacity 0.6).
11. **Kartu stok.** Pencarian kode atau nama, case-insensitive. Mutasi terbaru di atas. Baris mutasi: `+n` hijau untuk Receiving, `-n` oranye untuk Intransit, plus saldo setelah. Kosong: `Belum ada riwayat pergerakan.`.
12. **Logout.** Dialog `Logout` / `Yakin mau logout dari akun ini?` / `Tidak` / `Ya, Logout`, lalu `pushAndRemoveUntil` ke Login. Stockisi menambah peringatan draf (CONTEXT 7).

## Tahap 1: Fondasi (2026-11-21)

### Struktur `stockisi/lib/`

- `main.dart`: titik komposisi. Satu-satunya tempat memilih implementasi repository (sekarang tiruan).
- `app.dart`: `MaterialApp`, `MultiProvider` berisi lima repository, locale `id`.
- `models/`: `OperatorProfile`, `DocumentType`/`DocumentStatus`, `ReferenceDocument`/`ReferenceDocumentItem`, `Draft`/`DraftLine`, `TransactionRecord`/`TransactionLine`, `StockItem`, `StockMovement`.
- `data/transaction_rules.dart`: aturan CONTEXT 6 sebagai fungsi murni (`itemStatusOf`, `checkQuantity`, `checkSubmit`, `partialCountOf`). Dipakai layar dan repository.
- `data/repository_exceptions.dart`: exception bertipe dengan pesan Bahasa Indonesia (`DataUnavailableException`, `NotSignedInException`, `NotFoundException`, `AuthException`, `SubmitException`).
- `data/repositories/`: lima kontrak (`AuthRepository`, `ReferenceDocumentRepository`, `DraftRepository`, `TransactionRepository`, `StockCardRepository`) + bundel `Repositories`.
- `data/mock/`: `mock_backend.dart` (state di memori + `applySubmit`), `mock_repositories.dart` (lima implementasi), `mock_seed.dart` (data dummy).
- `theme/`: `app_colors.dart`, `app_dimens.dart`, `app_text_styles.dart`, `app_theme.dart`.
- `widgets/`: `DocumentTypeBadge`, `ItemStatusChip`, `PrimaryActionButton`, `LoadingView`/`EmptyView`/`ErrorView`, `StockisiWordmark`, `PlaceholderScreen`.
- `screens/`: `app_routes.dart`, `splash_screen.dart`, `login_screen.dart` (placeholder + tombol akun contoh SEMENTARA), `home_shell.dart` (NavigationBar 4 tab, IndexedStack), placeholder di `documents/`, `stock/`, `history/`, `profile/`.

### Package

- `provider` ^6.1.5+1: state management (CLAUDE.md).
- `intl` ^0.20.3: format tanggal dan angka mulai Tahap 2-5.
- `flutter_localizations` (SDK): teks bawaan Material (tooltip "Kembali", menu salin-tempel) berbahasa Indonesia.
- Belum dipasang, menyusul saat dipakai: `flutter_secure_storage` (Tahap 2), `mobile_scanner` (Tahap 3), `barcode` (Tahap 4).
- Font Plus Jakarta Sans statis 400/500/600/700/800 dari repo resmi `tokotype/PlusJakartaSans`, lisensi OFL disertakan di `assets/fonts/OFL.txt`.

### Data dummy (`mock_seed.dart`)

- Kata sandi semua akun: `stockisi123`.
- Akun: `210457` Budi Santoso (WH01, aktif, akun utama); `210512` Rina Wulandari (WH01, aktif, "operator lain"); `198803` Agus Prasetyo (WH01, nonaktif); `220118` Siti Rahmawati (WH02, aktif).
- Gudang: `WH01` Gudang Bahan Baku Sidoarjo, `WH02` Gudang Barang Jadi Pasuruan.
- Barang: 15 di WH01 (`BRG-0001`..`BRG-0015`), 4 di WH02 (`BRG-0101`..`BRG-0104`). `BRG-0014` tanpa mutasi (saldo 0).
- Riwayat dibangun dengan memutar 9 submit historis lewat `applySubmit`, jadi saldo = jumlah mutasi (dicek di test).
- Dokumen untuk cabang alur (konstanta `MockDoc`):
  - `PO-2611-0041` RCV OPEN baru; `PO-2611-0048` RCV OPEN baru kecil.
  - `PO-2611-0043` RCV OPEN Partial 3 dari 5; Budi punya draf lama (versi 0, dokumen versi 1) untuk menguji "draf, dokumen sudah berubah".
  - `PO-2611-0046` RCV OPEN; submit pertama didahului Rina menyelesaikan dokumen (simulasi "sudah diproses operator lain").
  - `BON-2611-0012` INT OPEN Partial 2 dari 4.
  - `BON-2611-0014` INT OPEN; Budi punya draf valid.
  - `BON-2611-0016` INT OPEN; gas argon diminta 10 TBG, saldo 4 TBG (batas stok).
  - `PO-2611-0052`, `BON-2611-0021` milik WH02 (pembatasan gudang).
  - SUBMITTED: `PO-2610-0031`, `PO-2610-0034`, `PO-2610-0038` (Tandai Selesai dengan kekurangan), `BON-2610-0019`, `BON-2611-0006`, plus dua di WH02.
- Simulasi gagal: `--dart-define=STOCKISI_MOCK_FAIL=documents,stockCard,history,submit,drafts,login` membuat area itu gagal sekali, lalu berhasil saat Coba lagi.
- Jeda buatan 500 ms (login dan submit 750 ms).

### Verifikasi Tahap 1

- `flutter analyze`: No issues found.
- `flutter test`: 50 test lulus (aturan, konsistensi seed, repository tiruan, kontras warna, navigasi tab dan routing).
- `flutter build web --no-web-resources-cdn`: berhasil. Peringatan build: "Expected to find fonts for CupertinoIcons" (app tidak memakai CupertinoIcons; tidak berdampak).
- App web dijalankan di Chrome headless (viewport 390x844, emulasi mobile) dan ditelusuri otomatis lewat DevTools Protocol: Login placeholder → 4 tab → Detail Transaksi → Scan → Ringkasan → Detail Kartu Stok → Label QR → Detail Riwayat, tombol Kembali. Tidak ada error di console. Tangkapan layar dicek visual.
- `flutter build apk --debug`: berhasil. Belum dijalankan di perangkat Android.
- Belum diverifikasi manual dengan ekstensi Mobile Simulator di komputer pemilik repo.
- Insiden: `stockish/pubspec.lock` sempat berubah (20:13, bersamaan dengan pembuatan `stockisi/`), kemungkinan `pub get` otomatis dari ekstensi Dart VS Code. Dikembalikan dengan `git checkout`. Cache ter-ignore `stockish/.dart_tool/`, `.flutter-plugins-dependencies`, `android/.gradle/` dibiarkan.

## Tahap 2: Masuk dan Profil (2026-11-21)

### Yang dibangun

- `lib/services/session_store.dart`: `SessionStore` (NIK saja), `SecureSessionStore` (`flutter_secure_storage`), `InMemorySessionStore` (test). Diadaptasi dari `stockish/lib/services/session/session_storage_service.dart`.
- `MockAuthRepository` kini menyimpan NIK ke `SessionStore` saat login, membaca saat `restoreSession` (akun hilang/nonaktif → sesi dihapus, null), menghapus saat logout.
- `lib/services/session_controller.dart`: `ChangeNotifier` berisi operator aktif (restore/login/logout), disediakan di `app.dart`.
- `splash_screen.dart`: `restore()` + tampil minimum 700 ms, lalu ke `/beranda` atau `/login`.
- `login_screen.dart`: form NIK (angka saja) + kata sandi (tombol tampil/sembunyi), validasi kolom kosong, banner error di form (`InlineErrorBanner`), tombol Masuk 56 dp di bawah. Tombol akun contoh dari Tahap 1 dihapus.
- `profile/profile_screen.dart`: avatar inisial, nama, NIK, gudang + kode, tombol Logout di bawah. Logout memeriksa draf dulu, lalu satu dialog konfirmasi yang isinya menyesuaikan.
- `screens/session_guard.dart`: `SessionGuard` (route terlindung tanpa sesi → Login, tumpukan dikosongkan) dan `RestartFromSplash` (route tak dikenal / tanpa argumen → Splash).
- `app.dart`: `onGenerateInitialRoutes` selalu mulai dari Splash, apa pun URL web-nya.

### Perilaku cabang

| Kondisi | Hasil |
| :--- | :--- |
| Kolom kosong | "NIK wajib diisi." / "Kata sandi wajib diisi." di bawah kolom |
| NIK tak terdaftar atau sandi salah | Banner "NIK atau kata sandi salah.", NIK tetap, sandi dikosongkan dan difokus |
| Akun nonaktif | Banner "Akun Anda nonaktif. Hubungi admin gudang.", NIK tetap |
| Gagal koneksi | Banner pesan koneksi, NIK dan sandi tetap, Masuk bisa ditekan lagi |
| Banner | Hilang begitu operator mengetik lagi |
| App dibuka ulang dengan sesi | Splash → tab Dokumen |
| Sesi tersimpan milik akun yang kini nonaktif | Sesi dihapus, ke Login |
| Logout, ada draf | Dialog "Ada draf yang belum disubmit" + daftar nomor dokumen; "Batal" / "Tetap logout" |
| Logout, tanpa draf | Dialog "Logout dari Stockisi?"; "Batal" / "Logout" |
| Logout, draf gagal diperiksa | Dialog dengan keterangan draf tidak bisa diperiksa; tetap bisa logout |
| Setelah logout | Login, tidak bisa kembali, sesi terhapus |
| URL web `#/beranda` tanpa sesi | Login |
| URL web route tanpa argumen (`#/dokumen/detail`) | Ulang dari Splash, tidak crash |

### Package

- `flutter_secure_storage` ^11.2.0 (kode lama memakai 9.x): menyimpan sesi di perangkat (CONTEXT 6 dan 10). Opsi bawaan; tidak memakai `encryptedSharedPreferences` seperti kode lama.

### Verifikasi Tahap 2

- `flutter analyze`: No issues found.
- `flutter test`: 69 test lulus (16 test baru di `test/auth_flow_test.dart`).
- Chrome headless (390x844, emulasi mobile), build web dengan `flutter_secure_storage` asli, 38 langkah: kolom kosong, sandi salah, akun nonaktif, login berhasil, reload di `/beranda` langsung ke halaman utama tanpa tombol kembali, Profil Budi, dialog draf → Batal → Tetap logout, buka `#/beranda` tanpa sesi → Login, login Siti, buka `#/dokumen/detail` → halaman utama, Profil Siti, dialog logout tanpa draf. Console bersih. Tangkapan layar dicek visual.
- Bug yang ditemukan lewat tangkapan layar dan sudah diperbaiki: (1) pesan "Kata sandi wajib diisi." muncul bersamaan dengan banner penolakan dan fokus gagal; (2) reload web di `/beranda` membangun tumpukan Splash + Beranda sehingga tab punya panah kembali dan pemulihan sesi tidak benar-benar lewat Splash; (3) URL web bisa membuka halaman utama tanpa sesi; (4) spinner Logout terus berputar selama dialog terbuka.
- `flutter build apk --debug`: berhasil. Gradle otomatis memasang Android SDK Platform 35 di komputer ini. Belum dijalankan di perangkat Android.
- Belum diverifikasi manual dengan ekstensi Mobile Simulator.
- Batas data tiruan: hanya sesi yang tersimpan di perangkat. Draf, stok, dan riwayat kembali ke data awal setiap app dimuat ulang.

## Tahap 3: Dokumen dan transaksi (mulai 2026-11-21)

Tambahan dari pemilik repo: tanda "Tidak tersedia" (CONTEXT 6) masuk "Selesai kalau": satu RCV dengan satu barang tidak datang bisa disubmit lewat tanda itu, tanda bisa dibatalkan, item kembali Pending. PROGRESS diperbarui per bagian.

Package: `mobile_scanner` ^7.5.0 (kode lama 5.2.3). Di web, paket ini memuat ZXing dari CDN (`unpkg.com/@zxing/library@0.23.0` atau `cdn.jsdelivr.net/npm/zxing-wasm@3.1.6`) saat dijalankan, jadi scan di browser butuh internet. Error kamera: `MobileScannerException.errorCode` = `permissionDenied` / `unsupported` / `genericError`.

### Bagian 1: Daftar Dokumen — selesai

- File: `viewmodels/document_list_view_model.dart`, `screens/documents/document_list_screen.dart`, `widgets/document_card.dart`, `services/formatters.dart` (`Fmt.date`, `Fmt.dateTime`, `Fmt.qty`), `services/qr_payload.dart` (dipakai bagian 2).
- Diadaptasi dari `stockish/lib/viewmodels/reference_document_list_viewmodel.dart`: pencarian lokal, filter status default menyembunyikan dokumen selesai, guard `_disposed`. Status Locked dan polling dibuang.
- Yang jalan:
  - Segmen RCV/INT (`SegmentedButton`, warna mint/peach sesuai jenis terpilih, ikon panah masuk/keluar).
  - Pencarian nomor dokumen atau vendor/tujuan, tombol hapus pencarian.
  - Filter status: Terbuka (default) / Selesai / Semua.
  - Urutan: OPEN dulu, lalu tanggal terbaru.
  - Kartu: nomor, vendor/tujuan, tanggal, jumlah item, progres "Partial: x dari y item terpenuhi" + bar, penanda "Ada draf", dokumen SUBMITTED redup berlabel "Selesai".
  - Ketuk SUBMITTED → SnackBar "{nomor} sudah selesai dan tidak bisa diproses lagi."
  - Ketuk OPEN → Detail Transaksi; saat kembali daftar dimuat ulang diam-diam (progres, status, draf ikut berubah).
  - State: memuat, gagal + Coba lagi, kosong per jenis, tidak ada yang cocok + "Tampilkan semua dokumen", tarik untuk segarkan.
- Keputusan:
  - Gagal memuat penanda draf tidak menggagalkan daftar (penanda lama dipakai).
  - Gagal saat penyegaran diam-diam tidak mengganti daftar yang sudah tampil.
  - Format tanggal ditulis manual (`21 Nov 2026`) supaya tidak perlu `initializeDateFormatting`.
  - `MockBackend.failNext(area)` ditambahkan untuk test yang butuh kegagalan di tengah alur.
- Test: `test/document_list_test.dart` (7 test), `test/helpers.dart` (`pumpSignedIn`, layar 390x844). Total 76 test lulus.
- Belum: pengecekan visual di Chrome (dilakukan di akhir tahap bersama bagian lain).

### Bagian 2: Detail Transaksi dan scan — selesai

- File: `viewmodels/transaction_view_model.dart` (dipakai Detail dan Ringkasan), `screens/documents/transaction_detail_screen.dart`, `screens/documents/transaction_sheets.dart` (sheet tambah jumlah, input manual, aksi item), `screens/documents/scanner_screen.dart`, `services/scan_launcher.dart`, `widgets/transaction_item_card.dart`.
- Diadaptasi:
  - `stockish/lib/viewmodels/transaction_detail_viewmodel.dart`: hitungan status, validasi yang mengembalikan pesan (`String?`).
  - `stockish/lib/screens/qr_scanner_screen.dart`: guard sekali pop, senter, `BoxFit.contain`, overlay kotak.
  - `stockish/lib/screens/transaction_detail_screen.dart`: pola "scan gagal → Input manual / coba lagi", pencocokan kode trim + tidak peka huruf.
- Yang jalan:
  - Memuat dokumen + draf. Draf dengan `basedOnVersion` berbeda → dialog "Dokumen sudah berubah", draf dibuang, kembali ke daftar. Dokumen ternyata SUBMITTED → dialog "Dokumen sudah selesai", kembali. Dokumen gudang lain → state "tidak ditemukan". Gagal koneksi → Coba lagi. Draf valid → SnackBar "Melanjutkan draf …".
  - Header progres menempel di atas: "x dari y item diperiksa" (y = item bersisa > 0), bar, hitungan Pending/Partial/Complete/Sudah terpenuhi.
  - Kartu item: nama, kode, rak, status (chip ikon + label), Target (sisa) dan Diinput dalam angka 32 sp, "Tidak tersedia" kalau ditandai, info "Dokumen n, sudah diproses m" untuk dokumen Partial, "Stok n" untuk INT. Item sudah terpenuhi tampil redup di bawah, tidak bisa diketuk.
  - Bawah layar: tombol Scan QR 56 dp, lalu Input manual dan Ringkasan.
  - Scan → `ScanOutcome`: kode → dicocokkan; ditolak → dialog "Scan ditolak" (Input manual / Scan lagi); cocok → sheet tambah jumlah (terisi saran sisa). Izin ditolak / kamera tidak ada → langsung sheet input manual dengan banner alasan. Tombol "Input manual" di scanner → sheet input manual.
  - Penolakan scan: format bukan `kode|satuan|gudang`; gudang lain; satuan berbeda; barang tidak ada di dokumen; barang sudah terpenuhi. Kuantitas: ≤ 0; melebihi sisa ("Maksimal n UOM"); INT melebihi stok ("Maksimal n UOM").
  - Input manual: kode + jumlah, nama barang dan target muncul saat kode cocok.
  - Kartu item → sheet: ubah jumlah (mengganti), Hapus input (→ Pending), Tandai tidak tersedia (hanya item Pending), Batalkan tanda (→ Pending). Scan/manual pada item bertanda mulai dari 0 dan melepas tanda.
  - Tombol kembali (`PopScope`) hanya bertanya kalau ada perubahan sejak draf terakhir: "Keluar dari dokumen?" → Batal / Buang draf / Simpan draf. Simpan dengan input kosong menghapus draf lama.
- Keputusan:
  - Satuan di QR yang berbeda dari satuan dokumen ditolak (dianggap label salah).
  - Tanda "Tidak tersedia" hanya ditawarkan untuk item tanpa input, supaya tidak menimpa jumlah yang sudah diketik tanpa disadari.
  - Ringkasan bisa dibuka kapan saja; syarat submit diperiksa di Ringkasan (CONTEXT 7 menaruh "Masih ada Pending" di babak Ringkasan).
  - `ScanLauncher` disediakan lewat provider (`StockisiApp.scanLauncher`) supaya alur scan teruji tanpa kamera.
  - Route Ringkasan menerima `TransactionViewModel` sebagai argumen; tanpa argumen itu (URL web) diulang dari Splash.
  - `load()` tidak memberi notifikasi "memuat" saat state sudah memuat (menghindari notifikasi di tengah build).
- Test: `test/transaction_view_model_test.dart` (23), `test/transaction_detail_test.dart` (12). Total 111 test lulus.
- Belum: scan kamera sungguhan (decode QR) belum diuji; direncanakan memakai QR dari Label QR di Tahap 4 sesuai PLAN. Pengecekan visual di Chrome di akhir tahap.

### Bagian 3: Ringkasan dan submit — selesai

- File: `screens/documents/transaction_summary_screen.dart`.
- Diadaptasi dari `stockish/lib/screens/transaction_summary_screen.dart` dan `transaction_summary_viewmodel.dart`: dialog Partial tiga pilihan, guard submit ganda, dialog berhasil yang tidak bisa ditutup sembarangan lalu kembali ke daftar. Idempotency key, retry window, timer kunci, activity/audit log dibuang.
- Yang jalan:
  - Header dokumen berwarna jenis (mint/peach), hitungan Complete/Partial/Pending, kolom "Nomor surat jalan vendor" (hanya RCV), rekap item (nama, kode, rak, status, "jumlah / target" atau "Tidak tersedia"), catatan item yang sudah terpenuhi sebelumnya. Tombol Submit 56 dp di bawah.
  - Ada Pending → banner peringatan sejak layar dibuka; Submit → banner "Masih ada n item Pending…", tidak ada dialog.
  - RCV tanpa surat jalan → pesan di kolom dan kolom difokus.
  - Konfirmasi Submit (layar 7): tanpa Partial → "Submit transaksi?" (Batal / Submit). Ada Partial → "Ada n item Partial" dengan penjelasan kedua pilihan (Batal / Simpan sebagai Partial / Tandai Selesai), berlaku untuk RCV dan INT.
  - Berhasil → dialog "Transaksi berhasil disubmit" + nomor transaksi + status dokumen ("selesai" / "tetap terbuka untuk sisa barang") → "Kembali ke daftar dokumen" (`popUntil` halaman utama; daftar dimuat ulang).
  - Dokumen sudah diproses operator lain (`documentAlreadySubmitted` / `documentChanged`) → dialog "Dokumen sudah diproses operator lain" + pesan (draf dibuang oleh repository) → kembali ke daftar.
  - Gagal koneksi → banner "Submit gagal… Input Anda tetap ada…"; Submit bisa ditekan lagi.
  - Tombol kembali dinonaktifkan selama submit berjalan.
- Keputusan:
  - Submit tanpa item Partial tetap melewati dialog konfirmasi, karena submit mengubah stok dan tidak bisa dibatalkan.
  - Nomor surat jalan hanya diisi di Ringkasan dan tidak ikut disimpan di draf.
  - `ItemStatusChip` dan `DocumentTypeBadge` memotong teks (ellipsis) kalau ruangnya sempit. Ditemukan lewat test: chip meluap di baris rekap dengan angka besar.
- Test: `test/transaction_submit_test.dart` (5 alur ujung-ke-ujung yang memeriksa data backend). Total 116 test lulus.

### Verifikasi Tahap 3

- `flutter analyze`: No issues found.
- `flutter test`: 117 test lulus (termasuk `test/scanner_screen_test.dart` yang memakai peluncur scanner asli).
- `flutter build apk --debug`: berhasil; izin `android.permission.CAMERA` ikut di manifest hasil merge. Belum dijalankan di perangkat Android.
- Chrome headless (390x844, build web `--profile -O1`), 80 langkah, console bersih, 20 tangkapan layar dicek visual: daftar RCV/INT, detail baru, Scan QR di browser tanpa izin kamera → pesan izin ditolak → Input manual dengan banner alasan, melebihi sisa ("Maksimal 12 PAIL"), tambah manual, tandai tidak tersedia, penahan tombol kembali → Simpan draf → "Ada draf", lanjutkan draf, Ringkasan, surat jalan kosong, dialog Partial → Simpan sebagai Partial → berhasil (TRX-RCV-…) → daftar "Partial: 2 dari 3 item terpenuhi", draf basi (PO-2611-0043), dokumen diproses operator lain (PO-2611-0046), INT batas stok ("Maksimal 4 TBG").
- Bug yang ditemukan di Chrome dan sudah diperbaiki:
  1. Tombol Scan QR melempar exception: `pushNamed<ScanOutcome>` gagal cast `Route<dynamic>` ke `Route<ScanOutcome?>`. Tidak tertangkap widget test karena memakai scanner palsu → ditambah test dengan peluncur asli.
  2. Izin kamera ditolak membuat layar scanner kosong tanpa jalan keluar: `MobileScanner` menampilkan placeholder selama belum terinisialisasi, termasuk saat error, sehingga `errorBuilder` tidak pernah tampil. Layar scanner kini membaca `controller.value.error` sendiri dan menampilkan pesan + Input manual; saat menunggu kamera tampil "Menyiapkan kamera…".
  3. Teks bantu di kolom kode barang terpotong → `helperMaxLines: 2`.
- Catatan: kartu yang tampak abu-abu di tangkapan layar adalah sorotan fokus keyboard Flutter web (skrip memakai input keyboard), bukan gaya kartu.
- Belum diverifikasi: decode QR dari kamera sungguhan (direncanakan di Tahap 4 dengan QR dari Label QR); manual di ekstensi Mobile Simulator; perangkat Android.

### Butir "Selesai kalau" Tahap 3

| Butir | Status | Bukti |
| :--- | :--- | :--- |
| Satu RCV sampai submit: stok, mutasi, riwayat, status | Ya | `transaction_submit_test` "RCV lengkap" (PO-2611-0048, Tandai Selesai lewat submit biasa); Chrome (Simpan sebagai Partial) |
| Satu INT sampai submit: stok, mutasi, riwayat, status | Ya | `transaction_submit_test` "INT Tandai Selesai" (BON-2611-0016: argon 4 → saldo 0, dokumen SUBMITTED) |
| Status sesuai pilihan Partial / Tandai Selesai | Ya | Partial → OPEN + progres; Tandai Selesai → SUBMITTED |
| "Kalau tidak mulus" babak Memilih dokumen | Ya | kosong/tidak cocok, gagal + Coba lagi, SUBMITTED tidak bisa dibuka (`document_list_test`) |
| "Kalau tidak mulus" babak Menginput barang | Ya | semua penolakan scan, izin/kamera, melebihi sisa/stok, keluar (simpan/buang/batal), draf basi (`transaction_view_model_test`, `transaction_detail_test`, Chrome) |
| "Kalau tidak mulus" babak Ringkasan dan submit | Ya | Pending, surat jalan kosong, dialog Partial, diproses operator lain, gagal koneksi (`transaction_submit_test`, Chrome) |
| Unit test aturan kuantitas, status item, syarat submit di implementasi tiruan | Ya | `transaction_rules_test`, `mock_repositories_test`, `transaction_view_model_test` |
| Tambahan: RCV dengan satu barang tidak datang lewat tanda, tanda bisa dibatalkan, item kembali Pending | Ya | `transaction_submit_test` "RCV satu barang tidak datang" (resin ditandai → dibatalkan → Pending, submit tertahan → ditandai lagi → Simpan sebagai Partial; transaksi mencatat 0 + tanda, saldo resin tetap) |

## Perapian environment dan dokumen (2026-11-23)

Dikerjakan sebelum presentasi progress. Tidak ada perubahan pada layar.

### Struktur dokumen

- `dkumen konteks/` (salah ketik) di-rename menjadi `docs/`. Semua rujukan `docs/...` di dalam dokumen jadi benar tanpa perlu menyunting satu per satu.
- `CLAUDE.md` dipindah ke root repo, karena aturan hanya terbaca otomatis dari root.
- `AGENTS.md` dibuat sebagai pemegang aturan sebenarnya; `CLAUDE.md` menjadi penunjuk `@AGENTS.md`. Alasannya: OpenCode hanya memuat satu berkas instruksi dan memilih `AGENTS.md` lebih dulu, sedangkan Claude Code memakai `CLAUDE.md`.
- `Laporan Kelompok 2 Tekber Kelas B.pdf` dipindah ke `docs/referensi/Laporan_Kelompok_2_Tekber_Kelas_B.pdf` (nama dengan garis bawah, sesuai rujukan `AGENTS.md`).
- `wms-mobile-flutter-spec.md` dipindah ke `docs/referensi/arsip/` dan diberi header "ARSIP — TIDAK NORMATIF" berisi daftar tujuh pertentangannya dengan `CONTEXT.md`. Sebelumnya dokumen ini berbahaya karena isinya justru fitur yang sudah dibuang (lock 15 menit, push queue, audit log, QR 4 field, 4 kategori mutasi, kuantitas desimal).
- `dkumen konteks/README.md` dihapus (isinya hanya "Start of Stockisi", duplikat root README).
- `README.md` root dan `stockisi/README.md` ditulis ulang: isi repo, cara menjalankan, akun demo, status 13 layar, struktur folder.
- `.gitignore` root dibersihkan: hanya artefak lokal. Kelima entri dokumen dihapus karena keputusan berubah ke proyek kelompok.
- `docs/PENGEMBANGAN-UI.md` dibuat sebagai backlog perbaikan tampilan. Belum dijadwalkan. Berisi batas keras (tidak boleh mengubah CONTEXT §4, §6, §7, dan folder `data/`/`viewmodels/`), tujuh kriteria tampilan yang terukur, tujuh temuan dengan bukti `file:baris`, dan rencana D1-D4.

### Kode

- `stockisi/pubspec.yaml`: `environment.sdk` dari `^3.13.7` ke `^3.12.2`, `intl` dari `^0.20.3` ke `^0.20.2`, tambah `cupertino_icons ^1.0.8`.
- Alasan `cupertino_icons`: `flutter build web` memunculkan peringatan `Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons)`. Tidak ada kode yang memakai `CupertinoIcons`; framework merujuknya lewat transisi halaman iOS. Package ini hanya berisi aset font.
- Tidak ada file di `lib/` yang berubah.

### Verifikasi

| Perintah | Hasil |
| :--- | :--- |
| `flutter --version` | Flutter 3.44.5, Dart 3.12.2 |
| `flutter pub get` | Got dependencies |
| `flutter analyze` | No issues found! |
| `flutter test` | **117 test lulus** (klaim Tahap 3 terkonfirmasi) |
| `flutter build web --release` | Berhasil, `√ Built build\web` (64,5s) |

### Temuan setelah isi laporan bisa dibaca (2026-11-23)

Laporan diekstrak dengan PyMuPDF (`python -m pip install pymupdf pypdf`) supaya bisa diaudit isinya, bukan hanya judulnya.

**Yang terkonfirmasi cocok dengan `docs/CONTEXT.md`:**

- §2.4 menyebut eksplisit "Tabel 2.1 memuat 13 screen". Rujukan `CONTEXT` §4.1 sudah benar, tidak perlu diperbaiki.
- §2.7 menyebut "Tabel 2.2 memuat delapan tabel utama". Cocok dengan `CONTEXT` §8.
- §2.2.2: status dokumen OPEN dan SUBMITTED. §2.2.3: Pending/Partial/Complete, submit ditolak selama ada Pending, RCV wajib nomor surat jalan, Submit lewat satu RPC.
- §2.2.4: mutasi dua kategori, Receiving menambah dan Intransit mengurangi.
- §2.2.5: QR berisi kode barang, satuan, kode gudang; hanya tampil di layar, tanpa pencetakan.
- §2.2.6: riwayat hanya transaksi Submitted, badge RCV/INT, detail memuat operator pemroses.
- §2.5: alur Receiving, Intransit, dan Pengecekan Stok sesuai `CONTEXT` §7.
- Tidak ada satu pun kata "lock", "audit", "push", atau "15 menit" di seluruh laporan. Jadi pembuangan fitur di `CONTEXT` §4.3 memang sesuai laporan, bukan menyimpang darinya.

**Celah di laporan yang perlu ditutup:**

- **§2.6 "Tampilan Screen" kosong.** Hanya judul, langsung disusul §2.7. Tidak ada mockup atau tangkapan layar sama sekali, padahal judul bagiannya menjanjikan itu. Ini pekerjaan yang belum ada pemiliknya.
- **BAB 3 Implementasi, BAB 4 Hasil dan Pembahasan, dan BAB 5 Penutup kosong.** Hanya judul.
- **Keputusan draf sebenarnya sudah tertulis di laporan.** §2.2.3 dan §2.3 butir 2 menyebut draf "tersimpan sebagai draf di perangkat". `CONTEXT` §8 masih mencatatnya sebagai belum diputuskan. Perlu dikonfirmasi kelompok, karena pilihan "draf di Supabase sebagai transaksi DRAFT" akan menyimpang dari laporan tetapi lebih aman untuk syarat CRUD matkul.

## Tahap 4: Kartu Stok dan Label QR (2026-11-23)

Layar 8, 9, dan 10 Tabel 2.1.

### Yang dibangun

- `lib/screens/stock/stock_card_list_screen.dart` (layar 8): kolom pencarian sebagai elemen pertama, daftar barang berisi nama, kode, nomor rak, saldo, dan satuan. State memuat, kosong, gagal, dan "tidak cocok" dipisah.
- `lib/screens/stock/stock_card_detail_screen.dart` (layar 9): nama, kode, nomor rak, kode gudang, saldo besar (`AppTextStyles.quantityLarge`), tombol Label QR, dan riwayat mutasi dua kategori. Tiap baris mutasi memuat badge RCV/INT, tanggal, nomor dokumen, nomor transaksi, NIK operator, perubahan bertanda, dan saldo setelah mutasi.
- `lib/screens/stock/qr_label_screen.dart` (layar 10): QR digambar di klien dengan paket `barcode`, tanpa layanan gambar daring. Isi QR ditulis apa adanya di bawah gambar supaya bisa dicek tanpa memindai.
- Viewmodel baru: `stock_card_list_view_model.dart` (pencarian ditunda 300 ms, penjaga `_loadSeq` supaya hasil lama tidak menimpa hasil baru), `stock_card_detail_view_model.dart` (memuat barang dan mutasi sekaligus).

### Butir "Selesai kalau" Tahap 4

| Butir | Status | Bukti |
| :--- | :--- | :--- |
| Babak "Cek stok dan QR" ditelusuri | Ya | `history_and_stock_test`: pencarian, state kosong, detail, QR. `flutter test` "tab Kartu Stok menampilkan barang dan menyaring pencarian", "pencarian tanpa hasil menampilkan state kosong", "Label QR dibuka dari Detail Kartu Stok" |
| QR hasil Label QR dipakai untuk input barang | Ya | `history_and_stock_test` "isi QR dari Label QR diterima scanner di Detail Transaksi": isi QR dibaca dari layar Label QR (`BRG-0001|LBR|WH01`), diberikan ke `FakeScanner` seperti hasil kamera, lembar tambah jumlah terbuka, setelah ditambah muncul "Total 60/60" |

### Bug yang ditemukan dan diperbaiki saat verifikasi

- `StockCardListViewModel.warehouseEmpty` semula bernilai true juga saat hasil pencarian kosong, sehingga state "Belum ada barang" menutupi "Barang tidak ditemukan". Sekarang `warehouseEmpty` hanya dihitung saat kata kunci kosong.
- Baris judul + keterangan pada Detail Kartu Stok dan Detail Riwayat memakai `Row` tanpa `Expanded`, sehingga meluap 34 px saat lebar teks besar. Keduanya sekarang memakai `Expanded` + `TextOverflow.ellipsis`.

## Tahap 5: Riwayat (2026-11-23)

Layar 11 dan 12 Tabel 2.1.

- `lib/screens/history/history_list_screen.dart` (layar 11): daftar transaksi SUBMITTED gudang operator, terbaru dulu, badge RCV/INT, nomor transaksi, dokumen acuan, waktu, jumlah item, nama operator, dan penanda "Dokumen masih terbuka" untuk submit Partial.
- `lib/screens/history/history_detail_screen.dart` (layar 12): header berisi nomor transaksi, jenis, dokumen acuan, waktu submit, operator beserta NIK, gudang, dan nomor surat jalan (RCV saja). Lalu tabel item dengan nama, kode, rak, kuantitas, satuan, dan penanda "Tidak tersedia".
- Viewmodel baru: `history_list_view_model.dart`, `history_detail_view_model.dart` (membedakan `notFound` dari gagal koneksi).

**Butir "Selesai kalau":** transaksi yang disubmit muncul dengan data yang sama. Dibuktikan `history_and_stock_test` "tab Riwayat menampilkan transaksi dan bisa dibuka" (membuka detail menampilkan "Waktu submit") dan uji repository "riwayat hanya berisi transaksi gudang operator, terbaru dulu" serta "detail transaksi gudang lain ditolak sebagai tidak ditemukan".

### Verifikasi Tahap 4 dan 5

| Perintah | Hasil |
| :--- | :--- |
| `flutter analyze` | No issues found! |
| `flutter test` | 127 test lulus |
| `flutter build web --release` | Berhasil, tanpa peringatan font |
| Dijalankan di Chrome (`build/web` disajikan lokal) | Login `210457` berhasil; tab Dokumen tampil dengan segmen RCV/INT dan empat kartu dokumen; tab Kartu Stok tampil dengan kolom pencarian dan daftar barang beserta saldo; mengetuk kartu membuka `#/kartu-stok/detail` |

**Yang belum diverifikasi lewat tangkapan layar:** Detail Kartu Stok, Label QR, Riwayat, dan Detail Riwayat hanya diperiksa lewat widget test. Jendela browser tidak lagi bisa diambil tangkapan layarnya selama sesi ini. Perlu dicek manual sekali sebelum presentasi; langkahnya ada di `docs/DEMO.md`.

## Keputusan teknis

- Logo: wordmark teks "Stockisi" + ikon `inventory_2` di kotak navy (`StockisiWordmark`). Ikon launcher tetap bawaan Flutter. Diganti kalau logo resmi ada.
- Repository bekerja atas nama operator yang login dan membatasi gudang sendiri; layar tidak pernah mengirim kode gudang. Alasan: cocok dengan RLS Supabase.
- Deteksi dokumen berubah memakai `ReferenceDocument.version` (naik tiap submit); draf dan `SubmitRequest` membawa `basedOnVersion`.
- Status item `fulfilled` ("Sudah terpenuhi") ditambahkan untuk item bersisa 0 sejak awal (CONTEXT 6).
- Nomor surat jalan disimpan di transaksi, bukan di dokumen, karena satu PO bisa punya beberapa pengiriman Partial.
- Pesan error untuk operator dibuat oleh kelas exception; implementasi repository cukup memilih jenisnya.
- Akun "operator lain" (Rina, WH01) ditambahkan sehingga ada 4 akun, untuk simulasi dokumen diproses operator lain.
- Format nomor transaksi: `TRX-{RCV|INT}-{yyMMdd}-{urut 4 digit}`.
- Konfirmasi Submit (layar 7) berupa dialog di Ringkasan, tidak punya route sendiri.
- Verifikasi otomatis di Chrome headless lewat skrip Node + DevTools Protocol (tanpa package tambahan), karena tidak ada AVD dan alat otomasi browser lain.
- Sesi menyimpan NIK saja; profil diambil ulang dari repository saat dipulihkan, supaya akun yang dinonaktifkan tidak bisa masuk lewat sesi lama.
- Kata sandi dikosongkan setelah ditolak (NIK tetap), dipertahankan kalau gagalnya karena koneksi.
- Logout tidak menghapus draf; dialog menyebut nomor dokumen yang punya draf. Satu dialog saja (bukan peringatan lalu konfirmasi).
- Navigasi setelah logout ditangani `SessionGuard` (satu mekanisme), bukan oleh layar Profil.
- App selalu mulai dari Splash dan route terlindung dijaga sesi, karena di web URL bisa diketik langsung.
- Paket `barcode` dipakai khusus untuk menggambar QR di Label QR (layar 10). Hanya encoder, tanpa akses kamera; kamera tetap lewat `mobile_scanner`. Dipilih daripada `barcode_widget` karena cukup satu `CustomPainter` dan tidak menambah dependensi lagi.
- Paket `cupertino_icons` ditambahkan hanya sebagai aset font, untuk menghilangkan peringatan `flutter build web` tentang `CupertinoIcons` yang dirujuk framework lewat transisi halaman iOS.
- Batas `sdk ^3.12.2` dan `intl ^0.20.2` dipilih supaya `flutter pub get` jalan di Flutter 3.44.5 (Dart 3.12.2) tanpa merusak Flutter 3.47.9 milik komputer lain.
- Pencarian Kartu Stok ditunda 300 ms di viewmodel, bukan di layar, supaya perilakunya bisa diuji tanpa widget.
- `widgets/placeholder_screen.dart` dihapus setelah layar terakhir yang memakainya (Kartu Stok dan Riwayat) selesai dikerjakan.

- INT mendapat pilihan Simpan sebagai Partial / Tandai Selesai seperti RCV. Alasan: CONTEXT 6 dan laporan 2.2.3 tidak membedakan tipe; CONTEXT di atas kode lama.
- Nomor surat jalan diisi di Ringkasan, bukan Detail. Alasan: laporan Tabel 2.1 nomor 6.
- Baris mutasi kartu stok membawa NIK operator. Alasan: laporan 2.2.4.
- Paket QR: kode lama memakai `barcode` lewat `pdf`. Untuk tampilan di layar tanpa package tambahan, rencananya `barcode` dipakai untuk membangkitkan matriks QR lalu digambar dengan `CustomPainter`. Dipastikan di Tahap 1 dengan membaca API package-nya.

## Jawaban pertanyaan Tahap 0 (dijawab 2026-11-21)

1. Perangkat verifikasi: Chrome dengan ekstensi Mobile Simulator di komputer pemilik repo. Scan diuji lewat webcam laptop, izin kamera ditolak diuji lewat izin browser. Android menyusul (CONTEXT 10).
2. Logo: diputuskan sendiri (aturan "Kapan memutuskan sendiri"). Lihat Keputusan teknis.
3. Isi QR: `kode barang|satuan|kode gudang`, contoh `BRG-0012|PCS|WH01` (CONTEXT 6).
4. Barang tidak datang: item bisa ditandai "Tidak tersedia" (kuantitas 0) dan dihitung Partial; tanda bisa dibatalkan. Pending = belum diperiksa (CONTEXT 6).

## Pertanyaan terbuka untuk pemilik repo

Tidak ada.

## Usulan yang belum dibangun

- Perbaikan tampilan (design pass). Rincian, batas, dan urutannya ada di `docs/PENGEMBANGAN-UI.md`. **Jangan dikerjakan sebelum Tahap 5 selesai** dan sebelum pemilik repo menyetujui.

## Catatan untuk anggota yang mengerjakan layer data

- Kode lama tidak menghitung sisa kuantitas di klien; dulu itu tugas backend. Di Stockisi, kontrak repository dokumen harus mengembalikan item yang sudah berisi sisa, dan RPC submit perlu menghitung ulang sisa di sisi database.
- Validasi stok tersedia untuk INT di kode lama hanya di klien. Di Supabase perlu ditegakkan juga di RPC submit.
- Tempat menyimpan draf masih menunggu keputusan kelompok (CONTEXT 8).
- Untuk pindah ke Supabase: buat lima kelas yang mengimplementasikan kontrak di `stockisi/lib/data/repositories/`, lalu ganti pembuatan `Repositories` di `main.dart`. Janji tiap method tertulis di dokumentasi kontraknya.
- `TransactionRepository.submit` harus atomik (satu RPC): cek status, cek `basedOnVersion`, cek aturan (`transaction_rules.dart`), update stok, catat mutasi, simpan transaksi, naikkan versi dokumen, hapus draf.
- `ReferenceDocument.version` belum ada di tabel laporan 2.7; perlu kolom di `reference_documents` (atau padanannya, misalnya `updated_at`).
- `ReferenceDocumentItem.processedQuantity` = kolom "kuantitas terverifikasi" di `reference_document_items`.
- `SessionStore` hanya dipakai implementasi tiruan. Dengan Supabase, `AuthRepository.restoreSession` bisa memakai sesi `supabase_flutter`, tetapi tetap harus mengembalikan null untuk akun nonaktif (`profiles.is_active`).
- Transaksi menyimpan baris item yang ditandai "Tidak tersedia" dengan kuantitas 0 dan `markedUnavailable = true`; tidak ada mutasi stok untuk baris itu. Tabel `transaction_items` perlu kolom penanda ini.
- Nomor surat jalan vendor disimpan per transaksi (`transactions`), bukan per dokumen, karena satu PO bisa diterima dalam beberapa pengiriman.
- Login memakai NIK, sedangkan Supabase Auth memakai email/telepon. Perlu pemetaan NIK → akun Auth (misalnya email sintetis per NIK atau RPC lookup) tanpa membedakan pesan "NIK tidak terdaftar" dan "sandi salah".
