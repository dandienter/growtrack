# GrowTrack (Flutter)

GrowTrack - Sistem Informasi Monitoring Tumbuh Kembang Anak Terpadu.
Konversi aplikasi desktop Java Swing GrowTrack (KKP Teknik Informatika UNINDRA, Posyandu Beringin DDN) menjadi aplikasi Android asli dengan Flutter. Bukan WebView.

## Fitur

- Login 2 peran: Admin dan Petugas, password SHA-256 + salt per pengguna (kompatibel akun desktop, upgrade salt otomatis)
- Data balita, data orang tua, pemeriksaan, imunisasi (master vaksin + jadwal), konsumsi dan PMT
- Status gizi WHO Child Growth Standards 2006 metode LMS (Z-Score BB/U, TB/U, BB/TB) dan klasifikasi Kemenkes sesuai PMK No. 2 Tahun 2020, termasuk koreksi tinggi 0,7 cm dan detektor data anomali
- Laporan PDF dengan kop surat posyandu: data balita, riwayat pemeriksaan, jadwal dan pelaksanaan imunisasi, konsumsi PMT, dan perkembangan per balita
- Database lokal offline SQLite (db_growtrack.db), skema dan data awal sama dengan edisi desktop
- Kelola database di dalam aplikasi, backup dan restore berkas database
- Pengaturan identitas posyandu dan manajemen akun pengguna

Akun awal sama dengan desktop: admin / admin123 dan bidan / admin123 (data contoh, ganti setelah login pertama).

## Struktur

- lib/db - skema SQLite, data awal, CRUD, backup/restore
- lib/logic - mesin status gizi WHO LMS (gizi.dart, tabel di lib/data/who_lms.dart) dan keamanan password
- lib/screens - layar aplikasi
- tools/generate_icons.py - menggambar ikon aplikasi (logo master, set mipmap Android, logo dalam aplikasi) dari kode; dijalankan otomatis oleh workflow build

## Build

APK dibangun oleh GitHub Actions (.github/workflows/build-apk.yml): rangka platform Android dibuat dari Flutter, ikon digambar dari skrip, lalu flutter build apk --release untuk arm64. Hasil tersedia sebagai artefak dan Release build-N.
