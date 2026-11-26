import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../db/database.dart';
import '../format.dart';
import '../logic/gizi.dart';
import '../models.dart';

/// Surat rujukan anak dari posyandu ke Puskesmas dengan format surat
/// resmi yang sama seperti SuratRujukan desktop: kop posyandu garis
/// ganda, identitas anak, hasil pemeriksaan terakhir sebagai paragraf,
/// alasan rujukan, dan tanda tangan ketua posyandu.
class RujukanPdf {
  static final _fontBiasa = pw.Font.times();
  static final _fontTebal = pw.Font.timesBold();
  static final _fontMiring = pw.Font.timesItalic();

  static pw.TextStyle _gaya(double ukuran, {bool tebal = false}) =>
      pw.TextStyle(font: tebal ? _fontTebal : _fontBiasa, fontSize: ukuran);

  /// "POSYANDU BERINGIN DDN" -> "Posyandu Beringin DDN"
  /// (kata maksimal 3 huruf dianggap singkatan, tetap kapital).
  static String _judulKas(String teks) {
    return teks.split(RegExp(r'\s+')).map((kata) {
      if (kata.isEmpty) return kata;
      if (kata.length <= 3) return kata.toUpperCase();
      return kata[0].toUpperCase() + kata.substring(1).toLowerCase();
    }).join(' ');
  }

  static String _des1(num v) =>
      v.toStringAsFixed(1).replaceAll('.', ',');

  static Future<Uint8List> buat({
    required Balita balita,
    required Pemeriksaan? terakhir,
    required String alasan,
    OrangTua? ortu,
  }) async {
    final pg = await GrowTrackDB.ambilPengaturan();
    final namaPosyandu = (pg.namaPosyandu ?? 'POSYANDU').toUpperCase();
    final alamat =
        (pg.alamat == null || pg.alamat!.isEmpty) ? '-' : pg.alamat!;
    final telp =
        (pg.noTelepon == null || pg.noTelepon!.isEmpty) ? '-' : pg.noTelepon!;
    final kota =
        (pg.kota == null || pg.kota!.trim().isEmpty) ? 'Jakarta' : pg.kota!;
    final namaKetua = (pg.namaKetua == null || pg.namaKetua!.isEmpty)
        ? '.......................'
        : pg.namaKetua!;

    pw.MemoryImage? logo;
    final logoPath = pg.logoPath;
    if (logoPath != null && logoPath.isNotEmpty) {
      final berkasLogo = File(logoPath);
      if (await berkasLogo.exists()) {
        try {
          logo = pw.MemoryImage(await berkasLogo.readAsBytes());
        } catch (_) {}
      }
    }
    if (logo == null) {
      try {
        final data = await rootBundle.load('assets/icon/posyandu-logo.png');
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {}
    }

    final sekarang = DateTime.now();
    final nomor =
        'SR/${balita.idBalita}/${sekarang.month.toString().padLeft(2, '0')}/${sekarang.year}';
    final lahir = parseTanggalDb(balita.tglLahir);
    final umurBulan =
        lahir != null ? hitungUmurBulan(lahir, sekarang) : null;
    final namaPosyanduKas = _judulKas(namaPosyandu);
    final ukuranKop = namaPosyandu.length > 30
        ? 13.0
        : (namaPosyandu.length > 20 ? 15.0 : 17.0);

    pw.Widget baris(String label, String isi) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 130, child: pw.Text(label, style: _gaya(11))),
            pw.Text(': ', style: _gaya(11)),
            pw.Expanded(child: pw.Text(isi, style: _gaya(11))),
          ],
        ),
      );
    }

    final teksKop = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(namaPosyandu,
            style: _gaya(ukuranKop, tebal: true),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2),
        pw.Text(alamat, style: _gaya(10.5), textAlign: pw.TextAlign.center),
        pw.Text('Telp: $telp',
            style: _gaya(10.5), textAlign: pw.TextAlign.center),
      ],
    );

    final widgets = <pw.Widget>[
      if (logo != null)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(
              width: 64,
              height: 64,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
            pw.Expanded(child: teksKop),
            pw.SizedBox(width: 64),
          ],
        )
      else
        teksKop,
      pw.SizedBox(height: 6),
      pw.Container(
          height: 1.4,
          decoration: const pw.BoxDecoration(color: PdfColors.black)),
      pw.SizedBox(height: 1.5),
      pw.Container(
          height: 0.5,
          decoration: const pw.BoxDecoration(color: PdfColors.black)),
      pw.SizedBox(height: 14),
      pw.Center(
        child: pw.Text('SURAT RUJUKAN', style: _gaya(13, tebal: true)),
      ),
      pw.SizedBox(height: 3),
      pw.Center(child: pw.Text('Nomor: $nomor', style: _gaya(10.5))),
      pw.SizedBox(height: 14),
      pw.Text('$kota, ${tanggalPanjangId(sekarang)}', style: _gaya(11)),
      pw.SizedBox(height: 10),
      pw.Text('Kepada Yth.', style: _gaya(11)),
      pw.Text('Kepala Puskesmas setempat', style: _gaya(11, tebal: true)),
      pw.Text('di tempat', style: _gaya(11)),
      pw.SizedBox(height: 10),
      pw.Text('Dengan hormat,', style: _gaya(11)),
      pw.SizedBox(height: 6),
      pw.Text(
        'Bersama surat ini, kami merujuk pasien balita dari '
        '$namaPosyanduKas untuk mendapatkan pemeriksaan dan penanganan '
        'lebih lanjut di Puskesmas, dengan data sebagai berikut:',
        style: _gaya(11),
      ),
      pw.SizedBox(height: 10),
      baris('Nama Balita', balita.namaBalita),
      baris('Jenis Kelamin', balita.jenisKelaminLengkap),
      baris('Tanggal Lahir',
          lahir != null ? tanggalPanjangId(lahir) : formatTanggalID(balita.tglLahir)),
      baris('Usia', umurBulan != null ? '$umurBulan Bulan' : '-'),
      baris('Nama Ibu', ortu?.namaIbu ?? balita.namaIbu ?? '-'),
      baris('Alamat', ortu?.alamat ?? '-'),
      pw.SizedBox(height: 8),
      if (terakhir != null)
        pw.Text(
          'Hasil pemeriksaan terakhir di posyandu '
          '(${tanggalPanjangId(parseTanggalDb(terakhir.tanggal) ?? sekarang)}): '
          'berat badan ${_des1(terakhir.beratBadan)} kg, '
          'tinggi badan ${_des1(terakhir.tinggiBadan)} cm'
          '${terakhir.lingkarKepala > 0 ? ', lingkar kepala ${_des1(terakhir.lingkarKepala)} cm' : ''}.',
          style: _gaya(11),
        ),
      if (terakhir != null) pw.SizedBox(height: 8),
      pw.Text(
        'Alasan rujukan: ${alasan.isEmpty ? '-' : alasan[0].toLowerCase() + alasan.substring(1)}',
        style: _gaya(11),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'Demikian surat rujukan ini kami buat. Atas perhatian dan kerja '
        'samanya, kami ucapkan terima kasih.',
        style: _gaya(11),
      ),
      pw.SizedBox(height: 26),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('Hormat kami,', style: _gaya(11)),
              pw.Text('Ketua $namaPosyanduKas', style: _gaya(11)),
              pw.SizedBox(height: 52),
              pw.RichText(
                text: pw.TextSpan(
                  style: _gaya(11),
                  children: [
                    const pw.TextSpan(text: '( '),
                    pw.TextSpan(
                      text: namaKetua,
                      style: pw.TextStyle(
                        font: _fontBiasa,
                        fontSize: 11,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    const pw.TextSpan(text: ' )'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ];

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: _fontBiasa,
        bold: _fontTebal,
        italic: _fontMiring,
      ),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(57, 51, 57, 54),
        footer: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Dicetak dari Sistem GrowTrack',
              style: pw.TextStyle(font: _fontMiring, fontSize: 8.5),
            ),
            pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: pw.TextStyle(font: _fontMiring, fontSize: 8.5),
            ),
          ],
        ),
        build: (pw.Context context) => widgets,
      ),
    );
    return doc.save();
  }
}
