import 'package:flutter/material.dart';

import '../db/database.dart';
import '../format.dart';
import '../models.dart';
import '../session.dart';
import '../sync/sync_service.dart';
import '../widgets.dart';
import 'edukasi.dart';

/// Kelola konten buatan kader: materi edukasi dan pengumuman yang
/// tersinkron ke aplikasi orang tua lewat sinkronisasi awan.
class KelolaKontenScreen extends StatefulWidget {
  const KelolaKontenScreen({super.key});

  @override
  State<KelolaKontenScreen> createState() => _KelolaKontenScreenState();
}

class _KelolaKontenScreenState extends State<KelolaKontenScreen> {
  List<Konten> _daftar = [];
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final d = await GrowTrackDB.ambilKonten();
    if (mounted) {
      setState(() {
        _daftar = d;
        _memuat = false;
      });
    }
  }

  Future<void> _form({Konten? awal}) async {
    final hasil = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FormKontenScreen(awal: awal)),
    );
    if (hasil == true) {
      _muat();
      // Dorong ke awan sekarang juga bila sedang daring.
      LayananSinkron.sinkronkan();
    }
  }

  Future<void> _hapus(Konten k) async {
    final yakin = await tampilKonfirmasi(
      context,
      judul: 'Hapus Konten',
      isi: 'Hapus "${k.judul}"? Konten ini juga hilang dari aplikasi orang tua setelah sinkronisasi.',
      teksYa: 'Hapus',
      teksTidak: 'Batal',
    );
    if (!yakin) return;
    await GrowTrackDB.hapusKonten(k.idKonten);
    LayananSinkron.sinkronkan();
    _muat();
    if (mounted) tampilSnack(context, 'Konten dihapus.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konten & Pengumuman')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.add),
        label: const Text('Buat Konten'),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : _daftar.isEmpty
              ? const TampilanKosong(
                  pesan:
                      'Belum ada konten. Ketuk Buat Konten untuk menulis materi edukasi atau pengumuman bagi orang tua.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: _daftar.length,
                  itemBuilder: (_, i) {
                    final k = _daftar[i];
                    final warna = k.isPengumuman
                        ? const Color(0xFFF59E0B)
                        : kTeal;
                    return AnimasiMasuk(
                      indeks: i,
                      child: Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: warna.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              k.isPengumuman
                                  ? Icons.campaign_outlined
                                  : Icons.menu_book_outlined,
                              color: warna,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            k.judul,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14.5),
                          ),
                          subtitle: Text(
                            '${k.isPengumuman ? 'Pengumuman' : 'Edukasi'} • ${k.tanggal != null ? formatTanggalID(k.tanggal!.substring(0, 10)) : '-'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'ubah') _form(awal: k);
                              if (v == 'lihat') {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        BacaKontenScreen(konten: k)));
                              }
                              if (v == 'hapus') _hapus(k);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'lihat', child: Text('Lihat')),
                              PopupMenuItem(value: 'ubah', child: Text('Ubah')),
                              PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                            ],
                          ),
                          onTap: () => _form(awal: k),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Form tulis/ubah konten.
class FormKontenScreen extends StatefulWidget {
  final Konten? awal;

  const FormKontenScreen({super.key, this.awal});

  @override
  State<FormKontenScreen> createState() => _FormKontenScreenState();
}

class _FormKontenScreenState extends State<FormKontenScreen> {
  final _judul = TextEditingController();
  final _ringkasan = TextEditingController();
  final _isi = TextEditingController();
  String _jenis = 'edukasi';
  bool _simpan = false;

  @override
  void initState() {
    super.initState();
    final a = widget.awal;
    if (a != null) {
      _jenis = a.jenis;
      _judul.text = a.judul;
      _ringkasan.text = a.ringkasan ?? '';
      _isi.text = a.isi;
    }
  }

  @override
  void dispose() {
    _judul.dispose();
    _ringkasan.dispose();
    _isi.dispose();
    super.dispose();
  }

  Future<void> _simpanKonten() async {
    if (_judul.text.trim().isEmpty || _isi.text.trim().isEmpty) {
      tampilSnack(context, 'Judul dan isi wajib diisi.');
      return;
    }
    setState(() => _simpan = true);
    final k = Konten(
      idKonten: widget.awal?.idKonten ?? '',
      jenis: _jenis,
      judul: _judul.text.trim(),
      ringkasan: _ringkasan.text.trim().isEmpty ? null : _ringkasan.text.trim(),
      isi: _isi.text.trim(),
      penulis: SesiUser.namaLengkap,
      tanggal: widget.awal?.tanggal,
    );
    if (widget.awal == null) {
      await GrowTrackDB.tambahKonten(k);
    } else {
      await GrowTrackDB.ubahKonten(k);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.awal == null ? 'Buat Konten' : 'Ubah Konten'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _jenis,
            decoration: dekorasiInput('JENIS KONTEN'),
            items: const [
              DropdownMenuItem(value: 'edukasi', child: Text('Edukasi')),
              DropdownMenuItem(value: 'pengumuman', child: Text('Pengumuman')),
            ],
            onChanged: (v) => setState(() => _jenis = v ?? 'edukasi'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _judul,
            decoration: dekorasiInput('JUDUL'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ringkasan,
            decoration: dekorasiInput('RINGKASAN (OPSIONAL)'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _isi,
            decoration: dekorasiInput('ISI').copyWith(
              alignLabelWithHint: true,
              hintText: 'Tulis isi lengkapnya. Baris kosong memisahkan paragraf.',
            ),
            textCapitalization: TextCapitalization.sentences,
            minLines: 8,
            maxLines: 16,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _simpan ? null : _simpanKonten,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: _simpan
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('SIMPAN & TERBITKAN'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Konten tersimpan di perangkat ini dan ikut terkirim ke aplikasi orang tua saat sinkronisasi berjalan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
