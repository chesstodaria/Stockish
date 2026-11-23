> # ⚠ ARSIP — TIDAK NORMATIF
>
> Dokumen ini **bukan acuan** untuk proyek Stockisi. Disimpan hanya sebagai
> riwayat dan bahan pertimbangan.
>
> Isinya sering **bertentangan** dengan keputusan kelompok yang berlaku:
>
> | Topik | Dokumen ini | Yang berlaku (`docs/CONTEXT.md`) |
> | :--- | :--- | :--- |
> | Status dokumen | 4 status: available / locked / completed / partial | 2 status: OPEN / SUBMITTED (§6) |
> | Kunci dokumen | 15 menit + reclaim + timer | tidak dibawa (§4.3) |
> | Audit log, push queue, sync ERP | ada | tidak dibawa (§4.3) |
> | Isi QR | 4 field | 3 field `kode\|satuan\|gudang` (§6) |
> | Kategori mutasi | 4 | 2: Receiving dan Intransit (§4.1) |
> | Kuantitas | `REAL` (desimal) | `int` (bulat) |
> | Sesi tunggal per NIK | dicek ke server | tidak dibawa (§4.3) |
>
> Kalau ada yang mengutip dokumen ini sebagai spesifikasi, arahkan ke
> `docs/CONTEXT.md`.

# Spesifikasi Arsitektur & Fungsional WMS Mobile StockFlow (Flutter/Dart)

Dokumen ini merupakan spesifikasi teknis dan operasional lengkap untuk pembangunan aplikasi **WMS (Warehouse Management System) Mobile** berbasis **Flutter / Dart**. Seluruh kebutuhan, aturan bisnis, skema data, dan alur kerja diikhtisarkan secara komprehensif dari proyek *Audit Trail StockFlow* dan disesuaikan untuk implementasi *pure mobile client-side* (tanpa ketergantungan backend/full-stack, berbasis *local database* / *mock service layer*).

---

## 1. Arsitektur Sistem & Batasan Konteks Mobile

Aplikasi StockFlow Mobile dirancang untuk menangani operasional penerimaan (*Receiving*) dan pengeluaran/pemindahan (*Intransit*) barang di gudang manufaktur menggunakan perangkat genggam/tablet.

### 1.1 Aturan Inti Operasional
- **1 Operator NIK = 1 Fixed Warehouse**: Setiap akun operator terikat secara permanen pada satu kode gudang tertentu (`warehouseCode`, contoh: `WH01`). Operator hanya dapat melihat dan mentransaksikan barang serta dokumen yang berada dalam lingkup gudang tersebut.
- **Single Active Session per Mobile App**: Satu NIK hanya diizinkan memiliki 1 sesi aktif pada aplikasi mobile (`app = 'MOBILE'`). Sesi baru akan membatalkan sesi lama (*session invalidation*).
- **Batch at Submit Transaction Model**: Proses pemindaian dan penginputan barang dalam suatu dokumen terkumpul dalam status *draft* di memori lokal/database aplikasi. Pembaruan stok aktual (*Stock Quantity*) dan riwayat aktivitas hanya terjadi saat tombol **Submit** ditekan oleh operator.
- **Sliding Document Lock (15 Menit)**: Dokumen referensi yang sedang diproses oleh seorang operator dikunci (`LOCKED`) untuk mencegah konflik dengan operator lain. Kunci memiliki batas waktu aktif 15 menit dan diperbarui secara otomatis (*sliding extension*) setiap kali ada aktivitas transaksi atau *heartbeat*.
- **Hard Limit Quantity**: Jumlah barang yang diinput tidak boleh melebihi kuantitas yang tertera pada dokumen referensi. Penginputan *over-quantity* ditolak secara otomatis oleh sistem.

---

## 2. Skema Data & Model Entitas (Client-Side DB / Dart Models)

Untuk aplikasi Flutter *pure mobile*, seluruh entitas diimplementasikan menggunakan SQLite (`sqflite`), Hive, atau *in-memory mock repository*. Relasi entitas diturunkan langsung dari acuan ERD StockFlow.

### 2.1 Ringkasan Entitas & Field Data

| Entitas | Field Utama | Tipe Data / Constraint | Deskripsi & Aturan Bisnis |
| :--- | :--- | :--- | :--- |
| **USER** | `id`, `nik`, `name`, `password`, `warehouseCode`, `role`, `isActive` | NIK (PK String), WHCode (FK), Role Enum | Akun operator warehouse. Field `isActive = true` wajib untuk login. |
| **WAREHOUSE** | `code`, `name` | Code (PK String) | Master gudang (contoh: `WH01` - Gudang Utama). |
| **ITEM** | `id`, `itemCode`, `name`, `uomId`, `uomName`, `warehouseCode`, `rackNumber` | ItemCode (PK String), WHCode (FK) | Master barang. Setiap item terikat pada 1 Gudang tetap dan memiliki lokasi rak (`rackNumber`). |
| **UOM** | `id`, `name` | ID (PK String) | Satuan ukuran barang (Pcs, Box, Roll, Kg, Meter, dll). |
| **STOCK** | `id`, `itemId`, `warehouseCode`, `quantity`, `lastUpdated` | ItemId (FK), WHCode (FK), Double Qty | Saldo stok fisik aktual di gudang tertentu per item. |
| **REFERENCE_DOCUMENT** | `id`, `refNumber`, `type`, `vendorDocNumber`, `warehouseCode`, `status`, `lockedByNik`, `lockedAt` | RefNumber (PK), Type (RCV/INT), Status (OPEN/LOCKED/SUBMITTED) | Dokumen acuan transaksi (PO untuk RCV, BON untuk INT). |
| **REFERENCE_DOCUMENT_ITEM**| `id`, `refDocId`, `itemId`, `expectedQty`, `scannedQty`, `itemStatus` | RefDocId (FK), ItemId (FK), Status (PENDING/COMPLETE/PARTIAL) | Detail item acuan beserta kuantitas target dan kuantitas yang telah diverifikasi. |
| **TRANSACTION** | `id`, `trxNumber`, `refDocNumber`, `documentType`, `status`, `userNik`, `submittedByNik`, `warehouseCode`, `vendorDocNumber`, `createdAt`, `submittedAt` | TrxNumber (PK), Status (DRAFT/SUBMITTED) | Header transaksi yang berhasil dikirim atau disimpan draft. |
| **TRANSACTION_ITEM** | `id`, `trxId`, `itemId`, `qty`, `uom`, `rackNumber` | TrxId (FK), ItemId (FK), Double Qty | Rincian barang yang ditransaksikan. |
| **AUDIT_LOG** | `id`, `userNik`, `action`, `entityName`, `entityId`, `timestamp`, `details`, `deviceInfo` | ID (Auto-increment PK) | Catatan jejak audit lokal seluruh tindakan operator. |
| **PUSH_QUEUE** | `id`, `trxId`, `pushStatus`, `retryCount`, `lastError`, `createdAt` | Status (PENDING/SUCCESS/FAILED_RETRYABLE/FAILED_FATAL) | Antrean sinkronisasi transaksi ke sistem eksternal/ERP. |

---

## 3. Spesifikasi Fitur & Aturan Bisnis Modul Mobile

### 3.1 Otentikasi, Splash Screen, & Session Management
- **Splash Screen Logic**: Saat aplikasi dibuka, sistem memeriksa keberadaan token / NIK aktif pada *secure storage* lokal (`FlutterSecureStorage`). Jika valid dan *Remember Login* aktif, aplikasi langsung masuk ke `MainHomeScreen`. Jika tidak, aplikasi menampilkan `LoginScreen`.
- **Remember Login**: Fitur opsional bagi operator untuk menyimpan kredensial/sesi login sehingga tidak perlu menginput NIK dan password setiap kali aplikasi di-restart atau tablet di-reboot.
- **Login Validation**: Validasi NIK dan Password. Mengembalikan status error jika akun tidak ditemukan, password salah, atau akun bertanda `isActive = false`.
- **Logout & Session Invalidation**: Dijalankan melalui tombol Logout di Profile. Menghapus token lokal, mengatur status sesi menjadi non-aktif, serta mencatat event `LOGOUT` ke dalam `AUDIT_LOG`.

### 3.2 List Dokumen Referensi & System Document Locking
- **Reference Document Screen**: Menampilkan daftar dokumen yang tersedia untuk gudang tempat operator bertugas, dibagi berdasarkan Tab:
  - **Receiving (RCV)**: Berasal dari *Purchase Order* (PO) vendor.
  - **Intransit (INT)**: Berasal dari *BON Pengeluaran / Transfer Internal*.
- **Mekanisme Locking**:
  - Ketika operator mengetuk salah satu dokumen berstatus `OPEN`, sistem mengubah status dokumen menjadi `LOCKED` atas nama `lockedByNik` operator tersebut.
  - Jika dokumen sedang dikunci oleh operator lain, dokumen bertanda warna terkunci (*disabled*) dan tidak dapat dibuka.
- **Sliding Lock Timer (15 Menit)**:
  - `LockTimerService` menjalankan *countdown* 15 menit yang ditampilkan dalam *badge countdown* di UI.
  - Setiap kali operator melakukan *scan* item, mengedit kuantitas, atau menekan tombol navigasi internal, timer di-reset kembali ke 15:00 (*sliding window*).
  - Jika timer habis (00:00) tanpa ada aktivitas, atau jika ada perintah *Force Unlock* (oleh Admin), sistem akan merilis kunci dokumen (`status = OPEN`), membatalkan *draft* lokal, dan menampilkan *Dialog Warning/Expired*.
  - **Navigasi Safe Guard**: Saat timer *expired* atau dokumen di-unlock, sistem akan menutup semua dialog/modal scanner yang terbuka dan mendaratkan pengguna kembali ke `ReferenceDocumentListScreen` secara aman tanpa mengalami penumpukan route (*stacking bug*).

### 3.3 Engine Transaksi Gudang (Receiving & Intransit)
- **Alur Receiving (IN / RCV)**:
  - Menggunakan dokumen acuan Purchase Order.
  - Wajib menginput `Vendor Document Number` (Nomor Surat Jalan Vendor) sebelum Submit akhir.
  - Memverifikasi kuantitas fisik barang yang diterima terhadap kuantitas PO.
- **Alur Intransit (OUT / INT)**:
  - Menggunakan dokumen acuan BON Pengeluaran.
  - Mengurangi jumlah stok fisik pada entitas `STOCK` ketika transaksi di-submit.
- **Item Verification State**:
  - `Pending`: Barang pada dokumen referensi belum di-scan/diinput.
  - `Complete`: Kuantitas fisik aktual yang di-scan **sama dengan** kuantitas referensi (`scannedQty == expectedQty`).
  - `Partial`: Kuantitas fisik aktual **kurang dari** kuantitas referensi (`scannedQty < expectedQty`).
- **Aturan Submit Transaksi**:
  - Transaksi **ditolak** jika masih terdapat item berstatus `Pending`.
  - Jika terdapat item berstatus `Partial` (tanpa ada item `Pending`), sistem menampilkan dialog pilihan konfirmasi:
    - *Simpan sebagai Partial*: Menyelesaikan transaksi dengan kuantitas parsial dan membiarkan sisa dokumen terbuka.
    - *Tandai Selesai*: Menyelesaikan seluruh dokumen dan menutup dokumen referensi.
- **Metode Input Barang**:
  - **QR Code Camera Scanner**: Menggunakan kamera tablet/HP untuk membaca QR Code barang.
  - **Manual Popup Input**: Input manual kode barang dan kuantitas melalui popup dialog sebagai pengoperasian alternatif.

### 3.4 Digital Stock Card (Kartu Stok Digital)
- **Pencarian & Filter Stok**: Operator dapat mencari barang berdasarkan nama atau kode item. Hasil pencarian difilter secara ketat berdasarkan `warehouseCode` akun yang sedang login.
- **Informasi Stok Utama**: Menampilkan Nama Barang, Kode Barang, Satuan (UOM), Nomor Rak (`rackNumber`), dan Saldo Stok Fisik saat ini.
- **Screen Ledger Mutasi (4 Kategori Dokumen)**:
  Saat item dipilih, aplikasi menampilkan halaman detail mutasi stok yang dikelompokkan ke dalam 4 kategori pergerakan:
  1. **Receiving**: Riwayat penerimaan dari vendor (penambahan stok).
  2. **Intransit**: Riwayat pengeluaran/pemindahan barang (pengurangan stok).
  3. **Adjustment**: Riwayat penyesuaian stok Opname.
  4. **Transfer / Other**: Riwayat mutasi antar rak/lokasi internal.
- **Visual Display**: Setiap baris mutasi menampilkan tanggal, nomor referensi, perubahan kuantitas (+/-), NIK operator pemroses, serta preview gambar/foto barang.

### 3.5 Pembuatan & Pencetakan Label QR Code
- **Generator QR Code**: Menghasilkan string terformat yang berisi representasi data barang (`itemCode|uom|warehouseCode|batchNo`) untuk dirender menjadi visual QR Code.
- **Print QR Direct Queue**: Fitur pencetakan label QR secara langsung dari aplikasi mobile ke printer thermal/label (via Bluetooth / Wi-Fi) tanpa membutuhkan aplikasi pihak ketiga.

### 3.6 Riwayat Transaksi (Transaction History)
- **Daftar Riwayat**: Menampilkan daftar transaksi yang telah berhasil dikirim (*Submitted*) oleh operator di gudang terkait.
- **Visual Badge**: Membedakan transaksi menggunakan *badge* warna (Contoh: `RCV` berlabel Hijau/Biru, `INT` berlabel Oranye/Ungu).
- **Detail Transaksi**: Menampilkan informasi lengkap header transaksi (Nomor Transaksi, Dokumen Referensi, Tanggal/Waktu, NIK Pembuat `submittedByNik`, Nama Operator Pemroses `processedByName`) serta tabel daftar item, kuantitas, dan UOM.

### 3.7 Offline Push Monitoring & Audit Trail Engine
- **Push Monitoring Queue**:
  - Seluruh transaksi yang dikirim di-entry ke dalam antrean `PUSH_QUEUE`.
  - Status Push: `PENDING` (dalam antrean), `SUCCESS` (berhasil terkirim), `FAILED_RETRYABLE` (gagal karena jaringan, dapat di-retry), `FAILED_FATAL` (gagal validasi).
  - Operator dapat melihat status antrean dan menekan tombol **Retry** secara manual dari UI Mobile jika terjadi kendala jaringan.
- **Audit Trail Local Hooks**:
  Sistem secara otomatis meng-capture dan menyimpan log aktivitas operator ke dalam entitas `AUDIT_LOG` pada aksi-aksi berikut:
  1. `LOGIN`: Saat pengguna berhasil otentikasi.
  2. `LOGOUT`: Saat pengguna menekan keluar dari aplikasi.
  3. `LOCK_DOC`: Saat pengguna membuka dan mengunci dokumen referensi.
  4. `UNLOCK_DOC`: Saat kunci dokumen dilepas atau kadaluarsa.
  5. `SUBMIT_TRX`: Saat transaksi dikirimkan.
  6. `PRINT_QR`: Saat label QR dicetak.
  7. `SEARCH_STOCK`: Saat pengguna melakukan pencarian kartu stok.
  8. `RETRY_PUSH`: Saat pengguna memicu ulang proses kirim antrean.

---

## 4. Arsitektur Navigasi Screen & Alur Kerja SOP

### 4.1 Peta Rute Navigasi Flutter (App Routes)
```text
[SplashScreen]
      │
      ├──> [LoginScreen]
      │
      └──> [MainHomeScreen] (BottomNavigationBar / Tabs)
                 │
                 ├── Tab 1: [ReferenceDocumentListScreen]
                 │               │
                 │               └──> [TransactionDetailScreen] (Scanner & Manual Popup)
                 │                          │
                 │                          └──> [TransactionSummaryScreen]
                 │                                     │
                 │                                     └──> [SubmitConfirmationModal]
                 │
                 ├── Tab 2: [StockCardListScreen]
                 │               │
                 │               └──> [StockCardDetailScreen] (4 Kategori Ledger)
                 │
                 ├── Tab 3: [TransactionHistoryScreen]
                 │               │
                 │               └──> [TransactionHistoryDetailScreen]
                 │
                 └── Tab 4: [ProfileScreen]
                                 │
                                 ├──> [PushMonitoringScreen]
                                 └──> Action: Logout -> Clear Session -> [LoginScreen]
```

### 4.2 SOP Penanganan State Navigasi & Safety Guards
1. **PopScope Guard pada Screen Detail Transaksi**: Mencegah pengguna keluar secara tidak sengaja (*back button*) tanpa mengonfirmasi pelepasan kunci dokumen (*Unlock Document*).
2. **Global Timer Event Guard**: Ketika `LockTimerService` memancarkan event `EXPIRED`, listener global memanggil `Navigator.popUntil(ModalRoute.withName('/ref_doc_list'))`, mematikan dialog/scanner aktif, dan menampilkan Dialog Notifikasi Kadaluarsa di atas Screen Utama List Dokumen.

---

## 5. Panduan Implementasi Kode Flutter / Dart

### 5.1 Struktur Arsitektur Kode (MVVM Pattern)
```text
lib/
├── core/
│   ├── constants/       # Color, Theme, Endpoint constants
│   ├── services/        # LockTimerService, DatabaseHelper, LocalStorageService
│   └── utils/           # Formatters, QRGeneratorHelper
├── data/
│   ├── datasources/     # Local SQLite DB (Tables: Users, Items, Stocks, RefDocs, AuditLogs)
│   ├── models/          # Dart Data Models (User, Item, RefDoc, Transaction, AuditLog)
│   └── repositories/    # Local Storage Repositories (Mock / SQLite Implementation)
├── providers/           # State Management (Provider / Riverpod / BLoC)
│   ├── auth_provider.dart
│   ├── transaction_provider.dart
│   ├── stock_card_provider.dart
│   └── lock_timer_provider.dart
└── views/
    ├── screens/         # Flutter Screen Widgets
    └── widgets/         # Reusable Custom Widgets (Badges, Dialogs, Cards)
```

### 5.2 Skrip Pembuatan Tabel SQLite Lokal (SQLite DDL Schema)

```sql
-- Tabel Master Gudang
CREATE TABLE warehouses (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL
);

-- Tabel Master User
CREATE TABLE users (
    nik TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    password TEXT NOT NULL,
    warehouse_code TEXT NOT NULL,
    role TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (warehouse_code) REFERENCES warehouses(code)
);

-- Tabel Master Item
CREATE TABLE items (
    id TEXT PRIMARY KEY,
    item_code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    uom_name TEXT NOT NULL,
    warehouse_code TEXT NOT NULL,
    rack_number TEXT,
    FOREIGN KEY (warehouse_code) REFERENCES warehouses(code)
);

-- Tabel Saldo Stok
CREATE TABLE stocks (
    id TEXT PRIMARY KEY,
    item_id TEXT NOT NULL,
    warehouse_code TEXT NOT NULL,
    quantity REAL NOT NULL DEFAULT 0.0,
    last_updated TEXT NOT NULL,
    FOREIGN KEY (item_id) REFERENCES items(id),
    FOREIGN KEY (warehouse_code) REFERENCES warehouses(code)
);

-- Tabel Dokumen Referensi
CREATE TABLE reference_documents (
    id TEXT PRIMARY KEY,
    ref_number TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL, -- 'RCV' atau 'INT'
    vendor_doc_number TEXT,
    warehouse_code TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'OPEN', -- 'OPEN', 'LOCKED', 'SUBMITTED'
    locked_by_nik TEXT,
    locked_at TEXT,
    FOREIGN KEY (warehouse_code) REFERENCES warehouses(code)
);

-- Tabel Detail Item Dokumen Referensi
CREATE TABLE reference_document_items (
    id TEXT PRIMARY KEY,
    ref_doc_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    expected_qty REAL NOT NULL,
    scanned_qty REAL NOT NULL DEFAULT 0.0,
    item_status TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'COMPLETE', 'PARTIAL'
    FOREIGN KEY (ref_doc_id) REFERENCES reference_documents(id),
    FOREIGN KEY (item_id) REFERENCES items(id)
);

-- Tabel Header Transaksi
CREATE TABLE transactions (
    id TEXT PRIMARY KEY,
    trx_number TEXT NOT NULL UNIQUE,
    ref_doc_number TEXT NOT NULL,
    document_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'DRAFT', -- 'DRAFT', 'SUBMITTED'
    user_nik TEXT NOT NULL,
    submitted_by_nik TEXT NOT NULL,
    warehouse_code TEXT NOT NULL,
    vendor_doc_number TEXT,
    created_at TEXT NOT NULL,
    submitted_at TEXT
);

-- Tabel Detail Item Transaksi
CREATE TABLE transaction_items (
    id TEXT PRIMARY KEY,
    trx_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    qty REAL NOT NULL,
    uom TEXT NOT NULL,
    rack_number TEXT,
    FOREIGN KEY (trx_id) REFERENCES transactions(id),
    FOREIGN KEY (item_id) REFERENCES items(id)
);

-- Tabel Audit Log Lokal
CREATE TABLE audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_nik TEXT NOT NULL,
    action TEXT NOT NULL,
    entity_name TEXT,
    entity_id TEXT,
    timestamp TEXT NOT NULL,
    details TEXT,
    deviceInfo TEXT
);

-- Tabel Push Queue Sync
CREATE TABLE push_queue (
    id TEXT PRIMARY KEY,
    trx_id TEXT NOT NULL,
    push_status TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'SUCCESS', 'FAILED_RETRYABLE', 'FAILED_FATAL'
    retry_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (trx_id) REFERENCES transactions(id)
);
```

### 5.3 Rekomendasi Package Flutter Utama
- `sqflite`: Database relational lokal SQL untuk menyimpan data transaksi, stok, dan audit log.
- `flutter_secure_storage`: Penyimpanan terenkripsi untuk menyimpan NIK, token, dan status *Remember Login*.
- `provider` / `flutter_riverpod`: Manajemen state reaktif untuk mengelola ViewModel transaksi, timer countdown, dan status antrean push.
- `mobile_scanner` / `qr_code_scanner`: Integrasi pemindaian QR Code menggunakan kamera HP/tablet.
- `qr_flutter`: Menghasilkan visual QR Code untuk pencetakan label barang.
- `blue_thermal_printer` / `pdf`: Mengirim perintah cetak label ke printer Bluetooth/Wi-Fi thermal.

---
