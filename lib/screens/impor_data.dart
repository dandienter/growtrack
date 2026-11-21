import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../db/database.dart';
import '../models.dart';
import '../sync/sync_service.dart';
import '../widgets.dart';

/// Impor data orang tua atau balita dari berkas CSV / XLSX.
/// Baris pertama berkas adalah judul kolom; nama kolom fleksibel
/// (tidak peka huruf besar dan spasi). Baris yang tidak lolos
/// pemeriksaan ditampilkan alasannya dan tidak ikut diimpor.
class ImporDataScreen extends StatefulWidget {
  final bool orangTua;

  const ImporDataScreen({super.key, required this.orangTua});

  @override
  State<ImporDataScreen> createState() => _ImporDataScreenState();
}

class _BarisSiap {
  final Map<String, String> sel;
  _BarisSiap(this.sel);
}

class _ImporDataScreenState extends State<ImporDataScreen> {
  final List<_BarisSiap> _siap = [];
  final List<String> _masalah = [];
  String? _namaBerkas;
  bool _memproses = false;

  String get _judul => widget.orangTua ? 'Impor Orang Tua' : 'Impor Balita';

  List<String> get _kolomWajib => widget.orangTua
      ? const ['nama_ibu']
      : const ['nama', 'jenis_kelamin', 'tanggal_lahir', 'nama_ibu'];

  String get _penjelasan => widget.orangTua
      ? 'Kolom yang dikenali: nama_ayah, nama_ibu (wajib), pekerjaan, '
          'no_hp, alamat. Satu baris untuk satu keluarga.'
      : 'Kolom yang dikenali: nama (wajib), jenis_kelamin (wajib, isi L '
          'atau P), tanggal_lahir (wajib, format 2024-03-15 atau '
          '15/03/2024), berat_lahir (kg), tinggi_lahir (cm), nama_ibu '
          '(wajib, harus sama persis dengan data orang tua yang sudah '
          'ada). Impor orang tua dulu sebelum impor balita.';

  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _ambil(Map<String, String> baris, List<String> kunci) {
    for (final k in kunci) {
      final v = baris[k];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  String _selKeTeks(CellValue? v) {
    if (v == null) return '';
    if (v is TextCellValue) return v.value.toString();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final d = v.value;
      return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
    }
    if (v is DateCellValue) {
      return '${v.year}-${v.month.toString().padLeft(2, '0')}-'
          '${v.day.toString().padLeft(2, '0')}';
    }
    if (v is TimeCellValue) return '';
    return v.toString();
  }

  List<List<String>> _uraiCsv(String teks) {
    final hasil = <List<String>>[];
    var baris = <String>[];
    var sel = StringBuffer();
    var dalamKutip = false;
    final t = teks.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (var i = 0; i < t.length; i++) {
      final c = t[i];
      if (dalamKutip) {
        if (c == '"') {
          if (i + 1 < t.length && t[i + 1] == '"') {
            sel.write('"');
            i++;
          } else {
            dalamKutip = false;
          }
        } else {
          sel.write(c);
        }
      } else if (c == '"') {
        dalamKutip = true;
      } else if (c == ',') {
        baris.add(sel.toString());
        sel = StringBuffer();
      } else if (c == '\n') {
        baris.add(sel.toString());
        sel = StringBuffer();
        hasil.add(baris);
        baris = <String>[];
      } else {
        sel.write(c);
      }
    }
    baris.add(sel.toString());
    if (baris.any((e) => e.trim().isNotEmpty)) hasil.add(baris);
    return hasil;
  }

  List<List<String>> _uraiXlsx(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final namaSheet = excel.getDefaultSheet() ?? excel.tables.keys.first;
    final sheet = excel.tables[namaSheet];
    if (sheet == null) return const [];
    final hasil = <List<String>>[];
    for (final row in sheet.rows) {
      hasil.add([for (final sel in row) _selKeTeks(sel?.value)]);
    }
    return hasil;
  }

  String? _normalTanggal(String mentah) {
    final t = mentah.trim();
    if (t.isEmpty) return null;
    final polaIso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})');
    final mIso = polaIso.firstMatch(t);
    if (mIso != null) {
      return '${mIso.group(1)}-${mIso.group(2)!.padLeft(2, '0')}-'
          '${mIso.group(3)!.padLeft(2, '0')}';
    }
    final polaDmy = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})');
    final mDmy = polaDmy.firstMatch(t);
    if (mDmy != null) {
      return '${mDmy.group(3)}-${mDmy.group(2)!.padLeft(2, '0')}-'
          '${mDmy.group(1)!.padLeft(2, '0')}';
    }
    return null;
  }

  Future<void> _pilihBerkas() async {
    setState(() => _memproses = true);
    try {
      final hasil = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
      );
      if (hasil.isEmpty) return;
      final berkas = hasil.first;
      final jalur = berkas.path;
      if (jalur == null) {
        if (mounted) tampilSnack(context, 'Berkas tidak bisa dibaca.');
        return;
      }
      final bytes = await File(jalur).readAsBytes();
      final List<List<String>> mentah =
          (berkas.extension ?? '').toLowerCase() == 'xlsx'
              ? _uraiXlsx(bytes)
              : _uraiCsv(utf8.decode(bytes, allowMalformed: true));
      _prosesBaris(mentah);
      setState(() => _namaBerkas = berkas.name);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Gagal membaca berkas: $e');
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
  }

  void _prosesBaris(List<List<String>> mentah) {
    _siap.clear();
    _masalah.clear();
    if (mentah.isEmpty) {
      _masalah.add('Berkas kosong.');
      return;
    }
    final kepala = [for (final h in mentah.first) _norm(h)];
    for (var i = 1; i < mentah.length; i++) {
      final selMentah = mentah[i];
      if (selMentah.every((e) => e.trim().isEmpty)) continue;
      final baris = <String, String>{};
      for (var j = 0; j < kepala.length && j < selMentah.length; j++) {
        if (kepala[j].isNotEmpty) baris[kepala[j]] = selMentah[j];
      }
      final nomor = i + 1;
      if (widget.orangTua) {
        final ibu = _ambil(baris, ['namaibu']);
        if (ibu.isEmpty) {
          _masalah.add('Baris $nomor: nama_ibu kosong.');
          continue;
        }
        _siap.add(_BarisSiap(baris));
      } else {
        final nama = _ambil(baris, ['nama', 'namabalita', 'namaanak']);
        final jkMentah =
            _ambil(baris, ['jeniskelamin', 'jk', 'kelamin']).toLowerCase();
        final jk = (jkMentah == 'l' || jkMentah.startsWith('laki'))
            ? 'L'
            : (jkMentah == 'p' || jkMentah.startsWith('perempuan'))
                ? 'P'
                : '';
        final tgl = _normalTanggal(
            _ambil(baris, ['tanggallahir', 'tgllahir', 'lahir']));
        final ibu = _ambil(baris, ['namaibu']);
        if (nama.isEmpty) {
          _masalah.add('Baris $nomor: nama anak kosong.');
          continue;
        }
        if (jk.isEmpty) {
          _masalah.add('Baris $nomor ($nama): jenis_kelamin harus L atau P.');
          continue;
        }
        if (tgl == null) {
          _masalah.add('Baris $nomor ($nama): tanggal_lahir tidak dikenal.');
          continue;
        }
        if (ibu.isEmpty) {
          _masalah.add('Baris $nomor ($nama): nama_ibu kosong.');
          continue;
        }
        baris['_nama'] = nama;
        baris['_jk'] = jk;
        baris['_tgl'] = tgl;
        _siap.add(_BarisSiap(baris));
      }
    }
    setState(() {});
  }

  double _angka(String s) =>
      double.tryParse(s.replaceAll(',', '.').trim()) ?? 0;

  Future<void> _imporSekarang() async {
    setState(() => _memproses = true);
    var sukses = 0;
    final gagal = <String>[];
    try {
      if (widget.orangTua) {
        for (final b in _siap) {
          try {
            final id =
                await GrowTrackDB.buatId('orang_tua', 'id_ortu', 'ORT-');
            await GrowTrackDB.simpanOrangTua(
              OrangTua(
                idOrtu: id,
                namaAyah: _ambil(b.sel, ['namaayah']),
                namaIbu: _ambil(b.sel, ['namaibu']),
                pekerjaan: _ambil(b.sel, ['pekerjaan']).isEmpty
                    ? null
                    : _ambil(b.sel, ['pekerjaan']),
                noHp: _ambil(b.sel, ['nohp', 'nohandphone', 'telepon',
                  'nohpwa', 'nomorhp']).isEmpty
                    ? null
                    : _ambil(b.sel,
                        ['nohp', 'nohandphone', 'telepon', 'nohpwa', 'nomorhp']),
                alamat: _ambil(b.sel, ['alamat']).isEmpty
                    ? null
                    : _ambil(b.sel, ['alamat']),
              ),
              baru: true,
            );
            sukses++;
          } catch (e) {
            gagal.add('Gagal menyimpan satu baris: $e');
          }
        }
      } else {
        final semuaOrtu = await GrowTrackDB.ambilOrangTua();
        final petaIbu = <String, String>{};
        for (final o in semuaOrtu) {
          petaIbu.putIfAbsent(o.namaIbu.trim().toLowerCase(), () => o.idOrtu);
        }
        final sekarang = DateTime.now();
        final tglDaftar = '${sekarang.year}-'
            '${sekarang.month.toString().padLeft(2, '0')}-'
            '${sekarang.day.toString().padLeft(2, '0')}';
        for (final b in _siap) {
          final nama = b.sel['_nama'] ?? '';
          final ibu = _ambil(b.sel, ['namaibu']);
          final idLangsung = _ambil(b.sel, ['idortu', 'idort']);
          final idOrtu = idLangsung.isNotEmpty
              ? idLangsung
              : petaIbu[ibu.trim().toLowerCase()];
          if (idOrtu == null) {
            gagal.add('$nama: ibu "$ibu" tidak ditemukan di data orang tua.');
            continue;
          }
          try {
            final id =
                await GrowTrackDB.buatId('balita', 'id_balita', 'BAL-');
            await GrowTrackDB.simpanBalita(
              Balita(
                idBalita: id,
                namaBalita: nama,
                jenisKelamin: b.sel['_jk'] ?? 'L',
                tglLahir: b.sel['_tgl'] ?? '',
                beratLahir:
                    _angka(_ambil(b.sel, ['beratlahir', 'bblahir'])),
                tinggiLahir:
                    _angka(_ambil(b.sel, ['tinggilahir', 'tblahir'])),
                idOrtu: idOrtu,
                tglDaftar: tglDaftar,
              ),
              baru: true,
            );
            sukses++;
          } catch (e) {
            gagal.add('$nama: gagal disimpan ($e)');
          }
        }
      }
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
    if (!mounted) return;
    if (sukses > 0) {
      LayananSinkron.sinkronkan();
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hasil Impor'),
        content: SingleChildScrollView(
          child: Text(
            '$sukses data berhasil diimpor.'
            '${gagal.isEmpty ? '' : '\n\nTidak terimpor:\n${gagal.map((g) => '- $g').join('\n')}'}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
    if (mounted && sukses > 0) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_judul)),
      backgroundColor: kLatar,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Card(
            color: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.upload_file, color: kTeal, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Format Berkas',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: kTinta),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Baris pertama berkas adalah judul kolom. $_penjelasan',
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.5, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kolom wajib: ${_kolomWajib.join(', ')}.',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: kTinta),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _memproses ? null : _pilihBerkas,
            icon: _memproses
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.folder_open, size: 18),
            label: Text(_namaBerkas == null
                ? 'Pilih Berkas CSV / XLSX'
                : 'Berkas: $_namaBerkas'),
          ),
          if (_siap.isNotEmpty || _masalah.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_siap.length} baris siap diimpor'
                      '${_masalah.isEmpty ? '' : ', ${_masalah.length} baris bermasalah'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: kTinta),
                    ),
                    if (_masalah.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final m in _masalah.take(12))
                        Text('- $m',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFB91C1C))),
                      if (_masalah.length > 12)
                        Text('... dan ${_masalah.length - 12} lainnya',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFB91C1C))),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  (_memproses || _siap.isEmpty) ? null : _imporSekarang,
              icon: const Icon(Icons.download_done, size: 18),
              label: Text('Impor ${_siap.length} Data Sekarang'),
            ),
          ],
        ],
      ),
    );
  }
}
