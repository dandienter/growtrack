import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../db/database.dart';
import '../models.dart';
import '../widgets.dart';
import 'laporan_pdf.dart';

/// Port tampilan/DialogLaporan.java: parameter laporan lalu pratinjau PDF.
class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  String _jenis = kJenisLaporan[0];
  bool _pakaiFilter = false;
  DateTime? _dari;
  DateTime? _sampai = DateTime.now();
  Balita? _balitaDipilih;
  Map<String, String>? _rtDipilih;

  List<Balita> _daftarBalita = [];
  List<Map<String, String>> _daftarRt = [];
  bool _membuat = false;

  bool get _perBalita => _jenis == kJenisLaporan[4];
  bool get _pmt => _jenis == kJenisLaporan[3];

  @override
  void initState() {
    super.initState();
    _dari = DateTime.now().subtract(const Duration(days: 30));
    _muatPilihan();
  }

  Future<void> _muatPilihan() async {
    final balita = await GrowTrackDB.ambilBalita();
    final rt = await GrowTrackDB.ambilDaftarRt();
    if (!mounted) return;
    setState(() {
      _daftarBalita = balita;
      _daftarRt = rt;
      if (_daftarRt.length == 1) _rtDipilih = _daftarRt.first;
      if (_daftarBalita.isNotEmpty) _balitaDipilih = _daftarBalita.first;
    });
  }

  Future<void> _cetak() async {
    if (_pakaiFilter) {
      if (_dari == null || _sampai == null) {
        tampilSnack(context, 'Silakan lengkapi rentang Tanggal Dari & Sampai!');
        return;
      }
      if (_dari!.isAfter(_sampai!)) {
        tampilSnack(
            context, "Tanggal 'Dari' tidak boleh melebihi Tanggal 'Sampai'!");
        return;
      }
    }
    if (_perBalita && _balitaDipilih == null) {
      tampilSnack(context, 'Pilih Balita terlebih dahulu dengan benar!');
      return;
    }
    setState(() => _membuat = true);
    try {
      final par = ParameterLaporan(
        jenis: _jenis,
        pakaiFilter: _pakaiFilter,
        dari: _dari,
        sampai: _sampai,
        balita: _perBalita ? _balitaDipilih : null,
        rt: _pmt ? _rtDipilih : null,
      );
      final bytes = await LaporanPdf.buat(par);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PratinjauLaporanScreen(
            judul: _jenis,
            namaBerkas: '${_jenis.replaceAll(' ', '_')}.pdf',
            bytes: bytes,
          ),
        ),
      );
    } catch (e) {
      if (mounted) tampilSnack(context, 'Gagal membuat PDF: $e');
    } finally {
      if (mounted) setState(() => _membuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('JENIS LAPORAN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _jenis,
            isExpanded: true,
            decoration: dekorasiInput(''),
            items: [
              for (final j in kJenisLaporan)
                DropdownMenuItem(value: j, child: Text(j)),
            ],
            onChanged: (v) => setState(() => _jenis = v!),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Gunakan Filter Rentang Tanggal'),
                  value: _pakaiFilter,
                  onChanged: (v) => setState(() => _pakaiFilter = v),
                ),
                if (_pakaiFilter)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: KolomTanggal(
                            label: 'Dari',
                            nilai: _dari,
                            onBerubah: (v) => setState(() => _dari = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: KolomTanggal(
                            label: 'Sampai',
                            nilai: _sampai,
                            onBerubah: (v) => setState(() => _sampai = v),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_pmt) ...[
            const SizedBox(height: 16),
            const Text('PILIH WILAYAH RT (KHUSUS LAPORAN PMT)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Map<String, String>?>(
              initialValue: _rtDipilih,
              isExpanded: true,
              decoration: dekorasiInput(''),
              items: [
                const DropdownMenuItem<Map<String, String>?>(
                  value: null,
                  child: Text('-- Semua Wilayah RT --'),
                ),
                for (final r in _daftarRt)
                  DropdownMenuItem(
                    value: r,
                    child: Text('${r['rt']} - ${r['penanggung_jawab']}'),
                  ),
              ],
              onChanged: (v) => setState(() => _rtDipilih = v),
            ),
          ],
          if (_perBalita) ...[
            const SizedBox(height: 16),
            const Text('PILIH BALITA (LAPORAN PERKEMBANGAN)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Balita>(
              initialValue: _balitaDipilih,
              isExpanded: true,
              decoration: dekorasiInput(''),
              items: [
                for (final b in _daftarBalita)
                  DropdownMenuItem(value: b, child: Text(b.namaBalita)),
              ],
              onChanged: (v) => setState(() => _balitaDipilih = v),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _membuat ? null : _cetak,
            icon: _membuat
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Tampilkan / Cetak PDF'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
          ),
        ],
      ),
    );
  }
}

class PratinjauLaporanScreen extends StatelessWidget {
  final String judul;
  final String namaBerkas;
  final Uint8List bytes;

  const PratinjauLaporanScreen({
    super.key,
    required this.judul,
    required this.namaBerkas,
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(judul)),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: namaBerkas,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}
