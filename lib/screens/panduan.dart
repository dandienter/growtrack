import 'package:flutter/material.dart';

import '../widgets.dart';

/// Panduan penggunaan GrowTrack untuk kader: langkah demi langkah
/// tiap fitur, dari menyiapkan data sampai mencetak laporan.
class PanduanKaderScreen extends StatelessWidget {
  const PanduanKaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panduan Penggunaan')),
      backgroundColor: kLatar,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: const [
          _KartuSambutan(),
          SizedBox(height: 14),
          _BagianPanduan(
            ikon: Icons.login,
            judul: '1. Memulai',
            langkah: [
              'Masuk dengan nama pengguna dan kata sandi yang diberikan admin.',
              'Peran akun terbaca otomatis setelah masuk, tidak perlu memilih peran.',
              'Beranda menampilkan ringkasan: jumlah balita, pemeriksaan bulan ini, dan anak yang perlu perhatian khusus.',
              'Ketuk nama anak pada Perhatian Khusus untuk membuka detail dan kurva pertumbuhannya.',
            ],
          ),
          _BagianPanduan(
            ikon: Icons.family_restroom,
            judul: '2. Data Orang Tua dan Balita',
            langkah: [
              'Buka tab Data Utama, pilih Orang Tua, ketuk tombol tambah, isi nama ayah, nama ibu, pekerjaan, nomor HP, dan alamat.',
              'Setelah orang tua tersimpan, pilih Balita, ketuk tombol tambah, isi nama anak, jenis kelamin, tanggal lahir, berat dan tinggi lahir, lalu pilih orang tuanya.',
              'Untuk data banyak sekaligus, pakai Impor: Pengaturan, Kelola Database, Impor Data. Siapkan berkas Excel (XLSX) atau CSV mengikuti contoh format di halaman impor.',
              'Urutan impor: impor orang tua dulu, baru balita, supaya anak bisa dikaitkan ke ibunya.',
            ],
          ),
          _BagianPanduan(
            ikon: Icons.monitor_weight,
            judul: '3. Pemeriksaan Rutin',
            langkah: [
              'Buka tab Pelayanan, pilih Pemeriksaan, ketuk tombol tambah.',
              'Pilih anak, isi tanggal periksa, berat badan (kg) dan tinggi badan (cm).',
              'Status gizi dan nilai Z-Score dihitung otomatis mengikuti standar WHO begitu disimpan.',
              'Buka detail anak untuk melihat penilaian lengkap dan kurva pertumbuhan BB/U dan TB/U.',
            ],
          ),
          _BagianPanduan(
            ikon: Icons.vaccines,
            judul: '4. Imunisasi',
            langkah: [
              'Buka tab Pelayanan, pilih Jadwal Imunisasi untuk melihat jadwal per anak.',
              'Setelah anak diimunisasi, buka jadwalnya dan ubah status menjadi Selesai, tanggal pemberian terisi otomatis.',
              'Buka Cakupan Imunisasi di tab Pelayanan untuk melihat persentase anak yang sudah menerima tiap vaksin.',
            ],
          ),
          _BagianPanduan(
            ikon: Icons.restaurant,
            judul: '5. Konsumsi dan PMT',
            langkah: [
              'Buka tab Pelayanan, pilih Konsumsi, ketuk tombol tambah.',
              'Pilih anak, tanggal, dan jenis konsumsi atau PMT yang diberikan.',
              'Riwayat konsumsi per anak bisa dilihat kembali dari daftar konsumsi dengan mencari nama anak.',
            ],
          ),
          _BagianPanduan(
            ikon: Icons.warning_amber,
            judul: '6. Pantauan Risiko',
            langkah: [
              'Buka tab Pelayanan, pilih Pantauan Risiko. Anak otomatis dikelompokkan: Tinggi, Sedang, Rendah.',
              'Tinggi artinya perlu tindak lanjut segera, misalnya status gizi buruk atau berat badan tidak naik dua kali berturut-turut.',
              'Ketuk anak untuk membuka detailnya, lalu hubungi orang tua lewat tombol WhatsApp di halaman anak tersebut.',
            ],
          ),
          _BagianPanduan(
            ikon: Icons.picture_as_pdf,
            judul: '7. Laporan dan PDF',
            langkah: [
              'Buka tab Laporan, pilih jenis laporan: data balita, riwayat pemeriksaan, imunisasi, konsumsi PMT, atau perkembangan per balita.',
              'Atur rentang tanggal bila perlu, lalu ketuk Buat Laporan untuk melihat pratinjau PDF.',
              'Dari pratinjau, laporan bisa dibagikan atau dicetak.',
              'Laporan satu anak juga bisa diunduh dari halaman detail anak lewat tombol Unduh Laporan. Orang tua pun bisa mengunduh laporan anaknya sendiri dari akun mereka.',
            ],
          ),
          _BagianPanduan(
            ikon: Icons.campaign,
            judul: '8. Konten dan Pengumuman (Admin)',
            langkah: [
              'Buka tab Pengaturan, pilih Konten dan Pengumuman, ketuk tombol tambah.',
              'Pilih jenisnya: Edukasi untuk materi bacaan orang tua, atau Pengumuman untuk kabar posyandu.',
              'Isi judul, ringkasan, dan isi lengkap, lalu simpan. Konten langsung tersinkron dan tampil di beranda orang tua.',
            ],
          ),
          _BagianPanduan(
            ikon: Icons.manage_accounts,
            judul: '9. Akun Orang Tua (Admin)',
            langkah: [
              'Buka tab Pengaturan, pilih Pengaturan Akun dan Sistem, lalu Kelola Pengguna.',
              'Buat akun dengan peran Orang Tua dan kaitkan ke satu data orang tua.',
              'Serahkan nama pengguna dan kata sandi ke orang tua tersebut. Mereka hanya bisa melihat data anaknya sendiri.',
            ],
          ),
          _BagianPanduan(
            ikon: Icons.cloud_sync,
            judul: '10. Sinkronisasi Awan',
            langkah: [
              'Semua data tersimpan dulu di HP dan tetap bisa dipakai tanpa internet.',
              'Saat HP terhubung internet, data tersinkron otomatis ke awan dan ke perangkat kader lain.',
              'Untuk menyinkronkan saat itu juga, buka Pengaturan, Kelola Database, ketuk Sinkronkan Sekarang.',
            ],
          ),
          _BagianPanduan(
            ikon: Icons.backup,
            judul: '11. Cadangan dan Pemulihan',
            langkah: [
              'Buka Pengaturan, Kelola Database, ketuk Cadangkan Database dan simpan berkasnya di tempat aman.',
              'Lakukan pencadangan secara berkala, misalnya setiap selesai posyandu.',
              'Bila ganti HP, pasang GrowTrack di HP baru lalu ketuk Pulihkan Database dan pilih berkas cadangan.',
            ],
          ),
          _BagianPanduan(
            ikon: Icons.system_update,
            judul: '12. Pembaruan Aplikasi',
            langkah: [
              'Bila ada versi baru, aplikasi menawarkan pembaruan otomatis saat dibuka.',
              'Ketuk Perbarui, unduh berkasnya, lalu pasang menimpa versi lama. Data tidak hilang.',
              'Cek manual juga bisa dari Pengaturan, Info Aplikasi, tombol Cek Pembaruan.',
            ],
          ),
        ],
      ),
    );
  }
}

class _KartuSambutan extends StatelessWidget {
  const _KartuSambutan();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kTeal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Panduan Kader GrowTrack',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Ikuti langkah-langkah di tiap bagian sesuai urutan kerjanya: '
            'siapkan data, catat pemeriksaan, pantau risiko, lalu buat '
            'laporan. Semua data tetap tersimpan di HP dan tersinkron '
            'saat ada internet.',
            style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _BagianPanduan extends StatelessWidget {
  final IconData ikon;
  final String judul;
  final List<String> langkah;

  const _BagianPanduan({
    required this.ikon,
    required this.judul,
    required this.langkah,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF2E4),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(ikon, color: kTeal, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    judul,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: kTinta,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < langkah.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == langkah.length - 1 ? 0 : 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: kTeal,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        langkah[i],
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
