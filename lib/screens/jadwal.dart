import 'package:flutter/material.dart';

import '../db/database.dart';
import '../format.dart';
import '../models.dart';
import '../widgets.dart';

/// Port tampilan/FormImunisasi.java: jadwal imunisasi balita.
class JadwalListScreen extends StatefulWidget {
  const JadwalListScreen({super.key});

  @override
  State<JadwalListScreen> createState() => _JadwalListScreenState();
}

class _JadwalListScreenState extends State<JadwalListScreen> {
  List<JadwalImunisasi> _daftar = [];
  bool _memuat = true;
  String _cari = '';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final data = await GrowTrackDB.ambilJadwal(cari: _cari);
    if (!mounted) return;
    setState(() {
      _daftar = data;
      _memuat = false;
    });
  }

  Future<void> _tambah() async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const JadwalFormScreen()),
    );
    if (simpan == true) _muat();
  }

  Future<void> _ubah(JadwalImunisasi j) async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => JadwalFormScreen(jadwal: j)),
    );
    if (simpan == true) _muat();
  }

  Future<void> _hapus(JadwalImunisasi j) async {
    final yakin = await tampilKonfirmasi(
      context,
      judul: 'Konfirmasi',
      pesan: 'Yakin ingin menghapus jadwal imunisasi ini?',
      teksYa: 'Ya, Hapus',
    );
    if (!yakin) return;
    await GrowTrackDB.hapusJadwal(j.idJadwal);
    if (!mounted) return;
    tampilSnack(context, 'Jadwal dihapus!');
    _muat();
  }

  bool _telat(JadwalImunisasi j) {
    if (j.status == 'Selesai' || j.tglBerikutnya == null) return false;
    final tgl = parseTanggalDb(j.tglBerikutnya);
    if (tgl == null) return false;
    final hariIni = DateTime.now();
    final hari = DateTime(hariIni.year, hariIni.month, hariIni.day);
    return tgl.isBefore(hari);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Imunisasi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          KotakCari(
            hint: 'Cari nama balita / vaksin...',
            onBerubah: (v) {
              _cari = v;
              _muat();
            },
          ),
          Expanded(
            child: _memuat
                ? const Center(child: CircularProgressIndicator())
                : _daftar.isEmpty
                    ? const TampilanKosong(
                        pesan: 'Belum ada jadwal imunisasi.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _daftar.length,
                        itemBuilder: (_, i) {
                          final j = _daftar[i];
                          final telat = _telat(j);
                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: telat
                                  ? const BorderSide(
                                      color: Color(0xFFEF4444), width: 1.2)
                                  : BorderSide.none,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: telat
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFE0F2F1),
                                child: Icon(Icons.event_note,
                                    color: telat
                                        ? const Color(0xFFEF4444)
                                        : kTeal),
                              ),
                              title: Text(j.namaBalita ?? j.idBalita,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${j.namaImunisasi ?? j.idImunisasi}\n'
                                'Diberikan: ${formatTanggalID(j.tglDiberikan)} • '
                                'Berikutnya: ${formatTanggalID(j.tglBerikutnya)}'
                                '${telat ? '\nTELAT - segera dijadwalkan ulang' : ''}',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ChipStatus(
                                    teks: telat ? 'Telat' : j.status,
                                    warna: j.status == 'Selesai'
                                        ? const Color(0xFF22C55E)
                                        : telat
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFF59E0B),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (pil) {
                                      if (pil == 'ubah') _ubah(j);
                                      if (pil == 'hapus') _hapus(j);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'ubah', child: Text('Ubah')),
                                      PopupMenuItem(
                                          value: 'hapus', child: Text('Hapus')),
                                    ],
                                  ),
                                ],
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
}

class JadwalFormScreen extends StatefulWidget {
  final JadwalImunisasi? jadwal;
  const JadwalFormScreen({super.key, this.jadwal});

  @override
  State<JadwalFormScreen> createState() => _JadwalFormScreenState();
}

class _JadwalFormScreenState extends State<JadwalFormScreen> {
  List<Balita> _daftarBalita = [];
  List<ImunisasiVaksin> _daftarVaksin = [];
  Balita? _balita;
  ImunisasiVaksin? _vaksin;
  DateTime? _tglDiberikan;
  DateTime? _tglBerikutnya;
  String _status = 'Belum';
  String? _idBaru;
  bool _memuat = true;

  bool get _modeUbah => widget.jadwal != null;

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  Future<void> _siapkan() async {
    final balita = await GrowTrackDB.ambilBalita();
    final vaksin = await GrowTrackDB.ambilVaksin();
    final j = widget.jadwal;
    if (!mounted) return;
    setState(() {
      _daftarBalita = balita;
      _daftarVaksin = vaksin;
      if (j != null) {
        for (final b in balita) {
          if (b.idBalita == j.idBalita) _balita = b;
        }
        for (final v in vaksin) {
          if (v.idImunisasi == j.idImunisasi) _vaksin = v;
        }
        _tglDiberikan = parseTanggalDb(j.tglDiberikan);
        _tglBerikutnya = parseTanggalDb(j.tglBerikutnya);
        _status = j.status;
      }
      _memuat = false;
    });
    if (j == null) {
      final id = await GrowTrackDB.buatId('jadwal_imunisasi', 'id_jadwal', 'JDW-');
      if (mounted) setState(() => _idBaru = id);
    }
  }

  Future<void> _simpan() async {
    if (_balita == null || _vaksin == null) {
      tampilSnack(context, 'Pilih Balita dan Vaksin terlebih dahulu!');
      return;
    }
    final j = JadwalImunisasi(
      idJadwal: widget.jadwal?.idJadwal ?? _idBaru ?? '',
      idBalita: _balita!.idBalita,
      idImunisasi: _vaksin!.idImunisasi,
      tglDiberikan: _tglDiberikan == null ? null : keTeksDb(_tglDiberikan),
      tglBerikutnya: _tglBerikutnya == null ? null : keTeksDb(_tglBerikutnya),
      status: _status,
    );
    try {
      await GrowTrackDB.simpanJadwal(j, baru: !_modeUbah);
      if (!mounted) return;
      tampilSnack(
          context, _modeUbah ? 'Jadwal berhasil diubah!' : 'Jadwal tersimpan!');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Gagal menyimpan jadwal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return Scaffold(
        appBar: AppBar(title: const Text('Jadwal Imunisasi')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar:
          AppBar(title: Text(_modeUbah ? 'Ubah Jadwal' : 'Tambah Jadwal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            enabled: false,
            decoration: dekorasiInput(
                'ID Jadwal (Auto): ${widget.jadwal?.idJadwal ?? _idBaru ?? '...'}'),
          ),
          const SizedBox(height: 14),
          KolomPilihCari<Balita>(
            label: 'Balita',
            petunjuk: '-- Pilih Balita --',
            nilai: _balita,
            daftar: _daftarBalita,
            labelItem: (b) => '${b.idBalita} - ${b.namaBalita}',
            onBerubah: (v) => setState(() => _balita = v),
          ),
          const SizedBox(height: 14),
          KolomPilihCari<ImunisasiVaksin>(
            label: 'Vaksin',
            petunjuk: '-- Pilih Vaksin --',
            nilai: _vaksin,
            daftar: _daftarVaksin,
            labelItem: (v) => '${v.idImunisasi} - ${v.namaImunisasi}',
            onBerubah: (v) => setState(() => _vaksin = v),
          ),
          const SizedBox(height: 14),
          KolomTanggal(
            label: 'Tanggal Diberikan',
            nilai: _tglDiberikan,
            bolehKosong: true,
            onBerubah: (v) => setState(() => _tglDiberikan = v),
          ),
          const SizedBox(height: 14),
          KolomTanggal(
            label: 'Tanggal Berikutnya',
            nilai: _tglBerikutnya,
            bolehKosong: true,
            onBerubah: (v) => setState(() => _tglBerikutnya = v),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: dekorasiInput('Status'),
            items: const ['Belum', 'Selesai']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? 'Belum'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _simpan,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
          ),
        ],
      ),
    );
  }
}
