import 'package:flutter/material.dart';

import '../db/database.dart';
import '../format.dart';
import '../kurva_who.dart';
import '../logic/gizi.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';
import 'laporan.dart';
import 'laporan_pdf.dart';
import 'pemeriksaan.dart';

/// Satu indikator antropometri pada kartu detail: nilai aktual, median
/// WHO, Z-Score, kategori, batas klasifikasi, dan interpretasi singkat.
class _Indikator {
  final String nama;
  final String nilaiAktual;
  final String median;
  final double z;
  final String kategori;
  final String batas;
  final String interpretasi;

  const _Indikator({
    required this.nama,
    required this.nilaiAktual,
    required this.median,
    required this.z,
    required this.kategori,
    required this.batas,
    required this.interpretasi,
  });
}

/// Hasil hitung ulang satu baris pemeriksaan (Z-Score disimpan di DB
/// untuk BB/U, TB/U, BB/TB; LK/U selalu dihitung on-the-fly di sini).
class _HitungBaris {
  final Pemeriksaan periksa;
  final int umur;
  final HasilGizi hasil;

  const _HitungBaris(this.periksa, this.umur, this.hasil);
}

/// Layar "Detail Hasil Antropometri": ringkasan status gizi terakhir,
/// kartu 4 indikator (BB/U, TB/U, BB/TB, LK/U), grafik tren WHO,
/// tabel riwayat, rekomendasi singkat, dan unduh PDF per anak.
/// Dipakai bersama oleh petugas (dari daftar Pemeriksaan) dan orang tua
/// (dari beranda orang tua).
class DetailAntropometriScreen extends StatefulWidget {
  final Balita balita;

  /// Pembangun layar detail anak lengkap (imunisasi dsb.) untuk peran
  /// orang tua; diisi oleh beranda orang tua agar tidak ada impor
  /// melingkar antarlayar. Null untuk petugas.
  final Widget Function()? pembangunDetailLengkap;

  const DetailAntropometriScreen({
    super.key,
    required this.balita,
    this.pembangunDetailLengkap,
  });

  @override
  State<DetailAntropometriScreen> createState() =>
      _DetailAntropometriState();
}

class _DetailAntropometriState extends State<DetailAntropometriScreen> {
  List<_HitungBaris> _baris = [];
  bool _memuat = true;

  Balita get _b => widget.balita;
  bool get _laki => isLaki(_b.jenisKelamin);

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final daftar =
          await GrowTrackDB.ambilPemeriksaan(idBalita: _b.idBalita);
      final lahir = parseTanggalDb(_b.tglLahir);
      final hasil = <_HitungBaris>[];
      if (lahir != null) {
        for (final p in daftar) {
          final tgl = parseTanggalDb(p.tanggal);
          if (tgl == null) continue;
          final umur = hitungUmurBulan(lahir, tgl);
          final koreksi =
              koreksiTinggi(p.tinggiBadan, umur, p.posisiUkur ?? 'Berdiri');
          hasil.add(_HitungBaris(
            p,
            umur,
            hitungStatusGiziDetail(
              p.beratBadan,
              koreksi.tinggiKoreksi,
              umur,
              _b.jenisKelamin,
              lingkarKepala: p.lingkarKepala,
            ),
          ));
        }
      }
      if (!mounted) return;
      setState(() {
        _baris = hasil;
        _memuat = false;
      });
    } catch (_) {
      if (mounted) setState(() => _memuat = false);
    }
  }

  _HitungBaris? get _terakhir => _baris.isEmpty ? null : _baris.first;

  List<_Indikator> _indikatorTerakhir(_HitungBaris hb) {
    final p = hb.periksa;
    final h = hb.hasil;
    final umur = hb.umur.toDouble();
    String dua(double v, String satuan) =>
        '${v.toStringAsFixed(1).replaceAll('.', ',')} $satuan';
    if (umur > 60) {
      // Jalur WHO 2007: median tidak ditampilkan (tabel acuan berbeda),
      // nilai aktual + Z-Score + kategori tetap dari mesin yang sama.
      return [
        _Indikator(
          nama: 'TB/U - Tinggi menurut Umur',
          nilaiAktual: dua(p.tinggiBadan, 'cm'),
          median: '-',
          z: h.zTBU,
          kategori: h.statusTBU,
          batas: '< -3 Sangat Pendek • -3 s.d. <-2 Pendek • '
              '-2 s.d. +3 Normal • > +3 Tinggi',
          interpretasi: _interpretasiTBU(h.statusTBU),
        ),
        _Indikator(
          nama: 'IMT/U - IMT menurut Umur',
          nilaiAktual: imt(p.beratBadan, p.tinggiBadan).isNaN
              ? '-'
              : imt(p.beratBadan, p.tinggiBadan).toStringAsFixed(1),
          median: '-',
          z: h.zIMTU,
          kategori: h.statusIMTU,
          batas: '< -3 Gizi Buruk • -3 s.d. <-2 Gizi Kurang • '
              '-2 s.d. +1 Gizi Baik • +1 s.d. +2 Gizi Lebih • > +2 Obesitas',
          interpretasi: _interpretasiBBTB(h.statusIMTU),
        ),
        _Indikator(
          nama: 'LK/U - Lingkar Kepala menurut Umur',
          nilaiAktual: '-',
          median: '-',
          z: double.nan,
          kategori: '-',
          batas: 'Hanya sampai usia 60 bulan',
          interpretasi: 'LK/U tidak dinilai untuk usia di atas 5 tahun.',
        ),
      ];
    }
    final koreksi =
        koreksiTinggi(p.tinggiBadan, hb.umur, p.posisiUkur ?? 'Berdiri');
    final tbK = koreksi.tinggiKoreksi;
    return [
      _Indikator(
        nama: 'BB/U - Berat menurut Umur',
        nilaiAktual: dua(p.beratBadan, 'kg'),
        median: dua(medianBBU(umur, _laki), 'kg'),
        z: h.zBBU,
        kategori: h.statusBBU,
        batas: '< -3 Sangat Kurang • -3 s.d. <-2 Kurang • '
            '-2 s.d. +1 Normal • > +1 Risiko Lebih',
        interpretasi: _interpretasiBBU(h.statusBBU),
      ),
      _Indikator(
        nama: 'TB/U - Tinggi menurut Umur',
        nilaiAktual: dua(tbK, 'cm'),
        median: dua(medianTBU(umur, _laki), 'cm'),
        z: h.zTBU,
        kategori: h.statusTBU,
        batas: '< -3 Sangat Pendek • -3 s.d. <-2 Pendek • '
            '-2 s.d. +3 Normal • > +3 Tinggi',
        interpretasi: _interpretasiTBU(h.statusTBU),
      ),
      _Indikator(
        nama: 'BB/TB - Berat menurut Tinggi',
        nilaiAktual: dua(p.beratBadan, 'kg'),
        median: dua(medianBBTB(tbK, umur, _laki), 'kg'),
        z: h.zBBTB,
        kategori: h.statusBBTB,
        batas: '< -3 Gizi Buruk • -3 s.d. <-2 Gizi Kurang • '
            '-2 s.d. +1 Gizi Baik • +1 s.d. +2 Risiko Lebih • '
            '+2 s.d. +3 Gizi Lebih • > +3 Obesitas',
        interpretasi: _interpretasiBBTB(h.statusBBTB),
      ),
      _Indikator(
        nama: 'LK/U - Lingkar Kepala menurut Umur',
        nilaiAktual: p.lingkarKepala > 0 ? dua(p.lingkarKepala, 'cm') : '-',
        median: medianLKU(umur, _laki).isNaN
            ? '-'
            : dua(medianLKU(umur, _laki), 'cm'),
        z: h.zLKU,
        kategori: h.statusLKU,
        batas: '< -2 Di Bawah Normal • -2 s.d. +2 Normal • '
            '> +2 Di Atas Normal',
        interpretasi: _interpretasiLKU(h.statusLKU),
      ),
    ];
  }

  String _interpretasiBBU(String k) {
    if (k.contains('Sangat Kurang')) {
      return 'Berat badan sangat kurang untuk umurnya; perlu perhatian segera.';
    }
    if (k.contains('Kurang')) {
      return 'Berat badan kurang untuk umurnya; pantau kenaikan tiap bulan.';
    }
    if (k.contains('Risiko')) {
      return 'Berat badan cenderung lebih untuk umurnya; jaga pola makan.';
    }
    if (k == '-') return 'Belum dapat dinilai.';
    return 'Berat badan sesuai dengan umur anak.';
  }

  String _interpretasiTBU(String k) {
    if (k.contains('Sangat Pendek')) {
      return 'Tinggi sangat pendek untuk umurnya (indikasi stunting berat).';
    }
    if (k.contains('Pendek')) {
      return 'Tinggi pendek untuk umurnya (indikasi stunting).';
    }
    if (k.contains('Tinggi')) return 'Tinggi badan di atas rata-rata umurnya.';
    if (k == '-') return 'Belum dapat dinilai.';
    return 'Tinggi badan sesuai dengan umur anak.';
  }

  String _interpretasiBBTB(String k) {
    if (k.contains('Buruk')) {
      return 'Berat sangat kurang dibanding tingginya (gizi buruk).';
    }
    if (k.contains('Kurang')) {
      return 'Berat kurang dibanding tingginya (gizi kurang).';
    }
    if (k.contains('Obesitas')) {
      return 'Berat jauh melebihi tinggi badannya (obesitas).';
    }
    if (k.contains('Lebih')) {
      return 'Berat cenderung lebih dibanding tingginya; jaga pola makan.';
    }
    if (k == '-') return 'Belum dapat dinilai.';
    return 'Berat badan proporsional dengan tinggi badan anak.';
  }

  String _interpretasiLKU(String k) {
    if (k.contains('Bawah')) {
      return 'Lingkar kepala di bawah rentang normal; konsultasikan ke bidan.';
    }
    if (k.contains('Atas')) {
      return 'Lingkar kepala di atas rentang normal; konsultasikan ke bidan.';
    }
    if (k == '-') return 'Lingkar kepala tidak diukur pada pemeriksaan ini.';
    return 'Lingkar kepala dalam rentang normal untuk umurnya.';
  }

  List<String> _rekomendasi(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.contains('buruk')) {
      return const [
        'Segera rujuk ke Puskesmas untuk penanganan gizi buruk.',
        'Beri PMT pemulihan sesuai anjuran petugas dan pantau tiap minggu.',
      ];
    }
    if (s.contains('kurang') || s.contains('stunting') || s.contains('pendek')) {
      return const [
        'Tingkatkan asupan protein hewani dan beri PMT sesuai jadwal.',
        'Pantau berat dan tinggi badan setiap bulan di Posyandu.',
        'Konsultasikan ke bidan bila tidak ada perbaikan dalam 2 bulan.',
      ];
    }
    if (s.contains('lebih') || s.contains('obesitas')) {
      return const [
        'Jaga pola makan bergizi seimbang, batasi gula dan makanan olahan.',
        'Pantau berat badan setiap bulan di Posyandu.',
      ];
    }
    if (s.contains('anomali')) {
      return const [
        'Periksa kembali hasil ukur (berat, tinggi, tanggal lahir) lalu ukur ulang.',
      ];
    }
    return const [
      'Pertahankan pola makan bergizi seimbang dan protein hewani harian.',
      'Lanjutkan penimbangan rutin setiap bulan di Posyandu.',
      'Lengkapi imunisasi sesuai jadwal anak.',
    ];
  }

  List<TitikKurva> _titik(int jenis) {
    // jenis: 0 = BB, 1 = TB, 2 = LK
    final lahir = parseTanggalDb(_b.tglLahir);
    if (lahir == null) return const [];
    final hasil = <TitikKurva>[];
    for (final hb in _baris) {
      final tgl = parseTanggalDb(hb.periksa.tanggal);
      if (tgl == null) continue;
      final bulan = tgl.difference(lahir).inDays / 30.4375;
      if (bulan < 0) continue;
      final nilai = jenis == 0
          ? hb.periksa.beratBadan
          : jenis == 1
              ? hb.periksa.tinggiBadan
              : hb.periksa.lingkarKepala;
      if (jenis == 2 && nilai <= 0) continue;
      hasil.add(TitikKurva(bulan, nilai));
    }
    return hasil;
  }

  Future<void> _unduhPdf() async {
    try {
      final bytes = await LaporanPdf.buat(ParameterLaporan(
        jenis: 'Laporan Perkembangan per Balita',
        balita: _b,
      ));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PratinjauLaporanScreen(
            judul: 'Laporan ${_b.namaBalita}',
            namaBerkas:
                'Laporan_${_b.namaBalita.replaceAll(' ', '_')}.pdf',
            bytes: bytes,
          ),
        ),
      );
    } catch (e) {
      if (mounted) tampilSnack(context, 'Gagal membuat PDF: $e');
    }
  }

  Future<void> _ubah(Pemeriksaan p) async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PemeriksaanFormScreen(pemeriksaan: p)),
    );
    if (simpan == true) _muat();
  }

  @override
  Widget build(BuildContext context) {
    final terakhir = _terakhir;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Hasil Antropometri')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : KontenLebar(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _kartuAnak(terakhir),
                  if (terakhir == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: TampilanKosong(
                          pesan: 'Belum ada data pemeriksaan untuk anak ini.'),
                    )
                  else ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Indikator Pemeriksaan Terakhir',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatTanggalID(terakhir.periksa.tanggal)} • '
                      'Umur ${terakhir.umur} bulan • '
                      'Standar WHO & Permenkes No. 2 Tahun 2020',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    for (final ind in _indikatorTerakhir(terakhir))
                      _kartuIndikator(ind),
                    const SizedBox(height: 8),
                    const Text(
                      'Grafik Tren Pertumbuhan (WHO)',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    _kartuKurva(
                      'Berat Badan menurut Umur (BB/U)',
                      KurvaPertumbuhan(
                        jenisKelamin: _b.jenisKelamin,
                        berat: true,
                        titik: _titik(0),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _kartuKurva(
                      'Tinggi Badan menurut Umur (TB/U)',
                      KurvaPertumbuhan(
                        jenisKelamin: _b.jenisKelamin,
                        berat: false,
                        titik: _titik(1),
                      ),
                    ),
                    if (_titik(2).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _kartuKurva(
                        'Lingkar Kepala menurut Umur (LK/U)',
                        KurvaPertumbuhan(
                          jenisKelamin: _b.jenisKelamin,
                          berat: false,
                          lingkarKepala: true,
                          titik: _titik(2),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Riwayat Pemeriksaan',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    _tabelRiwayat(),
                    const SizedBox(height: 16),
                    const Text(
                      'Rekomendasi',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    _kartuRekomendasi(terakhir),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _unduhPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Unduh Laporan PDF per Anak'),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(14)),
                    ),
                    if (widget.pembangunDetailLengkap != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  widget.pembangunDetailLengkap!()),
                        ),
                        icon: const Icon(Icons.vaccines_outlined),
                        label: const Text('Detail Anak & Imunisasi'),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(14)),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _kartuAnak(_HitungBaris? terakhir) {
    final b = _b;
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarKarakter.anak(
                  nama: b.namaBalita,
                  jenisKelamin: b.jenisKelamin,
                  tglLahir: parseTanggalDb(b.tglLahir),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.namaBalita,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${b.jenisKelaminLengkap} • Lahir ${formatTanggalID(b.tglLahir)}',
                        style: const TextStyle(
                            fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (terakhir != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Status Gizi Terakhir: ',
                      style: TextStyle(color: Color(0xFF64748B))),
                  ChipStatus(
                    teks: terakhir.periksa.statusGizi ??
                        terakhir.hasil.statusUtama,
                    warna: warnaStatusGizi(terakhir.periksa.statusGizi ??
                        terakhir.hasil.statusUtama),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kartuIndikator(_Indikator ind) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ind.nama,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
                ChipStatus(teks: ind.kategori, warna: _warnaKategori(ind)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _selNilai('Nilai Aktual', ind.nilaiAktual),
                _selNilai('Median WHO', ind.median),
                _selNilai('Z-Score', fmtZ(ind.z)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Batas: ${ind.batas}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 4),
            Text(
              ind.interpretasi,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selNilai(String label, String nilai) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
          Text(nilai,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _warnaKategori(_Indikator ind) {
    final k = ind.kategori.toLowerCase();
    if (k == '-' || k.isEmpty) return const Color(0xFF64748B);
    if (k.contains('normal') || k.contains('baik')) {
      return const Color(0xFF1E7A46);
    }
    if (k.contains('buruk') || k.contains('sangat')) {
      return const Color(0xFFC0392B);
    }
    return const Color(0xFF9A6B14);
  }

  Widget _kartuKurva(String judul, Widget kurva) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13.5)),
            const SizedBox(height: 8),
            kurva,
          ],
        ),
      ),
    );
  }

  Widget _tabelRiwayat() {
    final staf = !SesiUser.isOrangTua;
    TextStyle gayaKepala = const TextStyle(
        fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B));
    String z(double v) => fmtZ(v);
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columns: [
            DataColumn(label: Text('Tanggal', style: gayaKepala)),
            DataColumn(label: Text('BB', style: gayaKepala)),
            DataColumn(label: Text('TB', style: gayaKepala)),
            DataColumn(label: Text('LK', style: gayaKepala)),
            DataColumn(label: Text('Z BB/U', style: gayaKepala)),
            DataColumn(label: Text('Z TB/U', style: gayaKepala)),
            DataColumn(label: Text('Z BB/TB', style: gayaKepala)),
            DataColumn(label: Text('Z LK/U', style: gayaKepala)),
            if (staf) DataColumn(label: Text('', style: gayaKepala)),
          ],
          rows: [
            for (final hb in _baris)
              DataRow(cells: [
                DataCell(Text(formatTanggalID(hb.periksa.tanggal))),
                DataCell(Text(hb.periksa.beratBadan.toString())),
                DataCell(Text(hb.periksa.tinggiBadan.toString())),
                DataCell(Text(hb.periksa.lingkarKepala > 0
                    ? hb.periksa.lingkarKepala.toString()
                    : '-')),
                DataCell(Text(z(hb.hasil.zBBU))),
                DataCell(Text(z(hb.hasil.zTBU))),
                DataCell(Text(z(hb.hasil.zBBTB))),
                DataCell(Text(z(hb.hasil.zLKU))),
                if (staf)
                  DataCell(IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    tooltip: 'Ubah pemeriksaan',
                    onPressed: () => _ubah(hb.periksa),
                  )),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _kartuRekomendasi(_HitungBaris terakhir) {
    final poin = _rekomendasi(
        terakhir.periksa.statusGizi ?? terakhir.hasil.statusUtama);
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in poin)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(color: Color(0xFF475569))),
                    Expanded(
                      child: Text(p,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF475569))),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            const Text(
              'Hasil ini adalah pemantauan pertumbuhan, bukan diagnosis medis.',
              style: TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
