# Konteks Proyek Stockisi

Isi dokumen ini fakta dan keputusan yang sudah disepakati. Aturan kerja ada di `CLAUDE.md`, dan langkah pengerjaan ada di `docs/PLAN.md`.

## 1. Proyek dan matkul

Stockisi adalah final project matkul Teknologi Berkembang, kelas B, Kelompok 2, Departemen Sistem Informasi ITS, tahun ajaran 2026/2027. Aplikasinya mobile WMS untuk operator gudang manufaktur: penerimaan barang dari vendor (Receiving), pengeluaran atau transfer barang (Intransit), pengecekan stok, dan label QR barang.

Syarat minimal ide dari asisten praktikum yang harus tetap terpenuhi oleh aplikasi akhir:

- Aplikasi mobile dibuat dengan Flutter, dan menyelesaikan satu masalah nyata.
- Minimal 5 layar berbeda. Splash tidak dihitung.
- Ada data yang disimpan lalu ditampilkan kembali, minimal 2 jenis data yang saling berhubungan.
- Pengguna bisa menambah, melihat, mengubah, dan menghapus minimal satu jenis data.
- Database memakai Supabase atau Firebase. Kelompok memilih Supabase.
- Pekerjaan bisa dibagi ke seluruh anggota (6 sampai 7 orang), dan kontribusi tiap anggota dicatat di logbook mingguan.

## 2. Pembagian pekerjaan

Repo ini adalah repo GitHub kelompok, `chesstodaria/Stockish`, yang sudah di-clone ke lokal. Isinya baru dua hal: folder `stockish/` berisi aplikasi lama, dan `README.md` yang praktis kosong. Aplikasi hasil perombakan dibangun sebagai proyek Flutter baru di folder `stockisi/`, berdampingan dengan `stockish/`, dan aplikasi lama dibiarkan utuh.

Pengerjaannya bertahap. Tahap sekarang adalah perombakan UI dan alur layar dengan data tiruan. Layer data Supabase (Auth, tabel, Row Level Security, dan fungsi RPC untuk submit) akan dikerjakan anggota kelompok lain setelah tahap ini selesai. Siapa mengerjakan bagian apa belum ditentukan.

Karena itu, layar tidak boleh tahu dari mana datanya berasal. Hasil tahap ini harus bisa diteruskan oleh orang lain hanya dengan mengganti implementasi repository.

## 3. Kondisi kode lama di `stockish/`

Kode di folder `stockish/` adalah aplikasi milik anggota kelompok yang dibawa sebagai bahan awal. Kode ini menjadi referensi perilaku dan sumber bagian yang bisa diadaptasi, tetapi tidak dijalankan ulang dan tidak diubah. Fakta yang sudah diperiksa:

- Nama package di `pubspec.yaml` adalah `stockflow_mobile`, dan judul aplikasinya masih "StockFlow". Nama produk yang dipakai kelompok adalah **Stockisi**.
- Polanya MVVM dengan `provider`: screens, viewmodels, repositories, services, dan models.
- Semua repository memanggil backend REST terpisah bernama `stockflow-backend`, di `http://<host>:8080/api/v1`. Backend itu **tidak ada di repo dan tidak tersedia**, sehingga app dalam kondisi sekarang tidak bisa dipakai sama sekali, bahkan untuk login.
- SQLite (`sqflite`) di kode lama hanya dipakai untuk progress draf per dokumen, log debug autentikasi, dan antrean audit log.
- Navigasi lama memakai menu kotak di Dashboard. Ini berbeda dengan rancangan kelompok yang memakai bottom navigation.
- Aset gambar yang sudah ada: `assets/images/Logo_Splash.png`, `Mobile.png`, dan `company_logo.png`.
- Ada fitur di kode lama yang di luar cakupan kelompok (lihat bagian 4.3).

Kode lama tetap berguna sebagai referensi perilaku, misalnya validasi kuantitas yang mengembalikan pesan spesifik dan dialog Partial di ringkasan transaksi. Ada dua hal yang kelihatannya ada di kode lama tetapi sebenarnya tidak bekerja. Pertama, `PopScope` di detail transaksi tidak menahan tombol kembali sama sekali. Kedua, field `receivedQuantitySoFar` tidak pernah diisi, karena sisa kuantitas dulu dihitung backend. Kedua perilaku itu dibangun baru di Stockisi. Pemetaan lengkapnya ada di `docs/PROGRESS.md`.

## 4. Cakupan

Acuan utama cakupan adalah laporan kelompok di `docs/referensi/`, terutama Bab 2. Bagian ini mencatat apa yang diambil, apa yang ditambahkan, dan apa yang dibuang.

### 4.1 Diambil dari laporan apa adanya

- 13 layar pada Tabel 2.1 laporan.
- Halaman utama memakai bottom navigation dengan empat tab: Dokumen, Kartu Stok, Riwayat, dan Profil.
- Alur Receiving dan Intransit, status item Pending, Partial, dan Complete, serta aturan submit (bagian 6).
- Kartu stok menampilkan riwayat mutasi dalam dua kategori, yaitu Receiving dan Intransit.
- Label QR hanya ditampilkan di layar dan dibuka dari Detail Kartu Stok. Tidak ada pencetakan.
- Profil berisi nama, NIK, gudang, dan tombol Logout.

### 4.2 Ditambahkan karena cabang alurnya belum tertutup di laporan

- **Draf bisa dilanjutkan.** Kalau operator menekan kembali di Detail Transaksi yang sudah berisi input, muncul pilihan untuk menyimpan draf lalu keluar, membuang draf, atau batal. Dokumen yang punya draf diberi penanda "Ada draf" di daftar dokumen. Saat dokumen itu dibuka lagi, input sebelumnya muncul kembali.
- **Progres dokumen Partial.** Dokumen yang disubmit dengan pilihan Simpan sebagai Partial tetap berstatus OPEN dan menampilkan progresnya di daftar, misalnya "3 dari 5 item terpenuhi". Saat dibuka lagi, target tiap item adalah sisanya, yaitu kuantitas dokumen dikurangi kuantitas yang sudah diterima atau dikeluarkan sebelumnya.
- **Dokumen sudah diproses operator lain.** Tidak ada mekanisme kunci dokumen, jadi dua operator di gudang yang sama bisa membuka dokumen yang sama. Ada dua titik yang bisa memunculkan kondisi ini. Pertama, saat submit, ketika dokumen ternyata sudah SUBMITTED atau sisanya sudah berubah. Kedua, saat melanjutkan draf yang dokumennya sudah berubah. Di kedua titik, operator mendapat pesan yang jelas, draf dibuang, lalu operator kembali ke daftar dokumen.
- **Kegagalan scan:**
  - Izin kamera ditolak atau kamera tidak tersedia: operator diarahkan ke input manual.
  - QR tidak bisa dibaca formatnya: ditolak dengan pesan.
  - Barang milik gudang lain: ditolak dengan pesan.
  - Barang tidak ada di dokumen: ditolak dengan pesan.
  - Kuantitas melebihi batas: ditolak dengan pesan yang menyebut batasnya.

### 4.3 Tidak dibawa dari kode lama

Fitur berikut tidak ada di laporan atau membutuhkan server yang tidak tersedia, jadi tidak dibangun di `stockisi/`:

- kunci dokumen 15 menit beserta timer, reclaim lock, dan validasi lock
- push monitoring dan sinkronisasi ERP
- audit log, activity log, dan log debug autentikasi
- layar Performa
- Print QR, PDF label, dan print via jaringan
- lampiran kartu stok (3D, engineering drawings, technical info, goods)
- pengecekan sesi tunggal ke server, polling sesi, idle timeout, dan banner koneksi global

Kondisi tanpa koneksi cukup ditangani sebagai state error di tiap layar yang memuat data.

## 5. Pengguna dan kondisi kerja

Penggunanya hanya satu peran, yaitu operator gudang manufaktur. Setiap operator punya NIK aktif dan terikat ke satu gudang tetap. Operator hanya melihat dan memproses dokumen serta barang di gudang itu.

Operator bekerja berdiri di depan rak atau di area penerimaan barang. Satu tangan sering memegang barang, kadang memakai sarung tangan, dan pencahayaan gudang tidak selalu terang. Aplikasinya dipakai di HP dengan orientasi portrait.

## 6. Aturan bisnis

**Akses dan sesi**

- Login memakai NIK dan kata sandi.
- Akun nonaktif ditolak dengan pesan khusus. NIK yang tidak terdaftar dan kata sandi yang salah ditolak dengan satu pesan yang sama, supaya tidak membocorkan NIK mana yang terdaftar.
- Sesi disimpan di perangkat. Splash memeriksa sesi itu, lalu mengarahkan ke halaman utama atau ke login.
- Logout menghapus sesi dan kembali ke login.

**Dokumen referensi**

- RCV bersumber dari Purchase Order, dan INT dari BON pengeluaran atau transfer internal.
- Status dokumen ada dua: OPEN dan SUBMITTED. Hanya dokumen OPEN yang bisa diproses. Dokumen SUBMITTED tampil sebagai selesai.

**Input barang**

- Barang diinput lewat scan QR kamera atau lewat input manual (kode barang dan kuantitas).
- Isi QR adalah `kode barang|satuan|kode gudang`, misalnya `BRG-0012|PCS|WH01`. QR di Label QR dan pembaca di scanner sama-sama memakai format ini.
- Kuantitas harus lebih dari nol.
- Total input per item tidak boleh melebihi sisa kuantitas dokumen.
- Untuk INT, total input juga tidak boleh melebihi saldo stok barang itu saat ini.
- Scan atau input manual untuk barang yang sudah punya input akan menambah jumlahnya. Mengubah kuantitas langsung dari kartu item akan mengganti nilainya. Item draf juga bisa dihapus, yang membuat statusnya kembali Pending.

**Status item**

- Pending: item belum diperiksa, artinya belum ada input dan belum ditandai kosong.
- Partial: input lebih dari nol tetapi kurang dari sisa, atau item ditandai "Tidak tersedia" (kuantitas 0). Tanda ini dipakai kalau barang sama sekali tidak datang pada RCV atau tidak bisa diambil pada INT. Tanda bisa dibatalkan, dan item kembali Pending.
- Complete: input sama dengan sisa.
- Item yang sisanya sudah 0 sejak awal (terpenuhi di transaksi Partial sebelumnya) tampil sebagai sudah terpenuhi dan tidak ikut dihitung.

Dengan aturan ini, dokumen yang salah satu barangnya tidak datang tetap bisa disubmit. Operator menandai item itu, lalu memilih Simpan sebagai Partial atau Tandai Selesai di dialog Partial. Aturan "submit ditolak selama masih ada Pending" tetap berlaku, karena Pending artinya item yang belum diperiksa.

**Submit**

- Submit ditolak selama masih ada item Pending.
- RCV wajib mengisi nomor surat jalan vendor sebelum submit.
- Kalau ada item Partial, operator memilih salah satu:
  - Simpan sebagai Partial: transaksi tersimpan dan dokumen tetap OPEN untuk sisanya.
  - Tandai Selesai: transaksi tersimpan dan dokumen menjadi SUBMITTED walaupun ada kekurangan.
- Submit berhasil menambah stok (RCV) atau mengurangi stok (INT), mencatat mutasi di kartu stok, membuat transaksi baru di riwayat, dan membuang draf dokumen itu.

**Transaksi dan riwayat**

- Riwayat hanya menampilkan transaksi SUBMITTED di gudang operator. Transaksi RCV dan INT dibedakan dengan badge warna.
- Detail riwayat memuat nomor transaksi, dokumen referensi, tanggal dan waktu, nama operator pemroses, serta daftar item lengkap dengan kuantitas dan satuan.

## 7. Customer journey

Perjalanan operator dikelompokkan per babak. Kolom "Kalau tidak mulus" berisi cabang yang harus punya tujuan jelas, bukan jalan buntu.

| Babak | Yang dilakukan operator | Yang dilihat atau didapat | Kalau tidak mulus |
| :--- | :--- | :--- | :--- |
| Masuk | Buka app, login dengan NIK dan kata sandi kalau belum ada sesi | Langsung ke tab Dokumen kalau sesi masih tersimpan | Pesan salah login atau akun nonaktif muncul di form tanpa menghapus NIK yang sudah diketik |
| Memilih dokumen | Pilih segmen RCV atau INT, cari nomor dokumen, lalu ketuk dokumen OPEN | Nomor dokumen, jumlah item, status, progres Partial, dan penanda draf | Daftar kosong, gagal memuat (ada tombol coba lagi), atau dokumen SUBMITTED yang tidak bisa dibuka |
| Menginput barang | Scan QR atau input manual, isi jumlah, lalu ubah atau hapus item kalau keliru | Progres "x dari y item" di atas layar, dan kartu item dengan target, sudah diinput, serta status | Cabang kegagalan scan di bagian 4.2, input melebihi batas, atau keluar di tengah jalan (simpan draf, buang, batal) |
| Ringkasan dan submit | Periksa rekap, isi nomor surat jalan untuk RCV, lalu tekan Submit | Konfirmasi berhasil beserta nomor transaksi, lalu kembali ke daftar dokumen | Masih ada Pending, nomor surat jalan kosong, ada Partial (dialog pilihan), atau dokumen sudah diproses operator lain |
| Cek stok dan QR | Cari barang berdasarkan nama atau kode, buka detail, lalu buka Label QR | Saldo, satuan, nomor rak, riwayat mutasi Receiving dan Intransit, dan QR yang siap dipindai | Barang tidak ditemukan, atau barang belum punya riwayat mutasi |
| Meninjau riwayat | Buka tab Riwayat, lalu ketuk sebuah transaksi | Badge RCV atau INT, header transaksi, dan tabel item | Riwayat masih kosong |
| Keluar | Buka Profil, lalu tekan Logout dan konfirmasi | Kembali ke layar login | Ada draf yang belum disubmit: operator diberi tahu dulu sebelum logout |

## 8. Data

Delapan tabel rancangan di laporan bagian 2.7 menjadi acuan bentuk data: `warehouses`, `profiles`, `items`, `stocks`, `reference_documents`, `reference_document_items`, `transactions`, dan `transaction_items`. Model di app mengikuti bentuk itu supaya nanti mudah dipetakan ke Supabase.

Satu hal belum diputuskan kelompok, yaitu tempat menyimpan draf. Pilihan pertama sesuai teks laporan, yaitu draf disimpan di perangkat. Pilihan kedua, draf disimpan di Supabase sebagai transaksi berstatus `DRAFT`. Pilihan kedua membuat CRUD-nya jelas terjadi di database sehingga syarat matkul lebih aman terpenuhi. Tampilan dan alur layar sama untuk kedua pilihan, jadi keputusan ini tidak menghalangi tahap UI.

## 9. Arah desain

- **Ergonomi:**
  - Aksi utama seperti Scan, Submit, dan Simpan berada di bagian bawah layar, dalam jangkauan jempol.
  - Target sentuh minimal 48 dp, dan tombol aksi utama setinggi sekitar 56 dp.
  - Angka kuantitas ditulis besar dan mudah dibaca dari jarak lengan.
- **Warna:**
  - Navy `#1B2A5E` dari kode lama dipertahankan sebagai warna teks utama dan aksen.
  - Permukaan memakai putih hangat.
  - Receiving punya warna identitas mint, dan Intransit peach. Keduanya dipakai konsisten di segmen, badge, dan header transaksi.
  - Status item memakai latar pastel dengan teks gelap, ditambah ikon dan label. Pending abu-abu, Partial kuning, dan Complete hijau. Informasi status tidak boleh hanya disampaikan lewat warna.
  - Kontras teks terhadap latar memenuhi minimal WCAG AA.
- **Tipografi:** satu keluarga font sans yang mudah dibaca, Plus Jakarta Sans, dibundel sebagai aset supaya tidak bergantung internet. Hierarki dibangun lewat ukuran, ketebalan, dan jarak.
- **Yang dihindari:** gradien besar, efek kaca, emoji sebagai ikon, ilustrasi dekoratif yang tidak memberi informasi, dan semua kartu dengan bentuk serta bobot yang sama.
- **Pola layar:**
  - Daftar dokumen memakai segmented control RCV/INT, kolom pencarian, dan filter status.
  - Detail transaksi menempelkan progres di atas layar dan tombol Scan besar di bawah.
  - Kartu Stok dibuka dengan kolom pencarian sebagai fokus utama.
  - Setiap layar yang memuat data punya state memuat, kosong, dan gagal.

## 10. Lingkungan

- Proyek baru `stockisi/` dibuat untuk platform Android dan web, sesuai dua cara menjalankan app yang diajarkan di praktikum.
- Package di kode lama yang relevan untuk tahap UI: `provider`, `mobile_scanner`, `flutter_secure_storage`, `intl`, dan `barcode`.
- Package untuk backend lama dan pencetakan (`http`, `dio`, `pdf`, `printing`, `share_plus`) tidak dibawa ke proyek baru.
- Verifikasi tahap UI dilakukan di Chrome dengan ekstensi Mobile Simulator, yang sudah terpasang di komputer pemilik repo. Scan diuji lewat webcam laptop. Cabang izin kamera ditolak diuji lewat izin browser. Pengujian di Android menyusul kalau nanti ada perangkat.
