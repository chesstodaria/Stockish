# Rencana Tahap UI Stockisi

Setiap tahap dikerjakan dalam satu putaran. Di akhir tahap, berhenti, laporkan hasilnya, lalu tunggu persetujuan. Butir "Selesai kalau" adalah syarat yang harus dicek satu per satu sebelum tahap disebut selesai.

## Tahap 0: Membaca dan memetakan

Tujuan tahap ini adalah memahami kode lama sebelum membangun apa pun. Tidak ada kode yang ditulis di tahap ini.

- Periksa versi Flutter dan Dart yang terpasang.
- Petakan setiap file di `stockish/lib/` ke salah satu dari tiga nasib untuk proyek baru:
  - diadaptasi (logika atau model yang masih sesuai cakupan)
  - hanya jadi referensi perilaku
  - tidak dibawa, karena masuk daftar di `docs/CONTEXT.md` bagian 4.3
- Petakan perilaku kode lama yang perlu dipertahankan. Minimal:
  - format isi QR
  - perhitungan sisa kuantitas
  - dialog Partial
  - penahan tombol kembali
- Buat `docs/PROGRESS.md` yang berisi semua pemetaan di atas.

**Selesai kalau:**

- Pemetaan file dan perilaku sudah tertulis di `docs/PROGRESS.md`.
- Setiap hal yang tidak bisa dipastikan sendiri sudah ditulis sebagai pertanyaan untuk pemilik repo.

## Tahap 1: Fondasi

Tujuan tahap ini adalah membuat proyek baru yang bisa berjalan tanpa backend dan punya bahan dasar desain.

- Buat proyek Flutter baru di `stockisi/` dengan nama project `stockisi`, untuk platform Android dan web.
- Buat kontrak repository (abstract class) untuk:
  - autentikasi
  - dokumen referensi
  - draf
  - transaksi
  - kartu stok
- Buat implementasi tiruan di memori untuk setiap kontrak di atas. Implementasi ini menerapkan aturan bisnis di `docs/CONTEXT.md` bagian 6, dan diberi jeda buatan singkat supaya state memuat ikut teruji.
- Buat data dummy:
  - minimal 2 gudang
  - 3 operator, salah satunya nonaktif
  - sekitar 15 barang dengan nomor rak
  - beberapa dokumen RCV dan INT dengan variasi status (OPEN baru, OPEN dengan progres Partial, SUBMITTED)
  - riwayat mutasi yang konsisten dengan saldo stok
- Dokumen milik gudang lain harus ada di data dummy, supaya pembatasan per gudang bisa terlihat bekerja.
- Pasang tema dari `docs/CONTEXT.md` bagian 9:
  - warna
  - font Plus Jakarta Sans sebagai aset
  - gaya teks
  - komponen bersama (badge jenis dokumen, chip status item, tombol aksi utama, state memuat/kosong/gagal)
- Buat cangkang halaman utama dengan bottom navigation empat tab, beserta routing ke semua layar. Layar yang belum dikerjakan cukup berupa placeholder.
- Nama tampilan aplikasi adalah Stockisi.

**Selesai kalau:**

- App bisa dijalankan dan keempat tab bisa dibuka tanpa error.
- `stockisi/` tidak memuat HTTP client, `ApiService`, atau URL backend lama.
- `git status` menunjukkan tidak ada perubahan di dalam `stockish/`.
- Kontrak repository terdokumentasi singkat di kodenya. Penjelasan cukup dari sisi apa yang dijanjikan ke layar, bukan bagaimana cara menyimpannya.

## Tahap 2: Masuk dan Profil

- Splash memeriksa sesi tersimpan.
- Login menampilkan tiga kondisi: berhasil, salah kredensial, dan akun nonaktif.
- Profil menampilkan nama, NIK, dan gudang, serta Logout dengan konfirmasi. Kalau ada draf yang belum disubmit, operator diberi tahu dulu sebelum logout.

**Selesai kalau:**

- Babak "Masuk" dan "Keluar" di `docs/CONTEXT.md` bagian 7 sudah ditelusuri, termasuk cabangnya.
- Menutup lalu membuka app lagi langsung masuk ke halaman utama selama belum logout.

## Tahap 3: Dokumen dan transaksi

Ini tahap terbesar. Layar yang dikerjakan: Daftar Dokumen, Detail Transaksi, input manual, scan QR, Ringkasan Transaksi, dan Konfirmasi Submit.

- Daftar dokumen memakai segmen RCV/INT, pencarian, filter status, progres Partial, dan penanda draf.
- Detail transaksi berisi:
  - progres yang menempel di atas layar
  - kartu item dengan target, sudah diinput, dan status
  - tombol Scan besar di bawah, dengan input manual sebagai alternatif
  - aksi ubah dan hapus item
  - penahan tombol kembali dengan pilihan simpan draf, buang, dan batal
- Ringkasan transaksi berisi rekap item, kolom nomor surat jalan untuk RCV, dialog Partial, dan konfirmasi berhasil.
- Semua cabang kegagalan di `docs/CONTEXT.md` bagian 4.2 sudah ditangani.
- Kondisi "dokumen sudah diproses operator lain" harus bisa disimulasikan dari implementasi tiruan, misalnya lewat satu dokumen dummy yang statusnya berubah saat disubmit.

**Selesai kalau:**

- Satu RCV dan satu INT berhasil diproses sampai submit, dan setelah itu:
  - stok berubah
  - mutasi tercatat
  - riwayat bertambah
  - status dokumen sesuai pilihan Partial atau Tandai Selesai
- Setiap baris "Kalau tidak mulus" di babak "Memilih dokumen", "Menginput barang", dan "Ringkasan dan submit" sudah ditelusuri dan punya tujuan yang jelas.
- Ada unit test untuk aturan kuantitas, status item, dan syarat submit di implementasi tiruan.

## Tahap 4: Kartu Stok dan Label QR

- Daftar Kartu Stok dibuka dengan kolom pencarian (nama atau kode) dan hanya menampilkan barang di gudang operator.
- Detail Kartu Stok menampilkan saldo, satuan, nomor rak, dan riwayat mutasi dua kategori.
- Label QR dibuka dari Detail Kartu Stok. Isi QR-nya bisa dipindai balik oleh scanner app sendiri di Tahap 3.

**Selesai kalau:**

- Babak "Cek stok dan QR" sudah ditelusuri.
- QR hasil Label QR berhasil dipakai untuk input barang di Detail Transaksi.

## Tahap 5: Riwayat

- Daftar transaksi SUBMITTED dengan badge RCV atau INT.
- Detail riwayat berisi header dan tabel item.

**Selesai kalau:**

- Transaksi yang disubmit di Tahap 3 muncul di sini dengan data yang sama persis.

## Tahap 6: Pemeriksaan menyeluruh dan serah terima

- Telusuri ketujuh babak `docs/CONTEXT.md` bagian 7 dari awal sampai akhir, termasuk semua cabangnya, lalu catat hasilnya.
- Periksa konsistensi visual antarlayar: warna, ukuran teks, jarak, dan state memuat/kosong/gagal.
- Pastikan `flutter analyze` bersih dan `flutter test` lulus.
- Tulis `docs/HANDOFF.md` untuk anggota kelompok yang akan mengerjakan Supabase. Isinya:
  - daftar kontrak repository dan apa yang dijanjikan masing-masing
  - aturan bisnis yang saat ini ditegakkan di implementasi tiruan dan nantinya perlu ditegakkan di database atau RPC
  - pemetaan model app ke tabel laporan bagian 2.7
  - catatan bahwa tempat penyimpanan draf masih menunggu keputusan kelompok
- Tulis daftar layar beserta kondisi data yang perlu disiapkan untuk mengambil tangkapan layar laporan bagian 2.6.

**Selesai kalau:**

- `docs/HANDOFF.md` cukup untuk membuat implementasi Supabase tanpa membaca kode layar.
- Tidak ada cabang alur yang berakhir buntu.
