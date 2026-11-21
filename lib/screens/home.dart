import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../format.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';
import 'balita.dart';
import 'jadwal.dart';
import 'laporan.dart';
import 'panduan.dart';
import 'pantauan_risiko.dart';
import 'pemeriksaan.dart';

/// Isi tab Beranda (cangkang AppBar + navigasi bawah ada di utama.dart),
/// port tampilan/MenuDashboard.java.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Pengaturan? _pengaturan;
  Map<String, num>? _statistik;
  List<Map<String, Object?>> _jadwalMendatang = [];
  List<Map<String, Object?>> _perhatianKhusus = [];
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final pg = await GrowTrackDB.ambilPengaturan();
      final st = await GrowTrackDB.ambilStatistik();
      final jm = await GrowTrackDB.jadwalMendatang();
      final pk = await GrowTrackDB.perhatianKhusus();
      if (!mounted) return;
      setState(() {
        _pengaturan = pg;
        _statistik = st;
        _jadwalMendatang = jm;
        _perhatianKhusus = pk;
        _memuat = false;
      });
    } catch (_) {
      if (mounted) setState(() => _memuat = false);
    }
  }

  /// Buka layar dari aksi cepat / tombol lihat semua, lalu segarkan beranda.
  Future<void> _bukaCepat(Widget halaman) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => halaman));
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _muat,
      child: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AnimasiMasuk(indeks: 0, child: _kepalaBeranda()),
                const SizedBox(height: 14),
                _gridStatistik(),
                const SizedBox(height: 16),
                AnimasiMasuk(indeks: 2, child: _seksiAksiCepat()),
                const SizedBox(height: 16),
                AnimasiMasuk(indeks: 3, child: _seksiJadwal()),
                const SizedBox(height: 16),
                AnimasiMasuk(indeks: 4, child: _seksiPerhatian()),
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  /// Kartu sapaan hero: gradasi teal, logo resmi di lingkaran putih,
  /// teks putih, dekorasi lingkaran transparan di pojok kanan atas.
  Widget _kepalaBeranda() {
    final logoPath = _pengaturan?.logoPath;
    final adaLogo = logoPath != null &&
        logoPath.isNotEmpty &&
        File(logoPath).existsSync();
    final alamat = _pengaturan?.alamat;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kTeal, Color(0xFF0A6E67)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kTeal.withOpacity(0.30),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -55,
            top: -55,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -70,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: adaLogo
                      ? Image.file(
                          File(logoPath),
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                        )
                      : Image.asset(
                          'assets/icon/posyandu-logo.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${SesiUser.namaLengkap ?? ''} (${SesiUser.role ?? ''})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _pengaturan?.namaPosyandu ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      if (alamat != null && alamat.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          alamat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        tanggalPanjangId(DateTime.now()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridStatistik() {
    final st = _statistik ??
        const {
          'totalBalita': 0,
          'periksaBulanIni': 0,
          'vaksinMendatang': 0,
          'biayaPmt': 0,
        };
    final kartu = [
      _KartuStat(
        judul: 'Total Balita',
        nilai: '${st['totalBalita']?.toInt() ?? 0}',
        subJudul: 'Anak Terdaftar',
        warna: const Color(0xFF3B82F6),
        ikon: Icons.child_care,
      ),
      _KartuStat(
        judul: 'Periksa Bulan Ini',
        nilai: '${st['periksaBulanIni']?.toInt() ?? 0}',
        subJudul: 'Total Pelayanan',
        warna: const Color(0xFFF59E0B),
        ikon: Icons.monitor_weight,
      ),
      _KartuStat(
        judul: 'Vaksin Mendatang',
        nilai: '${st['vaksinMendatang']?.toInt() ?? 0}',
        subJudul: 'Belum Selesai',
        warna: const Color(0xFFEF4444),
        ikon: Icons.vaccines,
      ),
      _KartuStat(
        judul: 'Biaya PMT',
        nilai: formatRupiah(st['biayaPmt'] ?? 0),
        subJudul: 'Bulan Ini',
        warna: const Color(0xFF10B981),
        ikon: Icons.payments,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.32,
      ),
      itemCount: kartu.length,
      itemBuilder: (_, i) => AnimasiMasuk(indeks: i, child: kartu[i]),
    );
  }

  Widget _seksiAksiCepat() {
    Widget tombol(IconData ikon, String label, Color warna, Widget tujuan) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _bukaCepat(tujuan),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: warna.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(ikon, color: warna, size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PanduanKaderScreen()),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kTeal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.menu_book, color: Colors.white, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panduan Penggunaan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Langkah demi langkah tiap fitur, dari data sampai laporan',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _judulSeksi('Aksi Cepat', Icons.bolt, kTeal),
        const SizedBox(height: 8),
        Card(
          color: Colors.white,
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                tombol(Icons.monitor_weight, 'Periksa',
                    const Color(0xFF3B82F6), const PemeriksaanListScreen()),
                tombol(Icons.child_care, 'Balita', const Color(0xFF22C55E),
                    const BalitaListScreen()),
                tombol(Icons.event_note, 'Jadwal', const Color(0xFFF59E0B),
                    const JadwalListScreen()),
                tombol(Icons.picture_as_pdf, 'Laporan',
                    const Color(0xFF8B5CF6), const LaporanScreen()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _judulSeksi(String teks, IconData ikon, Color warna,
      {VoidCallback? onLihatSemua}) {
    return Row(
      children: [
        Icon(ikon, color: warna, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            teks,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        if (onLihatSemua != null)
          TextButton(
            onPressed: onLihatSemua,
            style: TextButton.styleFrom(
              foregroundColor: kTeal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Lihat Semua',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _seksiJadwal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _judulSeksi(
          'Jadwal Imunisasi Mendatang',
          Icons.event,
          kTeal,
          onLihatSemua: () => _bukaCepat(const JadwalListScreen()),
        ),
        const SizedBox(height: 8),
        if (_jadwalMendatang.isEmpty)
          const Card(
            color: Colors.white,
            child: ListTile(
              subtitle: Text('Tidak ada jadwal imunisasi mendatang.'),
            ),
          )
        else
          Card(
            color: Colors.white,
            child: Column(
              children: [
                for (final j in _jadwalMendatang)
                  ListTile(
                    leading: AvatarKarakter.anak(
                      nama: j['nama_balita']?.toString() ?? '',
                      jenisKelamin: j['jenis_kelamin']?.toString(),
                      tglLahir: parseTanggalDb(j['tgl_lahir']?.toString()),
                    ),
                    title: Text(
                      j['nama_balita']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      j['nama_imunisasi']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      formatTanggalID(j['tgl_berikutnya']?.toString()),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _seksiPerhatian() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _judulSeksi(
          'Perhatian Khusus',
          Icons.warning_amber_outlined,
          const Color(0xFFEF4444),
          onLihatSemua: () => _bukaCepat(const PantauanRisikoScreen()),
        ),
        const SizedBox(height: 8),
        if (_perhatianKhusus.isEmpty)
          const Card(
            color: Colors.white,
            child: ListTile(
              subtitle: Text('Tidak ada balita yang memerlukan perhatian khusus.'),
            ),
          )
        else
          Card(
            color: Colors.white,
            child: Column(
              children: [
                for (final pk in _perhatianKhusus)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AvatarKarakter.anak(
                              nama: pk['nama_balita']?.toString() ?? '',
                              jenisKelamin: pk['jenis_kelamin']?.toString(),
                              tglLahir:
                                  parseTanggalDb(pk['tgl_lahir']?.toString()),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pk['nama_balita']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ChipStatus(
                              teks: pk['status_gizi']?.toString() ?? '',
                              warna:
                                  warnaStatusGizi(pk['status_gizi']?.toString()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Periksa terakhir ${formatTanggalID(pk['tanggal']?.toString())}',
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Angka statistik yang bergerak naik (count-up) saat Beranda tampil:
/// nilai murni dianimasikan apa adanya, nilai Rupiah dianimasikan lalu
/// diformat ulang tiap bingkai.
class _AngkaNaik extends StatelessWidget {
  final String teks;
  final TextStyle gaya;

  const _AngkaNaik({required this.teks, required this.gaya});

  @override
  Widget build(BuildContext context) {
    final angka = num.tryParse(teks.replaceAll(RegExp(r'[^0-9]'), ''));
    if (angka == null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(teks, style: gaya, maxLines: 1),
      );
    }
    final rupiah = teks.contains('Rp');
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: angka.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          rupiah ? formatRupiah(v.round()) : '${v.round()}',
          style: gaya,
          maxLines: 1,
        ),
      ),
    );
  }
}

/// Kartu statistik Beranda versi terpoles: kartu putih radius 20, ikon di
/// dalam kotak 38px radius 12 berlatar warna ikon lembut, angka 26px tebal,
/// judul kapital 11px abu. Sengaja lokal di berkas ini agar widget
/// KartuStatistik bersama di widgets.dart tidak berubah.
class _KartuStat extends StatelessWidget {
  final String judul;
  final String nilai;
  final String subJudul;
  final Color warna;
  final IconData ikon;

  const _KartuStat({
    required this.judul,
    required this.nilai,
    required this.subJudul,
    required this.warna,
    required this.ikon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: warna.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(ikon, color: warna, size: 18),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                judul.toUpperCase(),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 2),
            _AngkaNaik(
              teks: nilai,
              gaya: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: warna,
              ),
            ),
            Text(
              subJudul,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
