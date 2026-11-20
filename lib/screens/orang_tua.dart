import 'package:flutter/material.dart';

import '../db/database.dart';
import '../models.dart';
import '../widgets.dart';

/// Port tampilan/FormOrangTua.java: daftar + form data orang tua.
class OrangTuaListScreen extends StatefulWidget {
  const OrangTuaListScreen({super.key});

  @override
  State<OrangTuaListScreen> createState() => _OrangTuaListScreenState();
}

class _OrangTuaListScreenState extends State<OrangTuaListScreen> {
  List<OrangTua> _daftar = [];
  bool _memuat = true;
  String _cari = '';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final data = await GrowTrackDB.ambilOrangTua(cari: _cari);
    if (!mounted) return;
    setState(() {
      _daftar = data;
      _memuat = false;
    });
  }

  Future<void> _tambah() async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const OrangTuaFormScreen()),
    );
    if (simpan == true) _muat();
  }

  Future<void> _ubah(OrangTua o) async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => OrangTuaFormScreen(ortu: o)),
    );
    if (simpan == true) _muat();
  }

  Future<void> _hapus(OrangTua o) async {
    // P-8 desktop: blokir bila masih ada balita terdaftar
    final jmlAnak = await GrowTrackDB.hitungBalitaDariOrtu(o.idOrtu);
    if (!mounted) return;
    if (jmlAnak > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Peringatan'),
          content: Text(
              'Tidak bisa dihapus! Masih ada $jmlAnak balita terdaftar atas nama orang tua ini.\nHapus/pindahkan dulu data balitanya.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    final yakin = await tampilKonfirmasi(
      context,
      judul: 'Konfirmasi',
      pesan: 'Yakin ingin menghapus data orang tua ini?',
      teksYa: 'Ya, Hapus',
    );
    if (!yakin) return;
    await GrowTrackDB.hapusOrangTua(o.idOrtu);
    if (!mounted) return;
    tampilSnack(context, 'Data berhasil dihapus!');
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Orang Tua')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          KotakCari(
            hint: 'Cari nama ayah / ibu / no. HP...',
            onBerubah: (v) {
              _cari = v;
              _muat();
            },
          ),
          Expanded(
            child: _memuat
                ? const Center(child: CircularProgressIndicator())
                : _daftar.isEmpty
                    ? const TampilanKosong(pesan: 'Belum ada data orang tua.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _daftar.length,
                        itemBuilder: (_, i) {
                          final o = _daftar[i];
                          return AnimasiMasuk(indeks: i, child: Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            child: ListTile(
                              leading: AvatarKarakter.ibu(nama: o.namaIbu),
                              title: Text('Ibu: ${o.namaIbu}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Ayah: ${o.namaAyah}\n'
                                '${o.pekerjaan ?? '-'} • ${o.noHp ?? '-'}\n'
                                '${o.alamat ?? '-'}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'ubah') _ubah(o);
                                  if (v == 'hapus') _hapus(o);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'ubah', child: Text('Ubah')),
                                  PopupMenuItem(
                                      value: 'hapus', child: Text('Hapus')),
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

class OrangTuaFormScreen extends StatefulWidget {
  final OrangTua? ortu;
  const OrangTuaFormScreen({super.key, this.ortu});

  @override
  State<OrangTuaFormScreen> createState() => _OrangTuaFormScreenState();
}

class _OrangTuaFormScreenState extends State<OrangTuaFormScreen> {
  final _txtAyah = TextEditingController();
  final _txtIbu = TextEditingController();
  final _txtPekerjaan = TextEditingController();
  final _txtHp = TextEditingController();
  final _txtAlamat = TextEditingController();
  String? _idBaru;

  bool get _modeUbah => widget.ortu != null;

  @override
  void initState() {
    super.initState();
    final o = widget.ortu;
    if (o != null) {
      _txtAyah.text = o.namaAyah;
      _txtIbu.text = o.namaIbu;
      _txtPekerjaan.text = o.pekerjaan ?? '';
      _txtHp.text = o.noHp ?? '';
      _txtAlamat.text = o.alamat ?? '';
    } else {
      _siapkanId();
    }
  }

  Future<void> _siapkanId() async {
    final id = await GrowTrackDB.buatId('orang_tua', 'id_ortu', 'ORT-');
    if (mounted) setState(() => _idBaru = id);
  }

  @override
  void dispose() {
    _txtAyah.dispose();
    _txtIbu.dispose();
    _txtPekerjaan.dispose();
    _txtHp.dispose();
    _txtAlamat.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_txtAyah.text.trim().isEmpty || _txtIbu.text.trim().isEmpty) {
      tampilSnack(context, 'Nama Ayah dan Nama Ibu wajib diisi!');
      return;
    }
    final o = OrangTua(
      idOrtu: widget.ortu?.idOrtu ?? _idBaru ?? '',
      namaAyah: _txtAyah.text.trim(),
      namaIbu: _txtIbu.text.trim(),
      pekerjaan: _txtPekerjaan.text.trim().isEmpty
          ? null
          : _txtPekerjaan.text.trim(),
      noHp: _txtHp.text.trim().isEmpty ? null : _txtHp.text.trim(),
      alamat: _txtAlamat.text.trim().isEmpty ? null : _txtAlamat.text.trim(),
    );
    try {
      await GrowTrackDB.simpanOrangTua(o, baru: !_modeUbah);
      if (!mounted) return;
      tampilSnack(
          context, _modeUbah ? 'Data berhasil diubah!' : 'Data berhasil disimpan!');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Gagal menyimpan data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_modeUbah ? 'Ubah Orang Tua' : 'Tambah Orang Tua'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            enabled: false,
            decoration: dekorasiInput(
                'ID Orang Tua (Auto): ${widget.ortu?.idOrtu ?? _idBaru ?? '...'}'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtIbu,
            decoration: dekorasiInput('Nama Ibu', ikon: Icons.person_outline),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtAyah,
            decoration: dekorasiInput('Nama Ayah', ikon: Icons.person_outline),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtPekerjaan,
            decoration: dekorasiInput('Pekerjaan', ikon: Icons.work_outline),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtHp,
            keyboardType: TextInputType.phone,
            decoration:
                dekorasiInput('No. HP', ikon: Icons.phone_android_outlined),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtAlamat,
            maxLines: 3,
            decoration:
                dekorasiInput('Alamat', ikon: Icons.home_outlined),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _simpan,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan'),
            style:
                FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
          ),
        ],
      ),
    );
  }
}
