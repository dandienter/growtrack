import 'package:flutter/material.dart';

import '../db/database.dart';
import '../models.dart';
import '../widgets.dart';

/// Port tampilan/FormVaksin.java: master data vaksin / imunisasi.
class VaksinListScreen extends StatefulWidget {
  const VaksinListScreen({super.key});

  @override
  State<VaksinListScreen> createState() => _VaksinListScreenState();
}

class _VaksinListScreenState extends State<VaksinListScreen> {
  List<ImunisasiVaksin> _daftar = [];
  bool _memuat = true;
  String _cari = '';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    var data = await GrowTrackDB.ambilVaksin();
    if (_cari.isNotEmpty) {
      final c = _cari.toLowerCase();
      data = data
          .where((v) =>
              v.namaImunisasi.toLowerCase().contains(c) ||
              v.idImunisasi.toLowerCase().contains(c))
          .toList();
    }
    if (!mounted) return;
    setState(() {
      _daftar = data;
      _memuat = false;
    });
  }

  Future<void> _tambah() async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VaksinFormScreen()),
    );
    if (simpan == true) _muat();
  }

  Future<void> _ubah(ImunisasiVaksin v) async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VaksinFormScreen(vaksin: v)),
    );
    if (simpan == true) _muat();
  }

  Future<void> _hapus(ImunisasiVaksin v) async {
    final yakin = await tampilKonfirmasi(
      context,
      judul: 'Konfirmasi',
      pesan: 'Yakin ingin menghapus vaksin "${v.namaImunisasi}"?',
      teksYa: 'Ya, Hapus',
    );
    if (!yakin) return;
    try {
      await GrowTrackDB.hapusVaksin(v.idImunisasi);
      if (!mounted) return;
      tampilSnack(context, 'Data vaksin dihapus!');
      _muat();
    } catch (e) {
      if (mounted) {
        tampilSnack(context,
            'Gagal menghapus: vaksin masih dipakai pada jadwal imunisasi.');
      }
    }
  }

  Color _warnaKategori(String? kategori) {
    switch (kategori) {
      case 'Wajib':
        return const Color(0xFF0F9D94);
      case 'Lanjutan':
        return const Color(0xFFF59E0B);
      case 'Pilihan':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Vaksin')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          KotakCari(
            hint: 'Cari nama / ID vaksin...',
            onBerubah: (v) {
              _cari = v;
              _muat();
            },
          ),
          Expanded(
            child: _memuat
                ? const Center(child: CircularProgressIndicator())
                : _daftar.isEmpty
                    ? const TampilanKosong(pesan: 'Belum ada data vaksin.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _daftar.length,
                        itemBuilder: (_, i) {
                          final v = _daftar[i];
                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE0F2F1),
                                child: Icon(Icons.vaccines, color: kTeal),
                              ),
                              title: Text(v.namaImunisasi,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${v.merkProdusen ?? '-'} • Dosis ${v.dosis ?? '-'} • Usia ${v.usiaPemberian ?? '-'}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ChipStatus(
                                    teks: v.kategori ?? '-',
                                    warna: _warnaKategori(v.kategori),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (pil) {
                                      if (pil == 'ubah') _ubah(v);
                                      if (pil == 'hapus') _hapus(v);
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

class VaksinFormScreen extends StatefulWidget {
  final ImunisasiVaksin? vaksin;
  const VaksinFormScreen({super.key, this.vaksin});

  @override
  State<VaksinFormScreen> createState() => _VaksinFormScreenState();
}

class _VaksinFormScreenState extends State<VaksinFormScreen> {
  final _txtNama = TextEditingController();
  final _txtMerk = TextEditingController();
  final _txtDosis = TextEditingController();
  final _txtUsia = TextEditingController();
  String _kategori = 'Wajib';
  String? _idBaru;

  bool get _modeUbah => widget.vaksin != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vaksin;
    if (v != null) {
      _txtNama.text = v.namaImunisasi;
      _txtMerk.text = v.merkProdusen ?? '';
      _txtDosis.text = v.dosis ?? '';
      _txtUsia.text = v.usiaPemberian ?? '';
      _kategori = v.kategori ?? 'Wajib';
    } else {
      _siapkanId();
    }
  }

  Future<void> _siapkanId() async {
    final id = await GrowTrackDB.buatId('imunisasi', 'id_imunisasi', 'IMN-');
    if (mounted) setState(() => _idBaru = id);
  }

  @override
  void dispose() {
    _txtNama.dispose();
    _txtMerk.dispose();
    _txtDosis.dispose();
    _txtUsia.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_txtNama.text.trim().isEmpty) {
      tampilSnack(context, 'Nama vaksin wajib diisi!');
      return;
    }
    final v = ImunisasiVaksin(
      idImunisasi: widget.vaksin?.idImunisasi ?? _idBaru ?? '',
      namaImunisasi: _txtNama.text.trim(),
      merkProdusen:
          _txtMerk.text.trim().isEmpty ? null : _txtMerk.text.trim(),
      dosis: _txtDosis.text.trim().isEmpty ? null : _txtDosis.text.trim(),
      usiaPemberian:
          _txtUsia.text.trim().isEmpty ? null : _txtUsia.text.trim(),
      kategori: _kategori,
    );
    try {
      await GrowTrackDB.simpanVaksin(v, baru: !_modeUbah);
      if (!mounted) return;
      tampilSnack(context,
          _modeUbah ? 'Data vaksin berhasil diubah!' : 'Data vaksin tersimpan!');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Gagal menyimpan data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_modeUbah ? 'Ubah Vaksin' : 'Tambah Vaksin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            enabled: false,
            decoration: dekorasiInput(
                'ID Vaksin (Auto): ${widget.vaksin?.idImunisasi ?? _idBaru ?? '...'}'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtNama,
            decoration:
                dekorasiInput('Nama Vaksin', ikon: Icons.vaccines_outlined),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtMerk,
            decoration: dekorasiInput('Merk / Produsen',
                ikon: Icons.factory_outlined),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtDosis,
            decoration: dekorasiInput('Dosis', ikon: Icons.medication_outlined),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtUsia,
            decoration: dekorasiInput('Usia Pemberian',
                ikon: Icons.cake_outlined, hint: 'cth: 2 bulan'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _kategori,
            decoration: dekorasiInput('Kategori'),
            items: const ['Wajib', 'Lanjutan', 'Pilihan']
                .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                .toList(),
            onChanged: (v) => setState(() => _kategori = v ?? 'Wajib'),
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
