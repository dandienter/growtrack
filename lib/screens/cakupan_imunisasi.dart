import 'package:flutter/material.dart';

import '../db/database.dart';
import '../widgets.dart';

/// Cakupan Imunisasi: persentase balita yang sudah menyelesaikan
/// tiap jenis imunisasi dari seluruh balita terdaftar.
class CakupanImunisasiScreen extends StatefulWidget {
  const CakupanImunisasiScreen({super.key});

  @override
  State<CakupanImunisasiScreen> createState() => _CakupanImunisasiScreenState();
}

class _CakupanImunisasiScreenState extends State<CakupanImunisasiScreen> {
  List<Map<String, Object?>> _baris = [];
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final r = await GrowTrackDB.ambilCakupanImunisasi();
    if (mounted) {
      setState(() {
        _baris = r;
        _memuat = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var totalBalita = 0;
    var jumlahPersen = 0.0;
    for (final b in _baris) {
      totalBalita = (b['total_balita'] as num?)?.toInt() ?? 0;
      final selesai = (b['selesai'] as num?)?.toInt() ?? 0;
      if (totalBalita > 0) jumlahPersen += selesai / totalBalita * 100;
    }
    final rata = _baris.isEmpty ? 0.0 : jumlahPersen / _baris.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Cakupan Imunisasi')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : _baris.isEmpty
              ? const TampilanKosong(
                  pesan: 'Belum ada data imunisasi.')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: kTeal,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_outlined,
                                color: Colors.white, size: 34),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Rata-rata Cakupan',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                  Text(
                                    '${rata.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'dari $totalBalita balita terdaftar',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final b in _baris) _barisVaksin(b, totalBalita),
                  ],
                ),
    );
  }

  Widget _barisVaksin(Map<String, Object?> b, int totalBalita) {
    final nama = b['nama_imunisasi']?.toString() ?? '';
    final selesai = (b['selesai'] as num?)?.toInt() ?? 0;
    final persen = totalBalita == 0 ? 0.0 : selesai / totalBalita;
    final warna = persen >= 0.8
        ? kTeal
        : persen >= 0.5
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
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
                    nama,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14.5),
                  ),
                ),
                Text(
                  '${(persen * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: warna, fontSize: 14.5),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$selesai dari $totalBalita balita sudah selesai',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: persen,
                minHeight: 9,
                backgroundColor: const Color(0xFFE2E8F0),
                color: warna,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
