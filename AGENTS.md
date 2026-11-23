# Aturan Kerja Agen untuk Repo Stockisi

File ini berisi aturan, dan berlaku untuk semua agen AI (OpenCode, Claude Code,
Cursor, dan lainnya). `CLAUDE.md` hanya menunjuk ke file ini.

Fakta tentang proyek ada di `docs/CONTEXT.md`, urutan pekerjaan ada di
`docs/PLAN.md`, dan catatan kemajuan antarsesi ada di `docs/PROGRESS.md`.

## Urutan baca di awal setiap sesi

1. `AGENTS.md` (file ini)
2. `docs/PROGRESS.md`, untuk melihat tahap terakhir, keputusan yang sudah diambil, dan pertanyaan yang masih terbuka
3. `docs/CONTEXT.md`
4. `docs/PLAN.md`, khusus bagian tahap yang sedang berjalan
5. `docs/referensi/Laporan_Kelompok_2_Tekber_Kelas_B.pdf`, kalau butuh rincian yang tidak ada di `docs/CONTEXT.md`

Jangan mulai mengubah kode sebelum kelima langkah di atas selesai. Kalau `docs/PROGRESS.md` belum ada, berarti ini sesi pertama, jadi mulai dari Tahap 0 di `docs/PLAN.md`.

## Sumber kebenaran

Kalau ada perbedaan antarsumber, urutan yang berlaku:

1. Jawaban pemilik repo di sesi ini
2. `docs/CONTEXT.md`
3. Laporan kelompok di `docs/referensi/`
4. Kode lama di `stockish/`, yang hanya dipakai sebagai referensi perilaku dan bukan sebagai spesifikasi

Komentar di kode lama sering merujuk ke file seperti `02_Feature_Authentication.md` atau `05_Decision_Log.md`. File-file itu tidak ada di repo, jadi jangan dicari dan jangan ditebak isinya.

## Batas pekerjaan tahap ini

- Aplikasi baru dibangun di folder `stockisi/` di root repo. Folder `stockish/` berisi aplikasi lama dan hanya boleh dibaca sebagai referensi. Jangan mengubah, memindah, atau menghapus apa pun di `stockish/`.
- Pekerjaan sekarang hanya **UI dan alur layar**. Data berasal dari repository tiruan (mock) di memori.
- Jangan memasang Supabase, Firebase, HTTP client baru, atau backend apa pun. Layer data asli akan dikerjakan anggota kelompok lain di tahap berikutnya.
- Jangan mengerjakan fitur yang di `docs/CONTEXT.md` ditandai sebagai fitur yang dibuang. Kalau muncul ide fitur baru, catat di `docs/PROGRESS.md` sebagai usulan, lalu jangan dibangun.
- Kerjakan satu tahap `docs/PLAN.md` per putaran. Setelah sebuah tahap selesai, berhenti, laporkan, dan tunggu persetujuan sebelum masuk ke tahap berikutnya.
- Perbaikan tampilan yang belum dijadwalkan ada di `docs/PENGEMBANGAN-UI.md`. Itu backlog, bukan izin untuk mengerjakannya sekarang.

## Git

- Commit di akhir setiap tahap, dengan pesan yang menyebut nama tahapnya.
- Jangan push tanpa diminta.
- **Semua dokumen di `docs/` di-commit dan dibagi ke seluruh anggota kelompok.** Ini perubahan keputusan: repo ini semula dikerjakan satu orang, sekarang proyek kelompok, sehingga `AGENTS.md`, `CLAUDE.md`, `docs/CONTEXT.md`, `docs/PLAN.md`, `docs/PROGRESS.md`, `docs/PENGEMBANGAN-UI.md`, dan `docs/referensi/` semuanya ter-track. Kalau ada yang menyarankan meng-ignore-nya lagi, tanyakan dulu ke pemilik repo.
- `.gitignore` di root hanya berisi artefak lokal (log, `.idea/`, `.DS_Store`, dan sejenisnya). Folder `stockish/` dan `stockisi/` punya `.gitignore` Flutter masing-masing.
- `docs/HANDOFF.md` ditulis di Tahap 6, ditujukan untuk anggota kelompok yang meneruskan layer data.
- `docs/referensi/arsip/` berisi dokumen lama yang **tidak normatif**. Jangan pakai isinya sebagai acuan; rujukannya tetap `docs/CONTEXT.md`.

## Kapan memutuskan sendiri, kapan bertanya

Ukurannya satu: apakah pilihan itu mengubah perjalanan operator dari awal sampai akhir (`docs/CONTEXT.md` bagian 7), aturan bisnis (bagian 6), atau cakupan (bagian 4).

- **Putuskan sendiri** kalau tidak mengubah ketiganya. Contohnya format atau pemisah data, penamaan, struktur file, pilihan widget, detail visual, teks pesan, isi data dummy, placeholder aset yang belum ada, dan cara menguji di lingkungan yang tersedia. Pilih yang paling sederhana dan konsisten dengan dokumen, catat satu baris di bagian "Keputusan teknis" `docs/PROGRESS.md`, lalu lanjut tanpa bertanya.
- **Tanyakan** hanya kalau:
  - pilihannya mengubah alur, aturan bisnis, atau cakupan
  - ada cabang alur yang buntu dan dokumen tidak memberi jalan keluar
  - butuh sesuatu yang hanya pemilik repo yang punya, misalnya akun, kredensial, atau file aset
- Setiap pertanyaan disertai usulan jawaban dan dampaknya ke alur. Pekerjaan lain yang tidak bergantung pada jawaban itu tetap dikerjakan.
- Fakta yang bisa dipastikan sendiri (versi tool, isi repo, perilaku kode lama, API package) dipastikan sendiri, bukan ditanyakan.
- Yang tetap tidak boleh adalah mengarang fakta tentang kode, lingkungan, atau isi dokumen. Data dummy di repository tiruan boleh dikarang, asalkan konkret dan realistis untuk gudang manufaktur di Indonesia.

## Bukti sebelum klaim selesai

Sebuah tahap baru boleh disebut selesai kalau syarat berikut terpenuhi:

- `flutter analyze` bersih dari error. Warning yang tersisa dicatat beserta alasannya.
- `flutter test` lulus.
- App benar-benar dijalankan, dan alur pada tahap itu sudah ditelusuri, termasuk cabang gagalnya. Kalau app tidak bisa dijalankan di lingkungan ini, katakan terus terang dan sebutkan apa yang belum diverifikasi.
- Setiap butir "Selesai kalau" di `docs/PLAN.md` dicek satu per satu.

## Catatan kemajuan

Perbarui `docs/PROGRESS.md` setiap kali sebuah tahap selesai, dan juga sebelum sesi berakhir. Isinya:

- tahap yang sedang atau sudah dikerjakan
- keputusan teknis beserta alasannya, ditulis singkat
- bagian kode lama yang dipakai ulang atau diadaptasi, beserta file asalnya
- pertanyaan terbuka untuk pemilik repo
- hal yang perlu diketahui anggota kelompok yang nanti mengerjakan layer data

Catatan ini dipakai sebagai ingatan antarsesi, jadi tulis faktanya saja, jangan narasi.

## Konvensi kode

- Struktur folder `stockisi/lib/` mengikuti pola yang dipakai matkul: kode layar di `lib/screens/`, dan layanan di `lib/services/`. Folder lain boleh ditambah sesuai kebutuhan, misalnya `lib/data/`, `lib/theme/`, atau `lib/widgets/`.
- State management memakai `provider`, sama dengan kode lama, supaya bagian yang diadaptasi tidak perlu ditulis ulang polanya.
- Semua teks yang tampil ke pengguna ditulis dalam Bahasa Indonesia.
- Warna, ukuran, dan gaya teks diambil dari satu sumber tema. Jangan menulis kode warna langsung di dalam layar.
- Jangan menambah package baru kecuali benar-benar perlu. Setiap package baru dicatat alasannya di `docs/PROGRESS.md`.
