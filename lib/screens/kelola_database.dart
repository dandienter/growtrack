import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database.dart';
import '../session.dart';
import '../widgets.dart';
import 'login.dart';

/// Port tampilan/FormKelolaDatabase.java untuk SQLite lokal:
/// lihat isi tabel, edit sel langsung, hapus baris, backup dan restore.
class KelolaDatabaseScreen extends StatefulWidget {
  const KelolaDatabaseScreen({super.key});

  @override
  State<KelolaDatabaseScreen> createState() => _KelolaDatabaseScreenState();
}

class _KelolaDatabaseScreenState extends State<KelolaDatabaseScreen> {
  String _tabelDipilih = GrowTrackDB.daftarTabel.first;
  String _jalurDb = '';
  List<String> _kolom = [];
  List<Map<String, Object?>> _baris = [];
  String? _kolomPk;
  bool _memuat = true;
  bool _proses = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final jalur = await GrowTrackDB.jalurDb();
    final info = await GrowTrackDB.infoTabel(_tabelDipilih);
    final isi = await GrowTrackDB.ambilIsiTabel(_tabelDipilih);
    if (!mounted) return;
    setState(() {
      _jalurDb = jalur;
      _kolom = info.kolom;
      _kolomPk = info.pk;
      _baris = isi;
      _memuat = false;
    });
  }

  String _teksSel(Object? v) => v?.toString() ?? 'NULL';

  Future<void> _editSel(Map<String, Object?> baris, String kolom) async {
    if (_kolomPk == null) {
      tampilSnack(context, 'Tabel ini tidak memiliki Primary Key!');
      return;
    }
    final nilaiAwal = baris[kolom];
    final txt = TextEditingController(text: nilaiAwal?.toString() ?? '');
    final simpan = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $kolom'),
        content: TextField(
          controller: txt,
          autofocus: true,
          maxLines: 3,
          decoration: dekorasiInput('Nilai baru (kosong = NULL)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (simpan != true) return;
    final baru = txt.text.isEmpty ? null : txt.text;
    try {
      await GrowTrackDB.ubahSelTabel(
          _tabelDipilih, kolom, baru, _kolomPk!, baris[_kolomPk]);
      if (!mounted) return;
      tampilSnack(context, 'Data diperbarui!');
      _muat();
    } catch (e) {
      if (mounted) tampilSnack(context, 'Edit Gagal: $e');
    }
  }

  Future<void> _hapusBaris(Map<String, Object?> baris) async {
    if (_kolomPk == null) {
      tampilSnack(context, 'Tabel ini tidak memiliki Primary Key!');
      return;
    }
    final yakin = await tampilKonfirmasi(
      context,
      judul: 'Konfirmasi',
      pesan:
          "Hapus baris ini dari '$_tabelDipilih'?\nTindakan tidak bisa dibatalkan!",
      teksYa: 'Ya, Hapus',
    );
    if (!yakin) return;
    try {
      await GrowTrackDB.hapusBarisTabel(
          _tabelDipilih, _kolomPk!, baris[_kolomPk]);
      if (!mounted) return;
      tampilSnack(context, 'Baris dihapus!');
      _muat();
    } catch (e) {
      if (mounted) tampilSnack(context, 'Hapus Gagal: $e');
    }
  }

  Future<void> _backup() async {
    setState(() => _proses = true);
    try {
      final berkas = await GrowTrackDB.siapkanBerkasBackup();
      await Share.shareXFiles(
        [XFile(berkas.path)],
        text: 'Backup Database GrowTrack',
      );
      if (!mounted) return;
      tampilSnack(context,
          'Backup dibuat: ${berkas.path.split(Platform.pathSeparator).last}');
    } catch (e) {
      if (mounted) tampilSnack(context, 'Backup Gagal: $e');
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _restore() async {
    final yakin = await tampilKonfirmasi(
      context,
      judul: 'Peringatan Restore',
      pesan:
          'Restore akan MENGGANTI seluruh database saat ini!\nPastikan sudah backup dulu.\nLanjutkan?',
      teksYa: 'Ya, Lanjutkan',
    );
    if (!yakin) return;
    final hasil = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (hasil == null || hasil.files.single.path == null) return;
    setState(() => _proses = true);
    try {
      await GrowTrackDB.restoreDariBerkas(hasil.files.single.path!);
      SesiUser.logout();
      if (!mounted) return;
      tampilSnack(context, 'Database berhasil di-restore! Silakan login ulang.');
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _proses = false);
        tampilSnack(context, 'Restore Gagal: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Database')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File: $_jalurDb',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _tabelDipilih,
                  isExpanded: true,
                  decoration: dekorasiInput('Pilih Tabel'),
                  items: [
                    for (final t in GrowTrackDB.daftarTabel)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    _tabelDipilih = v;
                    _muat();
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  "Tabel '$_tabelDipilih': ${_baris.length} baris (maks 1000). "
                  'Ketuk sel untuk edit langsung.',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _proses ? null : _backup,
                        icon: const Icon(Icons.backup_outlined),
                        label: const Text('Backup Database'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _proses ? null : _restore,
                        icon: const Icon(Icons.restore_outlined),
                        label: const Text('Restore Database'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _memuat
                ? const Center(child: CircularProgressIndicator())
                : _baris.isEmpty
                    ? const TampilanKosong(pesan: 'Tabel ini kosong.')
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              const DataColumn(label: Text('#')),
                              for (final k in _kolom)
                                DataColumn(label: Text(k)),
                              const DataColumn(label: Text('Aksi')),
                            ],
                            rows: [
                              for (var i = 0; i < _baris.length; i++)
                                DataRow(cells: [
                                  DataCell(Text('${i + 1}')),
                                  for (final k in _kolom)
                                    DataCell(
                                      ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 150),
                                        child: Text(
                                          _teksSel(_baris[i][k]),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: _baris[i][k] == null
                                                ? const Color(0xFF94A3B8)
                                                : null,
                                            fontStyle: _baris[i][k] == null
                                                ? FontStyle.italic
                                                : null,
                                          ),
                                        ),
                                      ),
                                      onTap: () => _editSel(_baris[i], k),
                                    ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Color(0xFFEF4444)),
                                      onPressed: () => _hapusBaris(_baris[i]),
                                    ),
                                  ),
                                ]),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
