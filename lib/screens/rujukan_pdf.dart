import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../db/database.dart';
import '../format.dart';
import '../logic/gizi.dart';
import '../models.dart';

/// Surat rujukan anak dari posyandu ke Puskesmas: kop posyandu,
/// identitas anak, hasil pemeriksaan terakhir, alasan rujukan,
/// dan tanda tangan ketua posyandu.
class RujukanPdf {
  static final _fontBiasa = pw.Font.helvetica();
  static final _fontTebal = pw.Font.helveticaBold();

  static pw.TextStyle _gaya(double ukuran, {bool tebal = false}) =>
      pw.TextStyle(font: tebal ? _fontTebal : _fontBiasa, fontSize: ukuran);

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
    final kota =
        (pg.kota == null || pg.kota!.trim().isEmpty) ? 'Jakarta' : pg.kota!;
    final namaKetua = (pg.namaKetua == null || pg.namaKetua!.isEmpty)
        ? '.......................'
        : pg.namaKetua!;

    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/icon/posyandu-logo.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    final sekarang = DateTime.now();
    final nomor =
        'SR/${balita.idBalita}/${sekarang.month.toString().padLeft(2, '0')}/${sekarang.year}';
    final umur = balita.tglLahir.isNotEmpty
        ? '${hitungUmurBulan(parseTanggalDb(balita.tglLahir) ?? sekarang, sekarang)} bulan'
        : '-';

    pw.Widget baris(String label, String isi) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 130,
              child: pw.Text(label, style: _gaya(11)),
            ),
            pw.Text(': ', style: _gaya(11)),
            pw.Expanded(child: pw.Text(isi, style: _gaya(11))),
          ],
        ),
      );
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(56, 48, 56, 48),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logo != null)
                    pw.SizedBox(
                      width: 64,
                      height: 64,
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text(namaPosyandu,
                            style: _gaya(18, tebal: true),
                            textAlign: pw.TextAlign.center),
                        pw.SizedBox(height: 3),
                        pw.Text(alamat,
                            style: _gaya(10),
                            textAlign: pw.TextAlign.center),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: logo != null ? 64 : 0),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                  height: 2,
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.black)),
              pw.SizedBox(height: 18),
              pw.Center(
                child: pw.Text('SURAT RUJUKAN',
                    style: _gaya(15, tebal: true)),
              ),
              pw.Center(
                child: pw.Text('Nomor: $nomor', style: _gaya(11)),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Kepada Yth.', style: _gaya(11)),
              pw.Text('Kepala Puskesmas setempat',
                  style: _gaya(11, tebal: true)),
              pw.Text('di tempat', style: _gaya(11)),
              pw.SizedBox(height: 12),
              pw.Text(
                'Dengan hormat, bersama surat ini kami merujuk anak '
                'berikut untuk mendapatkan pemeriksaan dan penanganan '
                'lebih lanjut:',
                style: _gaya(11),
              ),
              pw.SizedBox(height: 10),
              baris('Nama Anak', balita.namaBalita),
              baris('Jenis Kelamin', balita.jenisKelaminLengkap),
              baris('Tanggal Lahir',
                  '${formatTanggalID(balita.tglLahir)} (umur $umur)'),
              baris('Nama Ayah', ortu?.namaAyah ?? balita.namaAyah ?? '-'),
              baris('Nama Ibu', ortu?.namaIbu ?? balita.namaIbu ?? '-'),
              baris('Alamat', ortu?.alamat ?? '-'),
              pw.SizedBox(height: 8),
              if (terakhir != null) ...[
                baris('Tanggal Periksa Terakhir',
                    formatTanggalID(terakhir.tanggal)),
                baris('Berat Badan', '${terakhir.beratBadan} kg'),
                baris('Tinggi Badan', '${terakhir.tinggiBadan} cm'),
                baris('Status Gizi', terakhir.statusGizi ?? '-'),
                baris('Z-Score BB/U', fmtZ(terakhir.zBbu)),
                baris('Z-Score TB/U', fmtZ(terakhir.zTbu)),
                baris('Z-Score BB/TB', fmtZ(terakhir.zBbtb)),
                pw.SizedBox(height: 8),
              ],
              pw.Text('Alasan Rujukan:', style: _gaya(11, tebal: true)),
              pw.SizedBox(height: 4),
              pw.Text(alasan, style: _gaya(11)),
              pw.SizedBox(height: 12),
              pw.Text(
                'Demikian surat rujukan ini kami buat. Atas perhatian dan '
                'kerja samanya kami ucapkan terima kasih.',
                style: _gaya(11),
              ),
              pw.SizedBox(height: 28),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                          '$kota, ${tanggalPanjangId(sekarang)}',
                          style: _gaya(11)),
                      pw.Text('Ketua Posyandu,', style: _gaya(11)),
                      pw.SizedBox(height: 52),
                      pw.Text('( $namaKetua )',
                          style: _gaya(11, tebal: true)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }
}
