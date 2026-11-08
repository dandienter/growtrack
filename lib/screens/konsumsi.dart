import 'package:flutter/material.dart';

import '../db/database.dart';
import '../format.dart';
import '../models.dart';
import '../widgets.dart';

/// Port tampilan/FormKonsumsi.java: Konsumsi / PMT warga.
class KonsumsiListScreen extends StatefulWidget {
  const KonsumsiListScreen({super.key});

  @override
  State<KonsumsiListScreen> createState() => _KonsumsiListScreenState();
}

class _KonsumsiListScreenState extends State<KonsumsiListScreen> {
  List<Konsumsi> _daftar = [];
  bool _memuat = true;
  String _cari = '';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final data = await GrowTrackDB.ambilKonsumsi(cari: _cari);
    if (!mounted) return;
    setState(() {
      _daftar = data;
      _memuat = false;
    });
  }

  Future<void> _tambah() async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const KonsumsiFormScreen()),
    );
    if (simpan == true) _muat();
  }

  Future<void> _ubah(Konsumsi k) async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => KonsumsiFormScreen(konsumsi: k)),
    );
    if (simpan == true) _muat();
  }

  Future<void> _hapus(Konsumsi k) async {
    final yakin = await tampilKonfirmasi(
      context,
      judul: 'Konfirmasi',
      pesan: 'Yakin ingin menghapus data konsumsi PMT ini?',
      teksYa: 'Ya, Hapus',
    );
    if (!yakin) return;
    await GrowTrackDB.hapusKonsumsi(k.idKonsumsi);
    if (!mounted) return;
    tampilSnack(context, 'Data konsumsi dihapus!');
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konsumsi / PMT')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          KotakCari(
            hint: 'Cari nama kegiatan / keterangan...',
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
                        pesan: 'Belum ada data konsumsi PMT.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _daftar.length,
                        itemBuilder: (_, i) {
                          final k = _daftar[i];
                          return AnimasiMasuk(indeks: i, child: Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFDCFCE7),
                                child: Icon(Icons.restaurant,
                                    color: Color(0xFF10B981)),
                              ),
                              title: Text(k.namaKegiatan,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${formatTanggalID(k.tanggal)} • ${k.pemberianMt ?? '-'}\n'
                                'RT ${k.rt ?? '-'} • PJ: ${k.penanggungJawab ?? '-'} • ${k.jumlahBalita} Anak',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatRupiah(k.totalBiaya),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (pil) {
                                      if (pil == 'ubah') _ubah(k);
                                      if (pil == 'hapus') _hapus(k);
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
                          ));
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class KonsumsiFormScreen extends StatefulWidget {
  final Konsumsi? konsumsi;
  const KonsumsiFormScreen({super.key, this.konsumsi});

  @override
  State<KonsumsiFormScreen> createState() => _KonsumsiFormScreenState();
}

class _KonsumsiFormScreenState extends State<KonsumsiFormScreen> {
  final _txtKegiatan = TextEditingController();
  final _txtMenu = TextEditingController();
  final _txtRt = TextEditingController();
  final _txtPj = TextEditingController();
  final _txtJumlah = TextEditingController();
  final _txtBiaya = TextEditingController();
  final _txtKeterangan = TextEditingController();
  DateTime? _tanggal = DateTime.now();
  String? _idBaru;

  bool get _modeUbah => widget.konsumsi != null;

  @override
  void initState() {
    super.initState();
    final k = widget.konsumsi;
    if (k != null) {
      _tanggal = parseTanggalDb(k.tanggal);
      _txtKegiatan.text = k.namaKegiatan;
      _txtMenu.text = k.pemberianMt ?? '';
      _txtRt.text = k.rt ?? '';
      _txtPj.text = k.penanggungJawab ?? '';
      _txtJumlah.text = k.jumlahBalita == 0 ? '' : k.jumlahBalita.toString();
      _txtBiaya.text = k.totalBiaya == 0 ? '' : k.totalBiaya.toStringAsFixed(0);
      _txtKeterangan.text = k.keterangan ?? '';
    } else {
      _siapkanId();
    }
  }

  Future<void> _siapkanId() async {
    final id = await GrowTrackDB.buatId('konsumsi', 'id_konsumsi', 'KNS-');
    if (mounted) setState(() => _idBaru = id);
  }

  @override
  void dispose() {
    _txtKegiatan.dispose();
    _txtMenu.dispose();
    _txtRt.dispose();
    _txtPj.dispose();
    _txtJumlah.dispose();
    _txtBiaya.dispose();
    _txtKeterangan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_txtKegiatan.text.trim().isEmpty ||
        _txtMenu.text.trim().isEmpty ||
        _txtJumlah.text.trim().isEmpty ||
        _txtBiaya.text.trim().isEmpty ||
        _tanggal == null) {
      tampilSnack(context, 'Semua data kegiatan konsumsi wajib diisi!');
      return;
    }
    final jumlah = parseAngkaRibuan(_txtJumlah.text);
    final biaya = parseAngkaRibuan(_txtBiaya.text);
    if (jumlah == null || biaya == null) {
      tampilSnack(context, 'Jumlah Balita dan Total Biaya harus berupa angka!');
      return;
    }
    final k = Konsumsi(
      idKonsumsi: widget.konsumsi?.idKonsumsi ?? _idBaru ?? '',
      tanggal: keTeksDb(_tanggal),
      namaKegiatan: _txtKegiatan.text.trim(),
      pemberianMt: _txtMenu.text.trim(),
      rt: _txtRt.text.trim().isEmpty ? null : _txtRt.text.trim(),
      penanggungJawab:
          _txtPj.text.trim().isEmpty ? null : _txtPj.text.trim(),
      jumlahBalita: jumlah.toInt(),
      totalBiaya: biaya,
      keterangan:
          _txtKeterangan.text.trim().isEmpty ? null : _txtKeterangan.text.trim(),
    );
    try {
      await GrowTrackDB.simpanKonsumsi(k, baru: !_modeUbah);
      if (!mounted) return;
      tampilSnack(
        context,
        _modeUbah
            ? 'Data Konsumsi PMT berhasil diubah!'
            : 'Data Konsumsi PMT berhasil disimpan!',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Error simpan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_modeUbah ? 'Ubah Konsumsi PMT' : 'Tambah Konsumsi PMT')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            enabled: false,
            decoration: dekorasiInput(
                'ID Konsumsi (Auto): ${widget.konsumsi?.idKonsumsi ?? _idBaru ?? '...'}'),
          ),
          const SizedBox(height: 14),
          KolomTanggal(
            label: 'Tanggal',
            nilai: _tanggal,
            onBerubah: (v) => setState(() => _tanggal = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtKegiatan,
            decoration:
                dekorasiInput('Nama Kegiatan', ikon: Icons.event_outlined),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtMenu,
            decoration: dekorasiInput('Pemberian MT (Menu PMT)',
                ikon: Icons.restaurant_menu_outlined),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _txtRt,
                  decoration: dekorasiInput('RT', ikon: Icons.place_outlined),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _txtPj,
                  decoration: dekorasiInput('Penanggung Jawab RT',
                      ikon: Icons.person_outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _txtJumlah,
                  keyboardType: TextInputType.number,
                  decoration: dekorasiInput('Jumlah Balita'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _txtBiaya,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: dekorasiInput('Total Biaya (Rp)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtKeterangan,
            maxLines: 2,
            decoration: dekorasiInput('Keterangan / Sumber Dana',
                ikon: Icons.notes_outlined),
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
