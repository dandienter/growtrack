import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../format.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';
import 'balita.dart';
import 'info.dart';
import 'jadwal.dart';
import 'kelola_database.dart';
import 'konsumsi.dart';
import 'laporan.dart';
import 'login.dart';
import 'orang_tua.dart';
import 'pemeriksaan.dart';
import 'pengaturan.dart';
import 'vaksin.dart';

/// Beranda + Drawer, port tampilan/MenuDashboard.java.
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

  Future<void> _buka(Widget halaman) async {
    Navigator.pop(context); // tutup drawer
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => halaman));
    _muat();
  }

  Future<void> _keluar() async {
    Navigator.pop(context);
    final yakin = await tampilKonfirmasi(
      context,
      judul: 'Konfirmasi Logout',
      pesan: 'Yakin ingin keluar dari sistem?',
      teksYa: 'Ya, Keluar',
      teksTidak: 'Batal',
    );
    if (!yakin || !mounted) return;
    SesiUser.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final namaPosyandu = _pengaturan?.namaPosyandu ?? 'Posyandu';
    return Scaffold(
      appBar: AppBar(title: Text(namaPosyandu.toUpperCase())),
      drawer: _drawer(),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: _memuat
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _kepalaBeranda(),
                  const SizedBox(height: 16),
                  _gridStatistik(),
                  const SizedBox(height: 20),
                  _seksiJadwal(),
                  const SizedBox(height: 20),
                  _seksiPerhatian(),
                  const SizedBox(height: 8),
                ],
              ),
      ),
    );
  }

  Widget _drawer() {
    Widget item(IconData ikon, String teks, VoidCallback onTap) {
      return ListTile(
        leading: Icon(ikon, color: kTeal),
        title: Text(teks),
        onTap: onTap,
      );
    }

    Widget kategori(String teks) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          teks,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF94A3B8),
            letterSpacing: 1,
          ),
        ),
      );
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: kTeal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/icon/logo.png', height: 56),
                  const SizedBox(height: 10),
                  const Text(
                    'GrowTrack',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Halo, ${SesiUser.namaLengkap ?? ''} (${SesiUser.role ?? ''})',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            item(Icons.dashboard_outlined, 'Beranda',
                () => Navigator.pop(context)),
            kategori('MASTER DATA'),
            item(Icons.family_restroom_outlined, 'Data Orang Tua',
                () => _buka(const OrangTuaListScreen())),
            item(Icons.child_care_outlined, 'Data Balita',
                () => _buka(const BalitaListScreen())),
            item(Icons.vaccines_outlined, 'Data Vaksin',
                () => _buka(const VaksinListScreen())),
            kategori('TRANSAKSI & PELAYANAN'),
            item(Icons.event_note_outlined, 'Jadwal Imunisasi',
                () => _buka(const JadwalListScreen())),
            item(Icons.monitor_weight_outlined, 'Pemeriksaan',
                () => _buka(const PemeriksaanListScreen())),
            item(Icons.restaurant_outlined, 'Konsumsi / PMT',
                () => _buka(const KonsumsiListScreen())),
            kategori('LAPORAN'),
            item(Icons.picture_as_pdf_outlined, 'Laporan',
                () => _buka(const LaporanScreen())),
            if (SesiUser.isAdmin) ...[
              kategori('PENGATURAN'),
              item(Icons.settings_outlined, 'Pengaturan',
                  () => _buka(const PengaturanScreen())),
              item(Icons.storage_outlined, 'Kelola Database',
                  () => _buka(const KelolaDatabaseScreen())),
            ],
            const Divider(),
            item(Icons.info_outline, 'Info Aplikasi',
                () => _buka(const InfoScreen())),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
              title: const Text('Keluar (Logout)',
                  style: TextStyle(color: Color(0xFFEF4444))),
              onTap: _keluar,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kepalaBeranda() {
    final logoPath = _pengaturan?.logoPath;
    final adaLogo = logoPath != null &&
        logoPath.isNotEmpty &&
        File(logoPath).existsSync();
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (adaLogo) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(logoPath),
                    width: 56, height: 56, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, ${SesiUser.namaLengkap ?? ''} (${SesiUser.role ?? ''})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _pengaturan?.namaPosyandu ?? '',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  Text(
                    tanggalPanjangId(DateTime.now()),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      KartuStatistik(
        judul: 'Total Balita',
        nilai: '${st['totalBalita']?.toInt() ?? 0}',
        subJudul: 'Anak Terdaftar',
        warna: const Color(0xFF3B82F6),
        ikon: Icons.child_care,
      ),
      KartuStatistik(
        judul: 'Periksa Bulan Ini',
        nilai: '${st['periksaBulanIni']?.toInt() ?? 0}',
        subJudul: 'Total Pelayanan',
        warna: const Color(0xFFF59E0B),
        ikon: Icons.monitor_weight,
      ),
      KartuStatistik(
        judul: 'Vaksin Mendatang',
        nilai: '${st['vaksinMendatang']?.toInt() ?? 0}',
        subJudul: 'Belum Selesai',
        warna: const Color(0xFFEF4444),
        ikon: Icons.vaccines,
      ),
      KartuStatistik(
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
        childAspectRatio: 1.45,
      ),
      itemCount: kartu.length,
      itemBuilder: (_, i) => kartu[i],
    );
  }

  Widget _judulSeksi(String teks, IconData ikon, Color warna) {
    return Row(
      children: [
        Icon(ikon, color: warna, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            teks,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _seksiJadwal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _judulSeksi('Jadwal Imunisasi Mendatang', Icons.event, kTeal),
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
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2F1),
                      child: Icon(Icons.vaccines, color: kTeal, size: 20),
                    ),
                    title: Text(j['nama_balita']?.toString() ?? ''),
                    subtitle: Text(j['nama_imunisasi']?.toString() ?? ''),
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
        _judulSeksi('Perhatian Khusus (Stunting/Gizi Buruk)',
            Icons.warning_amber_outlined, const Color(0xFFEF4444)),
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
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          warnaStatusGizi(pk['status_gizi']?.toString())
                              .withOpacity(0.12),
                      child: Icon(Icons.child_care,
                          color:
                              warnaStatusGizi(pk['status_gizi']?.toString()),
                          size: 20),
                    ),
                    title: Text(pk['nama_balita']?.toString() ?? ''),
                    subtitle:
                        Text(formatTanggalID(pk['tanggal']?.toString())),
                    trailing: ChipStatus(
                      teks: pk['status_gizi']?.toString() ?? '',
                      warna: warnaStatusGizi(pk['status_gizi']?.toString()),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
