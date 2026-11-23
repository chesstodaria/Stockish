# Skrip Demo Presentasi

Catatan untuk presentasi progress. Data berasal dari repository tiruan di
memori, jadi **isi ulang halaman akan mengembalikan semua data ke kondisi
awal**. Jangan refresh di tengah demo.

## Persiapan

```bash
cd stockisi
flutter pub get
flutter run -d chrome
```

Kalau Chrome bermasalah, cadangan: `flutter run -d edge` atau
`flutter emulators --launch Medium_Tablet` lalu `flutter run`.

Buka di jendela selebar ±390 px (mode HP di DevTools) supaya tata letak
terlihat seperti di perangkat.

## Akun

Kata sandi semua akun: `stockisi123`.

| NIK | Nama | Gudang | Status | Dipakai untuk |
| :--- | :--- | :--- | :--- | :--- |
| `210457` | Budi Santoso | WH01 Gudang Bahan Baku Sidoarjo | aktif | akun utama demo |
| `210512` | Rina Wulandari | WH01 | aktif | "operator lain" di gudang yang sama |
| `220118` | Siti Rahmawati | WH02 Gudang Barang Jadi Pasuruan | aktif | bukti data terpisah per gudang |
| `198803` | Agus Prasetyo | WH01 | nonaktif | bukti akun nonaktif ditolak |

## Dokumen untuk tiap cabang

Semua nomor di bawah ini milik WH01, jadi terlihat oleh Budi dan Rina.

| Nomor | Cabang yang ditunjukkan |
| :--- | :--- |
| `PO-2611-0041` | RCV baru, semua item Pending. Untuk alur normal sampai submit |
| `PO-2611-0048` | RCV baru dengan item sedikit, paling cepat untuk submit lengkap |
| `PO-2611-0043` | RCV dengan progres Partial "3 dari 5 item terpenuhi". Budi punya draf lama untuk dokumen ini, jadi membuka draf memunculkan pesan "dokumen sudah berubah" |
| `PO-2611-0046` | RCV yang akan diselesaikan Rina tepat sebelum submit pertama, untuk pesan "sudah diproses operator lain" |
| `BON-2611-0012` | INT dengan progres Partial "2 dari 4 item terpenuhi" |
| `BON-2611-0014` | INT baru, Budi punya draf yang masih valid |
| `BON-2611-0016` | INT dengan gas argon diminta 10 TBG padahal saldo 4 TBG, untuk batas stok |

Dokumen gudang lain: `PO-2611-0052` milik WH02. Tidak akan muncul untuk Budi.

## Urutan demo (±6 menit)

**1. Masuk dan konteks (30 detik)**

- Splash → Login. Masukkan NIK `198803` / `stockisi123` → tampil "Akun Anda
  nonaktif". NIK tetap ada di kolom, hanya kata sandi yang dikosongkan.
- Ganti ke `210457` / `stockisi123` → masuk ke tab Dokumen.
- Sebutkan: repo baru `stockisi/`, aplikasi lama `stockish/` disimpan sebagai
  referensi dan tidak dijalankan.

**2. Daftar Dokumen (60 detik)**

- Tunjukkan segmen RCV / INT dan kolom pencarian.
- Ketuk `PO-2611-0043` → kartu menampilkan progres Partial dan penanda
  "Ada draf".

**3. Alur Receiving sampai submit (2 menit)**

- Buka `PO-2611-0048`.
- Tekan Scan QR → jelaskan bahwa di browser izin kamera ditolak, lalu aplikasi
  menawarkan input manual. Ini cabang kegagalan yang memang dirancang.
- Input manual satu barang, lalu coba kuantitas melebihi sisa → ditolak dengan
  pesan yang menyebut batasnya.
- Lengkapi semua item sampai status Complete.
- Ringkasan → coba Submit tanpa nomor surat jalan → ditolak.
- Isi nomor surat jalan → Submit → berhasil, muncul nomor transaksi.

**4. Bukti datanya berubah (60 detik)**

- Buka tab **Kartu Stok** → cari barang yang tadi diterima → saldo bertambah.
- Buka detail barang → tunjukkan riwayat mutasi: kategori Receiving, tanggal,
  nomor dokumen, dan NIK operator pemroses.
- Tekan **Label QR** → tunjukkan QR dan isi `kode|satuan|gudang` di bawahnya.
  Jelaskan sesuai laporan 2.2.5: hanya tampil di layar, tanpa pencetakan.

**5. Riwayat (45 detik)**

- Buka tab **Riwayat** → transaksi yang baru disubmit muncul di paling atas
  dengan badge RCV.
- Ketuk → header transaksi, surat jalan, operator, dan tabel item.

**6. Cabang "tidak mulus" (45 detik, opsional)**

- Kembali ke Dokumen, buka `BON-2611-0016`, input argon 10 TBG → ditolak karena
  saldo hanya 4 TBG.
- Atau buka `PO-2611-0043` → lanjutkan draf → muncul pesan dokumen sudah
  berubah dan draf dibuang.

**7. Profil (15 detik)**

- Tunjukkan nama, NIK, gudang, dan tombol Logout. Logout mengembalikan ke Login.

## Kalau ditanya

| Pertanyaan | Jawaban singkat |
| :--- | :--- |
| Datanya dari mana? | Repository tiruan di memori. Layar tidak tahu sumbernya, jadi pindah ke Supabase cukup mengganti implementasi repository |
| Berapa layar? | 13 layar sesuai Tabel 2.1 laporan, semuanya sudah jalan |
| Kenapa tidak ada kunci dokumen 15 menit? | Tidak ada di laporan. Fitur itu ada di aplikasi lama dan sengaja tidak dibawa (CONTEXT 4.3) |
| Kenapa tidak ada tombol cetak label? | Laporan 2.2.5 menyatakan pencetakan di luar cakupan |
| Kalau dua operator membuka dokumen yang sama? | Tidak dikunci. Saat submit, dokumen diperiksa ulang; kalau sudah berubah, operator diberi pesan dan drafnya dibuang (CONTEXT 4.2) |
| Kekurangan yang masih ada? | Layer data Supabase belum ada, dan perbaikan tampilan masih berupa backlog di `docs/PENGEMBANGAN-UI.md` |

## Sebelum tampil

```bash
cd stockisi
flutter analyze     # harus "No issues found!"
flutter test        # 126 test
```

Data tiruan memakai jeda buatan 500 ms supaya state memuat terlihat. Itu
disengaja, bukan aplikasi lambat.
