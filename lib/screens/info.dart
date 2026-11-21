import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../sync/update_service.dart';
import '../widgets.dart';

/// Port tampilan/DialogInfoAplikasi.java: tentang aplikasi GrowTrack.
class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  String _namaPosyandu = 'Posyandu Beringin DDN';
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final pg = await GrowTrackDB.ambilPengaturan();
    if (!mounted) return;
    setState(() {
      if (pg.namaPosyandu != null && pg.namaPosyandu!.isNotEmpty) {
        _namaPosyandu = pg.namaPosyandu!;
      }
      _logoPath = pg.logoPath;
    });
  }

  Widget _seksi(String judul, Widget isi) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: kTeal)),
            const SizedBox(height: 8),
            isi,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logoFile = _logoPath != null && _logoPath!.isNotEmpty
        ? File(_logoPath!)
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Info Aplikasi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Image.asset('assets/icon/posyandu-logo.png',
                    width: 96, height: 96),
                const SizedBox(height: 10),
                const Text(
                  'GrowTrack',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold, color: kTeal),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Sistem Informasi Pemantauan Tumbuh Kembang Balita',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF475569)),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Text(
                    'Versi $kNamaVersiIni',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                        fontSize: 12),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kode versi $kKodeVersiIni • Aplikasi Android GrowTrack',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => LayananUpdate.cekManual(context),
                  icon: const Icon(Icons.system_update, size: 18),
                  label: const Text('Cek Pembaruan'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _seksi(
            'Fungsi Aplikasi',
            const Text(
              'GrowTrack membantu kader Posyandu dalam pencatatan dan '
              'pemantauan tumbuh kembang balita secara digital, dan membantu '
              'orang tua memantau pertumbuhan anaknya dari rumah. Data '
              'tersimpan di perangkat dan tersinkron otomatis ke cloud saat '
              'ada internet.',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _seksi(
            'Fitur Utama',
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  Data orang tua dan balita'),
                SizedBox(height: 4),
                Text('•  Pemeriksaan antropometri (berat, tinggi, lingkar kepala)'),
                SizedBox(height: 4),
                Text('•  Penilaian status gizi otomatis berstandar WHO 2006'),
                SizedBox(height: 4),
                Text('•  Jadwal imunisasi dan data konsumsi'),
                SizedBox(height: 4),
                Text('•  Kurva pertumbuhan WHO dan penilaian Z-Score'),
                SizedBox(height: 4),
                Text('•  Akun orang tua: pantau anak dan edukasi offline'),
                SizedBox(height: 4),
                Text('•  Sinkronisasi cloud antarperangkat'),
                SizedBox(height: 4),
                Text('•  Laporan PDF siap cetak'),
                SizedBox(height: 4),
                Text('•  Cadangkan dan pulihkan database'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _seksi(
            'Standar Penilaian Gizi',
            const Text(
              'Menggunakan Standar Antropometri WHO Child Growth Standards 2006 '
              'metode LMS Z-Score, diadopsi Kemenkes RI melalui PMK No. 2 Tahun '
              '2020. Indikator: BB/U, TB/U, BB/TB.',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          _seksi(
            'Dikembangkan Oleh',
            const Text(
              'Kelompok KKP Teknik Informatika, Universitas Indraprasta PGRI '
              '(UNINDRA), Tahun 2026.',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('Untuk',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          const SizedBox(height: 8),
          if (logoFile != null && logoFile.existsSync())
            Center(
              child: Image.file(logoFile, width: 64, height: 64),
            ),
          Center(
            child: Text(
              _namaPosyandu,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              '© 2026 KKP Teknik Informatika UNINDRA',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
