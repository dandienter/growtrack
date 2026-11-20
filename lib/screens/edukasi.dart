import 'package:flutter/material.dart';

import '../widgets.dart';

/// Artikel edukasi offline untuk orang tua. Isi ringkas dan umum,
/// bukan pengganti nasihat dokter/bidan.
class ArtikelEdukasi {
  final String judul;
  final String ringkas;
  final IconData ikon;
  final Color warna;
  final List<String> isi;

  const ArtikelEdukasi({
    required this.judul,
    required this.ringkas,
    required this.ikon,
    required this.warna,
    required this.isi,
  });
}

const daftarArtikelEdukasi = <ArtikelEdukasi>[
  ArtikelEdukasi(
    judul: 'Mengenal Stunting dan Cara Mencegahnya',
    ringkas: 'Anak pendek karena kurang gizi kronis: tanda dan pencegahannya.',
    ikon: Icons.height,
    warna: Color(0xFFEF4444),
    isi: [
      'Stunting adalah kondisi anak lebih pendek dari standar usianya karena kekurangan gizi dalam waktu lama, terutama pada 1.000 hari pertama kehidupan (sejak hamil sampai anak berusia 2 tahun). Stunting bukan sekadar pendek: perkembangan otak ikut terhambat sehingga anak berisiko sulit belajar dan mudah sakit.',
      'Penyebab utamanya adalah asupan gizi yang kurang atau tidak beragam, infeksi berulang seperti diare, dan pola asuh makan yang kurang tepat. Anak yang berat badannya tidak naik selama 2 bulan berturut-turut perlu segera diperhatikan.',
      'Pencegahan dimulai sejak ibu hamil: makan bergizi seimbang, minum tablet tambah darah, dan periksa kehamilan rutin. Setelah lahir, berikan ASI eksklusif 6 bulan, lalu MP-ASI bergizi dengan protein hewani (telur, ikan, ayam, daging) setiap hari.',
      'Pantau pertumbuhan anak setiap bulan di Posyandu. Bila garis pertumbuhan di buku KIA mendatar atau menurun, atau anak tampak jauh lebih pendek dari teman seusianya, konsultasikan ke bidan atau Puskesmas agar ditangani sejak dini.',
    ],
  ),
  ArtikelEdukasi(
    judul: 'MP-ASI Tepat untuk Anak 6-24 Bulan',
    ringkas: 'Tekstur, frekuensi, dan contoh menu sesuai tahap usia anak.',
    ikon: Icons.restaurant,
    warna: Color(0xFFF59E0B),
    isi: [
      'Mulai usia 6 bulan, ASI saja tidak lagi cukup sehingga anak perlu Makanan Pendamping ASI (MP-ASI). Tetap lanjutkan menyusui sampai anak berusia 2 tahun atau lebih.',
      'Usia 6-8 bulan: MP-ASI lumat kental (bubur saring), 2-3 kali makan utama plus 1-2 kali selingan. Usia 9-11 bulan: makanan cincang atau lembek, 3-4 kali makan utama plus 1-2 selingan. Usia 12-24 bulan: makanan keluarga yang dipotong kecil, 3-4 kali makan utama plus 1-2 selingan.',
      'Setiap porsi usahakan lengkap: makanan pokok (nasi, kentang, ubi), protein hewani (telur, ikan, ayam, hati, daging), sayur dan buah, serta sedikit lemak sehat seperti santan atau minyak. Protein hewani setiap hari penting untuk mencegah stunting.',
      'Biasakan responsive feeding: beri makan dengan sabar, tanpa memaksa, dan tanpa gawai atau televisi. Cuci tangan dengan sabun sebelum menyiapkan dan menyuapi makanan, dan gunakan bahan segar yang dimasak matang.',
    ],
  ),
  ArtikelEdukasi(
    judul: 'Jadwal Imunisasi Dasar Lengkap',
    ringkas: 'Imunisasi wajib dari lahir sampai usia 2 tahun agar tidak terlewat.',
    ikon: Icons.vaccines,
    warna: Color(0xFF3B82F6),
    isi: [
      'Imunisasi melindungi anak dari penyakit berbahaya seperti hepatitis B, polio, campak, difteri, dan tuberkulosis. Semua imunisasi dasar di Posyandu dan Puskesmas diberikan gratis.',
      'Jadwalnya: lahir (0-7 hari) Hepatitis B; usia 1 bulan BCG dan Polio 1; usia 2 bulan DPT-HB-Hib 1 dan Polio 2; usia 3 bulan DPT-HB-Hib 2 dan Polio 3; usia 4 bulan DPT-HB-Hib 3 dan Polio 4; usia 9 bulan Campak; usia 18 bulan DPT-HB-Hib lanjutan; usia 24 bulan Campak lanjutan.',
      'Bila jadwal terlewat, jangan mengulang dari awal. Datang saja ke Posyandu atau Puskesmas dengan membawa buku KIA, imunisasi akan dilanjutkan sesuai catatan (imunisasi kejar).',
      'Sesudah imunisasi, anak bisa demam ringan atau rewel 1-2 hari; ini reaksi yang wajar. Kompres hangat bekas suntikan dan beri ASI/air lebih sering. Bila demam tinggi lebih dari 2 hari atau anak tampak sangat lemah, segera bawa ke fasilitas kesehatan.',
    ],
  ),
  ArtikelEdukasi(
    judul: 'Pentingnya Vitamin A untuk Balita',
    ringkas: 'Kapsul vitamin A tiap Februari dan Agustus: manfaat dan dosisnya.',
    ikon: Icons.medication,
    warna: Color(0xFF8B5CF6),
    isi: [
      'Vitamin A menjaga kesehatan mata, daya tahan tubuh, dan pertumbuhan anak. Kekurangan vitamin A membuat anak mudah terkena infeksi seperti campak dan diare, dan dalam kondisi berat dapat menyebabkan gangguan penglihatan.',
      'Pemerintah membagikan kapsul vitamin A gratis dua kali setahun, setiap bulan Februari dan Agustus, di Posyandu, Puskesmas, dan pos pelayanan lain.',
      'Dosisnya dibedakan menurut usia: kapsul biru (100.000 IU) untuk bayi 6-11 bulan, dan kapsul merah (200.000 IU) untuk anak 12-59 bulan. Cukup satu kapsul setiap kali pembagian.',
      'Catat tanggal pemberian vitamin A di buku KIA anak. Bila terlewat jadwal pembagian, tanyakan ke kader atau bidan kapan anak bisa mendapatkannya.',
    ],
  ),
  ArtikelEdukasi(
    judul: 'Memantau Tumbuh Kembang di Rumah',
    ringkas: 'Hal sederhana yang bisa dilakukan orang tua setiap hari di rumah.',
    ikon: Icons.home,
    warna: Color(0xFF10B981),
    isi: [
      'Tumbuh kembang anak dipantau dari dua hal: pertumbuhan fisik (berat, tinggi, lingkar kepala) dan perkembangan kemampuan (motorik, bicara, sosial). Keduanya tercatat di buku KIA setiap kali datang ke Posyandu.',
      'Di rumah, perhatikan nafsu makan anak, keaktifan bermain, dan pencapaian sesuai usia: misalnya usia 6 bulan mulai duduk, 9 bulan merangkak, 12 bulan berdiri atau berjalan ditopang, dan 18 bulan mulai mengucapkan kata bermakna.',
      'Stimulasi anak setiap hari lewat bermain, berbicara, bernyanyi, dan membacakan cerita. Batasi gawai dan televisi, terutama untuk anak di bawah 2 tahun.',
      'Segera bawa anak ke Posyandu atau Puskesmas bila berat badan tidak naik 2 bulan berturut-turut, anak tampak lesu dan tidak aktif, kehilangan kemampuan yang sudah dikuasai, atau belum bisa melakukan kemampuan dasar sesuai usianya.',
    ],
  ),
];

/// Seksi edukasi pada beranda orang tua: daftar artikel yang bisa
/// dibaca kapan pun tanpa internet.
class SeksiEdukasi extends StatelessWidget {
  const SeksiEdukasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Edukasi untuk Orang Tua',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        for (final a in daftarArtikelEdukasi)
          Card(
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: a.warna.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(a.ikon, color: a.warna, size: 22),
              ),
              title: Text(
                a.judul,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(a.ringkas, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BacaArtikelScreen(artikel: a)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Halaman baca satu artikel edukasi.
class BacaArtikelScreen extends StatelessWidget {
  final ArtikelEdukasi artikel;

  const BacaArtikelScreen({super.key, required this.artikel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edukasi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.centerLeft,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: artikel.warna.withOpacity(0.12),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(artikel.ikon, color: artikel.warna, size: 29),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            artikel.judul,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTinta,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          for (final p in artikel.isi) ...[
            Text(
              p,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.6,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          const Text(
            'Materi edukasi umum, bukan pengganti nasihat dokter atau bidan.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
