import 'package:flutter/material.dart';

import '../db/database.dart';
import '../format.dart';
import '../logic/gizi.dart';
import '../models.dart';
import '../widgets.dart';
import 'beranda_orang_tua.dart';

/// Tingkat risiko seorang anak hasil penilaian aturan sederhana.
class _Penilaian {
  final Balita balita;
  final int tingkat; // 2 tinggi, 1 sedang, 0 rendah
  final List<String> alasan;
  final Pemeriksaan? terakhir;

  const _Penilaian(this.balita, this.tingkat, this.alasan, this.terakhir);
}

/// Pantauan Risiko: peringatan dini berbasis aturan dari data
/// pemeriksaan terakhir tiap anak (status gizi, tren berat badan,
/// dan keterlambatan penimbangan).
class PantauanRisikoScreen extends StatefulWidget {
  const PantauanRisikoScreen({super.key});

  @override
  State<PantauanRisikoScreen> createState() => _PantauanRisikoScreenState();
}

class _PantauanRisikoScreenState extends State<PantauanRisikoScreen> {
  List<_Penilaian> _semua = [];
  bool _memuat = true;
  int _saring = -1; // -1 semua, 2 tinggi, 1 sedang, 0 rendah

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final balita = await GrowTrackDB.ambilBalita();
    final hasil = <_Penilaian>[];
    final kini = DateTime.now();
    for (final b in balita) {
      final periksa = await GrowTrackDB.ambilPemeriksaan(idBalita: b.idBalita);
      if (periksa.isEmpty) {
        hasil.add(_Penilaian(b, 1, const ['Belum pernah diperiksa'], null));
        continue;
      }
      final t = periksa.first;
      final status = t.statusGizi ?? '';
      var tingkat = 0;
      final alasan = <String>[];
      if (status.contains('Buruk') ||
          status.contains('Stunting') ||
          (t.zBbtb != null && t.zBbtb! < -3) ||
          (t.zTbu != null && t.zTbu! < -3)) {
        tingkat = 2;
        if (status.isNotEmpty) alasan.add(status);
      } else if (status.contains('Kurang') ||
          status.contains('Lebih') ||
          status.contains('Obesitas') ||
          (t.zBbtb != null && t.zBbtb! < -2) ||
          (t.zTbu != null && t.zTbu! < -2) ||
          (t.zBbu != null && t.zBbu! < -2)) {
        tingkat = 1;
        if (status.isNotEmpty) alasan.add(status);
      }
      // Tren berat badan: tidak naik dari pemeriksaan sebelumnya.
      if (periksa.length >= 2) {
        final p0 = periksa[0];
        final p1 = periksa[1];
        if (p0.beratBadan <= p1.beratBadan) {
          if (periksa.length >= 3 && p1.beratBadan <= periksa[2].beratBadan) {
            tingkat = 2;
            alasan.add('BB tidak naik 2 kali berturut-turut');
          } else {
            if (tingkat < 1) tingkat = 1;
            alasan.add('BB tidak naik dari pemeriksaan sebelumnya');
          }
        }
      }
      // Keterlambatan penimbangan lebih dari 2 bulan.
      final tgl = parseTanggalDb(t.tanggal);
      if (tgl != null && kini.difference(tgl).inDays > 60) {
        if (tingkat < 1) tingkat = 1;
        alasan.add('Belum ditimbang lebih dari 2 bulan');
      }
      if (alasan.isEmpty) alasan.add('Pertumbuhan terpantau baik');
      hasil.add(_Penilaian(b, tingkat, alasan, t));
    }
    hasil.sort((a, b) {
      final c = b.tingkat.compareTo(a.tingkat);
      if (c != 0) return c;
      return a.balita.namaBalita.compareTo(b.balita.namaBalita);
    });
    if (mounted) {
      setState(() {
        _semua = hasil;
        _memuat = false;
      });
    }
  }

  int _hitung(int tingkat) => _semua.where((e) => e.tingkat == tingkat).length;

  @override
  Widget build(BuildContext context) {
    final tampil =
        _saring < 0 ? _semua : _semua.where((e) => e.tingkat == _saring).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Pantauan Risiko')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chipSaring('Semua', -1, const Color(0xFF475569)),
                        _chipSaring('Tinggi', 2, const Color(0xFFDC2626)),
                        _chipSaring('Sedang', 1, const Color(0xFFD97706)),
                        _chipSaring('Rendah', 0, kTeal),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: tampil.isEmpty
                      ? const TampilanKosong(
                          pesan: 'Tidak ada anak pada tingkat ini.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: tampil.length,
                          itemBuilder: (_, i) {
                            final p = tampil[i];
                            final b = p.balita;
                            final warna = p.tingkat == 2
                                ? const Color(0xFFDC2626)
                                : p.tingkat == 1
                                    ? const Color(0xFFD97706)
                                    : kTeal;
                            final label = p.tingkat == 2
                                ? 'RISIKO TINGGI'
                                : p.tingkat == 1
                                    ? 'RISIKO SEDANG'
                                    : 'RISIKO RENDAH';
                            final lahir = parseTanggalDb(b.tglLahir);
                            final umur = lahir == null
                                ? ''
                                : '${hitungUmurBulan(lahir, DateTime.now())} bulan';
                            return AnimasiMasuk(
                              indeks: i,
                              child: Card(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            DetailAnakOrtuScreen(balita: b)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            AvatarKarakter.anak(
                                              nama: b.namaBalita,
                                              jenisKelamin: b.jenisKelamin,
                                              tglLahir: lahir,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                b.namaBalita,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ChipStatus(teks: label, warna: warna),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          p.alasan.join(' • '),
                                          style: TextStyle(
                                              color: warna,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          [
                                            if (umur.isNotEmpty) 'Umur $umur',
                                            if (p.terakhir != null)
                                              'BB ${p.terakhir!.beratBadan} Kg • TB ${p.terakhir!.tinggiBadan} Cm • ${formatTanggalID(p.terakhir!.tanggal)}',
                                          ].join(' • '),
                                          style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _chipSaring(String label, int nilai, Color warna) {
    final aktif = _saring == nilai;
    final jumlah = nilai < 0 ? _semua.length : _hitung(nilai);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label ($jumlah)'),
        selected: aktif,
        selectedColor: warna.withOpacity(0.16),
        labelStyle: TextStyle(
          color: aktif ? warna : const Color(0xFF475569),
          fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
          fontSize: 12.5,
        ),
        onSelected: (_) => setState(() => _saring = nilai),
      ),
    );
  }
}
