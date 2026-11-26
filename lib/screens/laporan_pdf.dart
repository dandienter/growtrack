import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../db/database.dart';
import '../format.dart';
import '../logic/gizi.dart';
import '../models.dart';
import '../session.dart';

/// Jenis laporan persis DialogLaporan desktop.
const List<String> kJenisLaporan = [
  'Laporan Data Balita Terdaftar',
  'Laporan Riwayat Pemeriksaan Keseluruhan',
  'Laporan Jadwal & Pelaksanaan Imunisasi',
  'Laporan Konsumsi PMT Warga',
  'Laporan Perkembangan per Balita',
  'Laporan Bulanan Puskesmas',
];

/// Parameter cetak laporan (padanan DialogLaporan).
class ParameterLaporan {
  final String jenis;
  final bool pakaiFilter;
  final DateTime? dari;
  final DateTime? sampai;
  final Balita? balita; // untuk Laporan Perkembangan per Balita
  final Map<String, String>? rt; // {rt, penanggung_jawab} untuk PMT

  const ParameterLaporan({
    required this.jenis,
    this.pakaiFilter = false,
    this.dari,
    this.sampai,
    this.balita,
    this.rt,
  });
}

/// Pembangun dokumen PDF laporan dengan kop surat posyandu,
/// port dari btnCetakActionPerformed pada DialogLaporan.java.
class LaporanPdf {
  static final _fontBiasa = pw.Font.times();
  static final _fontTebal = pw.Font.timesBold();
  static final _fontMiring = pw.Font.timesItalic();

  static pw.TextStyle _gaya(double ukuran, {bool tebal = false}) =>
      pw.TextStyle(font: tebal ? _fontTebal : _fontBiasa, fontSize: ukuran);

  /// Satu desimal koma Indonesia: 8.5 -> "8,5".
  static String _des1(num? v) =>
      v == null ? '-' : v.toStringAsFixed(1).replaceAll('.', ',');

  /// Z-score bertanda koma Indonesia: -2.31 -> "-2,31", 1.69 -> "+1,69".
  static String _zKoma(double? z) {
    if (z == null || z.isNaN) return '-';
    final s = z.toStringAsFixed(2).replaceAll('.', ',');
    return z > 0 ? '+$s' : s;
  }

  static pw.Widget _selHeader(String teks) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
      decoration: pw.BoxDecoration(color: PdfColor.fromHex('E8E8E8')),
      alignment: pw.Alignment.center,
      child: pw.Text(teks,
          style: _gaya(10, tebal: true), textAlign: pw.TextAlign.center),
    );
  }

  /// Nama penanda tangan di dalam kurung, nama saja yang bergaris bawah.
  static pw.Widget _teksNama(String nama) {
    return pw.RichText(
      textAlign: pw.TextAlign.center,
      text: pw.TextSpan(
        style: _gaya(11),
        children: [
          const pw.TextSpan(text: '( '),
          pw.TextSpan(
            text: nama,
            style: pw.TextStyle(
              font: _fontBiasa,
              fontSize: 11,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          const pw.TextSpan(text: ' )'),
        ],
      ),
    );
  }

  static pw.Widget _selIsi(String? teks) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
      alignment: pw.Alignment.center,
      child: pw.Text(teksDb(teks),
          style: _gaya(10.5), textAlign: pw.TextAlign.center),
    );
  }

  static Future<Uint8List> buat(ParameterLaporan par) async {
    final db = await GrowTrackDB.database;
    final pg = await GrowTrackDB.ambilPengaturan();

    final namaPosyandu = (pg.namaPosyandu ?? 'POSYANDU').toUpperCase();
    final alamat = (pg.alamat == null || pg.alamat!.isEmpty) ? '-' : pg.alamat!;
    final telp =
        (pg.noTelepon == null || pg.noTelepon!.isEmpty) ? '-' : pg.noTelepon!;
    final namaKetua = (pg.namaKetua == null || pg.namaKetua!.isEmpty)
        ? 'Kepala Posyandu'
        : pg.namaKetua!;
    final kota = (pg.kota == null || pg.kota!.trim().isEmpty)
        ? 'Jakarta'
        : pg.kota!.trim();

    pw.MemoryImage? logo;
    final logoPath = pg.logoPath;
    if (logoPath != null && logoPath.isNotEmpty) {
      final f = File(logoPath);
      if (await f.exists()) {
        try {
          logo = pw.MemoryImage(await f.readAsBytes());
        } catch (_) {}
      }
    }
    if (logo == null) {
      // Cadangan: logo resmi Posyandu dari aset aplikasi.
      try {
        final data = await rootBundle.load('assets/icon/posyandu-logo.png');
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {}
    }

    final ukuranKop =
        namaPosyandu.length > 30 ? 13.0 : (namaPosyandu.length > 20 ? 15.0 : 17.0);

    final widgets = <pw.Widget>[];

    // === KOP SURAT ===
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
    if (logo != null) {
      widgets.add(pw.Row(
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
      ));
    } else {
      widgets.add(teksKop);
    }
    widgets.add(pw.SizedBox(height: 6));
    widgets.add(pw.Container(
        height: 1.4, decoration: const pw.BoxDecoration(color: PdfColors.black)));
    widgets.add(pw.SizedBox(height: 1.5));
    widgets.add(pw.Container(
        height: 0.5, decoration: const pw.BoxDecoration(color: PdfColors.black)));
    widgets.add(pw.SizedBox(height: 12));

    String? rentangTeks;
    String? dariDb;
    String? sampaiDb;
    if (par.pakaiFilter && par.dari != null && par.sampai != null) {
      dariDb = keTeksDb(par.dari);
      sampaiDb = keTeksDb(par.sampai);
      rentangTeks =
          'Periode: ${tanggalPanjangId(par.dari!)} s/d ${tanggalPanjangId(par.sampai!)}';
    }

    void tambahJudul(String judul, {String? subTambahan, bool gabung = false}) {
      widgets.add(pw.Text(judul,
          style: _gaya(13, tebal: true), textAlign: pw.TextAlign.center));
      widgets.add(pw.SizedBox(height: 3));
      final sub = <String>[
        if (gabung && rentangTeks != null && subTambahan != null)
          '$rentangTeks - $subTambahan'
        else ...[
          if (rentangTeks != null) rentangTeks,
          if (subTambahan != null) subTambahan,
        ],
      ];
      if (sub.isNotEmpty) {
        widgets.add(pw.Text(sub.join('\n'),
            style: _gaya(10.5), textAlign: pw.TextAlign.center));
      }
      widgets.add(pw.SizedBox(height: 12));
    }

    pw.Table tabelDari(List<pw.Widget> headers, List<List<pw.Widget>> baris,
        Map<int, pw.TableColumnWidth> lebar) {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
        columnWidths: lebar,
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('E8E8E8')),
            children: headers,
          ),
          for (final b in baris) pw.TableRow(children: b),
        ],
      );
    }

    // === ISI PER JENIS LAPORAN ===
    if (par.jenis == kJenisLaporan[0]) {
      tambahJudul('LAPORAN DATA BALITA TERDAFTAR');
      var sql = 'SELECT * FROM balita';
      final args = <Object?>[];
      if (dariDb != null) {
        sql += ' WHERE tgl_daftar BETWEEN ? AND ?';
        args.addAll([dariDb, sampaiDb]);
      }
      sql += ' ORDER BY id_balita DESC';
      final rows = await db.rawQuery(sql, args);
      widgets.add(tabelDari(
        [
          _selHeader('ID Balita'),
          _selHeader('Nama Balita'),
          _selHeader('L/P'),
          _selHeader('Tanggal Daftar'),
          _selHeader('ID Orang Tua'),
        ],
        [
          for (final r in rows)
            [
              _selIsi(r['id_balita']?.toString()),
              _selIsi(r['nama_balita']?.toString()),
              _selIsi(r['jenis_kelamin']?.toString()),
              _selIsi(formatTanggalID(r['tgl_daftar']?.toString())),
              _selIsi(r['id_ortu']?.toString()),
            ],
        ],
        const {
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(4),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(3),
          4: pw.FlexColumnWidth(3),
        },
      ));
      final jmlL = rows.where((r) => r['jenis_kelamin'] == 'L').length;
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Text(
          'Total balita terdaftar: ${rows.length} anak '
          '($jmlL laki-laki, ${rows.length - jmlL} perempuan).',
          style: _gaya(10.5)));
    } else if (par.jenis == kJenisLaporan[1]) {
      tambahJudul('LAPORAN RIWAYAT PEMERIKSAAN KESELURUHAN');
      var sql = 'SELECT p.id_balita, b.nama_balita, p.tanggal, p.berat_badan, '
          'p.tinggi_badan, p.status_gizi FROM pemeriksaan p '
          'JOIN balita b ON p.id_balita = b.id_balita';
      final args = <Object?>[];
      if (dariDb != null) {
        sql += ' WHERE p.tanggal BETWEEN ? AND ?';
        args.addAll([dariDb, sampaiDb]);
      }
      sql += ' ORDER BY p.tanggal DESC';
      final rows = await db.rawQuery(sql, args);
      widgets.add(tabelDari(
        [
          _selHeader('Nama Balita'),
          _selHeader('Tanggal'),
          _selHeader('Berat (kg)'),
          _selHeader('Tinggi (cm)'),
          _selHeader('Status Gizi'),
        ],
        [
          for (final r in rows)
            [
              _selIsi(r['nama_balita']?.toString()),
              _selIsi(formatTanggalID(r['tanggal']?.toString())),
              _selIsi(_des1(r['berat_badan'] as num?)),
              _selIsi(_des1(r['tinggi_badan'] as num?)),
              _selIsi(r['status_gizi']?.toString()),
            ],
        ],
        const {
          0: pw.FlexColumnWidth(3.5),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(1.6),
          3: pw.FlexColumnWidth(1.6),
          4: pw.FlexColumnWidth(3.3),
        },
      ));
      final jmlBalita =
          rows.map((r) => r['id_balita']).toSet().length;
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Text(
          'Total pemeriksaan pada periode ini: ${rows.length} kali '
          'untuk $jmlBalita balita.',
          style: _gaya(10.5)));
    } else if (par.jenis == kJenisLaporan[2]) {
      tambahJudul('LAPORAN JADWAL & PELAKSANAAN IMUNISASI');
      var sql = 'SELECT j.id_jadwal, b.nama_balita, i.nama_imunisasi, '
          'j.tgl_diberikan, j.tgl_berikutnya, j.status '
          'FROM jadwal_imunisasi j '
          'JOIN balita b ON j.id_balita = b.id_balita '
          'JOIN imunisasi i ON j.id_imunisasi = i.id_imunisasi';
      final args = <Object?>[];
      if (dariDb != null) {
        sql +=
            ' WHERE (j.tgl_berikutnya BETWEEN ? AND ?) OR (j.tgl_diberikan BETWEEN ? AND ?)';
        args.addAll([dariDb, sampaiDb, dariDb, sampaiDb]);
      }
      sql += ' ORDER BY j.tgl_berikutnya ASC';
      final rows = await db.rawQuery(sql, args);
      widgets.add(tabelDari(
        [
          _selHeader('ID Jadwal'),
          _selHeader('Nama Balita'),
          _selHeader('Jenis Vaksin'),
          _selHeader('Diberikan'),
          _selHeader('Jadwal Next'),
          _selHeader('Status'),
        ],
        [
          for (final r in rows)
            [
              _selIsi(r['id_jadwal']?.toString()),
              _selIsi(r['nama_balita']?.toString()),
              _selIsi(r['nama_imunisasi']?.toString()),
              _selIsi(formatTanggalID(r['tgl_diberikan']?.toString())),
              _selIsi(formatTanggalID(r['tgl_berikutnya']?.toString())),
              _selIsi(r['status']?.toString()),
            ],
        ],
        const {
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(3.5),
          2: pw.FlexColumnWidth(2.5),
          3: pw.FlexColumnWidth(2),
          4: pw.FlexColumnWidth(2),
          5: pw.FlexColumnWidth(2),
        },
      ));
      final hitungStatus = <String, int>{};
      for (final r in rows) {
        final s = r['status']?.toString() ?? '-';
        hitungStatus[s] = (hitungStatus[s] ?? 0) + 1;
      }
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Text(
          'Ringkasan: ${hitungStatus.entries.map((e) => '${e.value} ${e.key}').join(', ')} '
          'pada periode ini.',
          style: _gaya(10.5)));
    } else if (par.jenis == kJenisLaporan[3]) {
      final rtDipilih = par.rt;
      final labelRt = rtDipilih != null
          ? 'Wilayah RT ${rtDipilih['rt']}'
          : 'Semua Wilayah RT';
      if (rentangTeks != null) {
        tambahJudul('LAPORAN KONSUMSI PMT WARGA',
            subTambahan: labelRt, gabung: true);
      } else {
        tambahJudul('LAPORAN KONSUMSI PMT WARGA',
            subTambahan: 'Semua periode - $labelRt');
      }
      var sql = 'SELECT id_konsumsi, tanggal, nama_kegiatan, pemberian_mt, '
          'jumlah_balita, total_biaya FROM konsumsi WHERE 1=1';
      final args = <Object?>[];
      if (dariDb != null) {
        sql += ' AND tanggal BETWEEN ? AND ?';
        args.addAll([dariDb, sampaiDb]);
      }
      if (rtDipilih != null) {
        sql += ' AND rt = ?';
        args.add(rtDipilih['rt']);
      }
      sql += ' ORDER BY tanggal DESC';
      final rows = await db.rawQuery(sql, args);
      var grandTotal = 0.0;
      final baris = <List<pw.Widget>>[];
      for (final r in rows) {
        final total = (r['total_biaya'] as num?)?.toDouble() ?? 0;
        grandTotal += total;
        baris.add([
          _selIsi(r['id_konsumsi']?.toString()),
          _selIsi(formatTanggalID(r['tanggal']?.toString())),
          _selIsi(r['nama_kegiatan']?.toString()),
          _selIsi(r['pemberian_mt']?.toString()),
          _selIsi('${(r['jumlah_balita'] as num?)?.toInt() ?? 0}'),
          _selIsi(formatRupiah(total)),
        ]);
      }
      widgets.add(tabelDari(
        [
          _selHeader('ID Konsumsi'),
          _selHeader('Tanggal'),
          _selHeader('Nama Kegiatan'),
          _selHeader('Pemberian MT'),
          _selHeader('Jml Balita'),
          _selHeader('Total Biaya'),
        ],
        baris,
        const {
          0: pw.FlexColumnWidth(2.5),
          1: pw.FlexColumnWidth(2.3),
          2: pw.FlexColumnWidth(3.2),
          3: pw.FlexColumnWidth(3.6),
          4: pw.FlexColumnWidth(2.2),
          5: pw.FlexColumnWidth(3.2),
        },
      ));
      widgets.add(pw.SizedBox(height: 6));
      widgets.add(pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
            'Total biaya PMT periode ini: ${formatRupiah(grandTotal)}',
            style: _gaya(10.5, tebal: true)),
      ));
    } else if (par.jenis == kJenisLaporan[4]) {
      final balita = par.balita!;
      tambahJudul('LAPORAN PERKEMBANGAN TUMBUH KEMBANG ANAK');

      final bio = await db.rawQuery(
        'SELECT b.nama_balita, b.jenis_kelamin, b.tgl_lahir, o.nama_ayah, '
        'o.nama_ibu, o.alamat FROM balita b '
        'JOIN orang_tua o ON b.id_ortu = o.id_ortu WHERE b.id_balita = ?',
        [balita.idBalita],
      );
      var namaAnak = balita.namaBalita;
      var jk = balita.jenisKelaminLengkap;
      var tglLahir = formatTanggalID(balita.tglLahir);
      var namaAyah = '-';
      var namaIbu = '-';
      var alamatAnak = '-';
      if (bio.isNotEmpty) {
        final r = bio.first;
        namaAnak = r['nama_balita']?.toString() ?? namaAnak;
        jk = r['jenis_kelamin']?.toString() == 'L' ? 'Laki-laki' : 'Perempuan';
        tglLahir = formatTanggalID(r['tgl_lahir']?.toString());
        namaAyah = r['nama_ayah']?.toString() ?? '-';
        namaIbu = r['nama_ibu']?.toString() ?? '-';
        alamatAnak = r['alamat']?.toString() ?? '-';
      }

      var tglPeriksaDisplay = '-';
      final rTgl = await db.rawQuery(
          'SELECT MAX(tanggal) AS last_tgl FROM pemeriksaan WHERE id_balita = ?',
          [balita.idBalita]);
      if (rTgl.isNotEmpty && rTgl.first['last_tgl'] != null) {
        tglPeriksaDisplay = formatTanggalID(rTgl.first['last_tgl']?.toString());
      }

      widgets.add(pw.Text('Biodata Anak & Orang Tua', style: _gaya(11.5, tebal: true)));
      widgets.add(pw.SizedBox(height: 5));
      pw.Widget bioBaris(String label, String nilai) {
        return pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 130, child: pw.Text(label, style: _gaya(11))),
            pw.Expanded(child: pw.Text(': $nilai', style: _gaya(11))),
          ],
        );
      }

      widgets.add(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          bioBaris('Nama Balita', namaAnak),
          bioBaris('Jenis Kelamin', jk),
          bioBaris('Tanggal Lahir', tglLahir),
          bioBaris('Nama Ayah', namaAyah),
          bioBaris('Nama Ibu', namaIbu),
          bioBaris('Alamat Lengkap', alamatAnak),
          bioBaris('Tanggal Pemeriksaan', tglPeriksaDisplay),
        ],
      ));
      widgets.add(pw.SizedBox(height: 14));
      widgets.add(
          pw.Text('Riwayat Pemeriksaan', style: _gaya(11.5, tebal: true)));
      widgets.add(pw.SizedBox(height: 5));

      var sql = 'SELECT tanggal, berat_badan, tinggi_badan, lingkar_kepala, '
          'posisi_ukur, z_bbu, z_tbu, z_bbtb, status_gizi, catatan_bidan '
          'FROM pemeriksaan WHERE id_balita = ?';
      final args = <Object?>[balita.idBalita];
      if (dariDb != null) {
        sql += ' AND tanggal BETWEEN ? AND ?';
        args.addAll([dariDb, sampaiDb]);
      }
      sql += ' ORDER BY tanggal ASC';
      final rows = await db.rawQuery(sql, args);

      final lahirPdf = parseTanggalDb(balita.tglLahir);
      final lakiPdf = isLaki(balita.jenisKelamin);

      String umurBaris(Map<String, Object?> r) {
        final tglP = parseTanggalDb(r['tanggal']?.toString());
        if (lahirPdf != null && tglP != null) {
          return '${hitungUmurBulan(lahirPdf, tglP)} Bulan';
        }
        return extractValue(r['catatan_bidan']?.toString(), '- Usia Anak:', '\n');
      }

      final baris = <List<pw.Widget>>[];
      for (final r in rows) {
        var posisiStr = r['posisi_ukur']?.toString() ?? '';
        if (posisiStr.isEmpty) {
          posisiStr =
              extractValue(r['catatan_bidan']?.toString(), '- Posisi Ukur:', '\n');
        }
        posisiStr =
            posisiStr.replaceAll(RegExp(r'\(.*?\)'), '').trim();
        baris.add([
          _selIsi(umurBaris(r)),
          _selIsi(_des1(r['berat_badan'] as num?)),
          _selIsi(_des1(r['tinggi_badan'] as num?)),
          _selIsi(_des1(r['lingkar_kepala'] as num?)),
          _selIsi(posisiStr.isEmpty ? '-' : posisiStr),
          _selIsi(r['status_gizi']?.toString()),
        ]);
      }

      widgets.add(tabelDari(
        [
          _selHeader('Usia'),
          _selHeader('BB (kg)'),
          _selHeader('TB (cm)'),
          _selHeader('LK (cm)'),
          _selHeader('Posisi'),
          _selHeader('Status Gizi'),
        ],
        baris,
        const {
          0: pw.FlexColumnWidth(1.6),
          1: pw.FlexColumnWidth(1.5),
          2: pw.FlexColumnWidth(1.5),
          3: pw.FlexColumnWidth(1.5),
          4: pw.FlexColumnWidth(2),
          5: pw.FlexColumnWidth(3.4),
        },
      ));

      if (rows.isNotEmpty && lahirPdf != null) {
        final terakhir = rows.last;
        final tglT = parseTanggalDb(terakhir['tanggal']?.toString());
        final umurT =
            tglT != null ? hitungUmurBulan(lahirPdf, tglT) : 0;
        final rawT = terakhir['catatan_bidan']?.toString();
        var catatanManualT = '-';
        if (rawT != null && rawT.contains('--- Catatan Manual ---')) {
          catatanManualT =
              rawT.substring(rawT.indexOf('--- Catatan Manual ---') + 22).trim();
        }
        if (catatanManualT.isEmpty) catatanManualT = '-';
        widgets.add(pw.SizedBox(height: 8));
        widgets.add(pw.Text(
            'Intervensi pemeriksaan terakhir ($umurT bulan): '
            'Vitamin A: ${extractValue(rawT, '- Kapsul Vit A:', '\n')}, '
            'obat cacing: ${extractValue(rawT, '- Obat Cacing:', '\n')}, '
            'imunisasi: ${extractValue(rawT, '- Imunisasi Diberikan:', '\n')}, '
            'ASI: ${extractValue(rawT, '- ASI Eksklusif:', '\n')}. '
            'Catatan khusus: $catatanManualT.',
            style: _gaya(10.5)));

        // === DETAIL ANTROPOMETRI PEMERIKSAAN TERAKHIR ===
        final bbT = (terakhir['berat_badan'] as num?)?.toDouble() ?? 0;
        final tbT = (terakhir['tinggi_badan'] as num?)?.toDouble() ?? 0;
        final lkT = (terakhir['lingkar_kepala'] as num?)?.toDouble() ?? 0;
        final korT = koreksiTinggi(
            tbT, umurT, terakhir['posisi_ukur']?.toString() ?? 'Berdiri');
        final det = hitungStatusGiziDetail(bbT, korT.tinggiKoreksi, umurT,
            balita.jenisKelamin,
            lingkarKepala: lkT);
        widgets.add(pw.SizedBox(height: 14));
        widgets.add(pw.Text(
            'Detail Antropometri - Pemeriksaan Terakhir '
            '(${formatTanggalID(terakhir['tanggal']?.toString())}, usia $umurT bulan)',
            style: _gaya(11.5, tebal: true)));
        widgets.add(pw.SizedBox(height: 5));
        final barisDetail = <List<pw.Widget>>[];
        if (umurT <= 60) {
          barisDetail.addAll([
            [
              _selIsi('BB/U - Berat Badan menurut Umur'),
              _selIsi('${_des1(bbT)} kg'),
              _selIsi('${_des1(medianBBU(umurT.toDouble(), lakiPdf))} kg'),
              _selIsi(_zKoma(det.zBBU)),
              _selIsi(det.statusBBU),
            ],
            [
              _selIsi('TB/U - Tinggi Badan menurut Umur'),
              _selIsi('${_des1(korT.tinggiKoreksi)} cm'),
              _selIsi('${_des1(medianTBU(umurT.toDouble(), lakiPdf))} cm'),
              _selIsi(_zKoma(det.zTBU)),
              _selIsi(det.statusTBU),
            ],
            [
              _selIsi('BB/TB - Berat Badan menurut Tinggi Badan'),
              _selIsi('${_des1(bbT)} kg'),
              _selIsi(
                  '${_des1(medianBBTB(korT.tinggiKoreksi, umurT.toDouble(), lakiPdf))} kg'),
              _selIsi(_zKoma(det.zBBTB)),
              _selIsi(det.statusBBTB),
            ],
            [
              _selIsi('LK/U - Lingkar Kepala menurut Umur'),
              _selIsi(lkT > 0 ? '${_des1(lkT)} cm' : '-'),
              _selIsi(medianLKU(umurT.toDouble(), lakiPdf).isNaN
                  ? '-'
                  : '${_des1(medianLKU(umurT.toDouble(), lakiPdf))} cm'),
              _selIsi(_zKoma(det.zLKU)),
              _selIsi(det.statusLKU),
            ],
          ]);
        } else {
          final nilaiImt = imt(bbT, tbT);
          barisDetail.addAll([
            [
              _selIsi('TB/U - Tinggi Badan menurut Umur'),
              _selIsi('${_des1(tbT)} cm'),
              _selIsi('-'),
              _selIsi(_zKoma(det.zTBU)),
              _selIsi(det.statusTBU),
            ],
            [
              _selIsi('IMT/U - IMT menurut Umur'),
              _selIsi(nilaiImt.isNaN ? '-' : _des1(nilaiImt)),
              _selIsi('-'),
              _selIsi(_zKoma(det.zIMTU)),
              _selIsi(det.statusIMTU),
            ],
            [
              _selIsi('LK/U - Lingkar Kepala menurut Umur'),
              _selIsi('-'),
              _selIsi('-'),
              _selIsi('-'),
              _selIsi('-'),
            ],
          ]);
        }
        widgets.add(tabelDari(
          [
            _selHeader('Indikator'),
            _selHeader('Nilai Aktual'),
            _selHeader('Median WHO'),
            _selHeader('Z-Score'),
            _selHeader('Kategori'),
          ],
          barisDetail,
          const {
            0: pw.FlexColumnWidth(3.05),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.4),
            3: pw.FlexColumnWidth(0.9),
            4: pw.FlexColumnWidth(1.95),
          },
        ));

        final statusT = terakhir['status_gizi']?.toString() ?? '';
        String isiInterpretasi;
        if (statusT.contains('Buruk')) {
          isiInterpretasi =
              'Status gizi terakhir $statusT. Anak memerlukan penanganan '
              'segera: rujuk ke Puskesmas untuk tata laksana gizi buruk dan '
              'pemberian PMT pemulihan sesuai petunjuk petugas kesehatan.';
        } else if (statusT.contains('Kurang')) {
          isiInterpretasi =
              'Status gizi terakhir $statusT. Tingkatkan asupan gizi '
              'seimbang dan protein hewani, manfaatkan PMT Posyandu, pantau '
              'pertumbuhan setiap bulan, dan konsultasikan ke Puskesmas '
              'bila tidak membaik dalam 2 bulan.';
        } else if (statusT.contains('Stunting') ||
            statusT.contains('Pendek')) {
          isiInterpretasi =
              'Status gizi terakhir $statusT. Perlu pemantauan tinggi '
              'badan berkala, asupan protein hewani yang cukup, dan '
              'stimulasi tumbuh kembang; konsultasikan ke Puskesmas '
              'untuk evaluasi lebih lanjut.';
        } else if (statusT.contains('Lebih') ||
            statusT.contains('Obesitas')) {
          isiInterpretasi =
              'Status gizi terakhir $statusT. Batasi makanan dan minuman '
              'manis serta makanan olahan, tingkatkan aktivitas fisik '
              'anak, dan pantau berat badan setiap bulan.';
        } else {
          isiInterpretasi =
              'Status gizi terakhir $statusT. Pertahankan pola makan gizi '
              'seimbang dan lakukan penimbangan rutin setiap bulan di '
              'Posyandu.';
        }
        final zLk = det.zLKU;
        if (umurT <= 60 && !zLk.isNaN && (zLk > 2 || zLk < -2)) {
          isiInterpretasi +=
              ' Nilai LK/U berada di ${zLk < -2 ? 'bawah' : 'atas'} rentang '
              'normal, mohon dipastikan kembali ketepatan pengukuran '
              'lingkar kepala pada kunjungan berikutnya.';
        }
        widgets.add(pw.SizedBox(height: 8));
        widgets.add(pw.Text('Interpretasi & Rekomendasi: $isiInterpretasi',
            style: _gaya(10.5)));
        widgets.add(pw.SizedBox(height: 4));
        widgets.add(pw.Text(
            'Metode: Z-score LMS WHO ${umurT <= 60 ? '2006' : 'Reference 2007'}, '
            'klasifikasi Permenkes No. 2 Tahun 2020. Laporan ini adalah '
            'hasil pemantauan pertumbuhan, bukan diagnosis medis.',
            style: _gaya(10)));
      }
    } else if (par.jenis == kJenisLaporan[5]) {
      // Laporan bulanan untuk Puskesmas: ringkasan layanan, sebaran
      // status gizi pemeriksaan terakhir tiap balita, dan catatan.
      final kini = DateTime.now();
      final awal = dariDb ??
          '${kini.year}-${kini.month.toString().padLeft(2, '0')}-01';
      final hariAkhir = DateTime(kini.year, kini.month + 1, 0).day;
      final akhir = sampaiDb ??
          '${kini.year}-${kini.month.toString().padLeft(2, '0')}-'
              '${hariAkhir.toString().padLeft(2, '0')}';
      if (rentangTeks != null) {
        tambahJudul('LAPORAN BULANAN PUSKESMAS');
      } else {
        final dAwal = parseTanggalDb(awal);
        final dAkhir = parseTanggalDb(akhir);
        tambahJudul('LAPORAN BULANAN PUSKESMAS',
            subTambahan: 'Periode: '
                '${dAwal != null ? tanggalPanjangId(dAwal) : awal} s/d '
                '${dAkhir != null ? tanggalPanjangId(dAkhir) : akhir}');
      }

      Future<int> hitungSatu(String sql, List<Object?> args) async {
        final r = await db.rawQuery(sql, args);
        return (r.first.values.first as num?)?.toInt() ?? 0;
      }

      final totalBalita =
          await hitungSatu('SELECT COUNT(*) FROM balita', const []);
      final periksaBulan = await hitungSatu(
          'SELECT COUNT(*) FROM pemeriksaan WHERE tanggal BETWEEN ? AND ?',
          [awal, akhir]);
      final imunisasiBulan = await hitungSatu(
          "SELECT COUNT(*) FROM jadwal_imunisasi WHERE status = 'Selesai' "
          'AND tgl_diberikan BETWEEN ? AND ?',
          [awal, akhir]);
      final cakupan = await GrowTrackDB.ambilCakupanImunisasi();
      final rataCakupan = cakupan.isEmpty
          ? 0.0
          : cakupan.fold<double>(0, (a, c) {
                final selesai = (c['selesai'] as num?)?.toDouble() ?? 0;
                final total = (c['total_balita'] as num?)?.toDouble() ?? 0;
                return a + (total == 0 ? 0.0 : selesai / total * 100);
              }) /
              cakupan.length;

      widgets.add(pw.Text('Ringkasan Layanan', style: _gaya(11.5, tebal: true)));
      widgets.add(pw.SizedBox(height: 5));
      widgets.add(tabelDari(
        [_selHeader('Indikator'), _selHeader('Jumlah')],
        [
          [_selIsi('Balita terdaftar'), _selIsi('$totalBalita')],
          [_selIsi('Pemeriksaan pada periode ini'), _selIsi('$periksaBulan')],
          [
            _selIsi('Imunisasi selesai pada periode ini'),
            _selIsi('$imunisasiBulan')
          ],
          [
            _selIsi('Cakupan imunisasi wajib'),
            _selIsi('${rataCakupan.toStringAsFixed(1).replaceAll('.', ',')}%')
          ],
        ],
        const {0: pw.FlexColumnWidth(3.4), 1: pw.FlexColumnWidth(1.4)},
      ));
      widgets.add(pw.SizedBox(height: 14));
      widgets.add(pw.Text('Sebaran Status Gizi (Pemeriksaan Terakhir Tiap Balita)',
          style: _gaya(11.5, tebal: true)));
      widgets.add(pw.SizedBox(height: 5));
      final sebaranMentah = await db.rawQuery(
          'SELECT p.status_gizi AS status, COUNT(*) AS c FROM pemeriksaan p '
          'JOIN (SELECT id_balita, MAX(tanggal) AS mx FROM pemeriksaan '
          'GROUP BY id_balita) t '
          'ON t.id_balita = p.id_balita AND t.mx = p.tanggal '
          'GROUP BY p.status_gizi ORDER BY c DESC');
      final sebaran = <String, int>{};
      for (final r in sebaranMentah) {
        var label = r['status']?.toString() ?? '-';
        if (label == 'Normal' || label == 'Gizi Baik') {
          label = 'Normal / Gizi Baik';
        }
        sebaran[label] = (sebaran[label] ?? 0) + ((r['c'] as num?)?.toInt() ?? 0);
      }
      final totalSebaran =
          sebaran.values.fold<int>(0, (a, b) => a + b);
      widgets.add(tabelDari(
        [_selHeader('Status Gizi'), _selHeader('Jumlah'), _selHeader('Persentase')],
        [
          for (final e in sebaran.entries)
            [
              _selIsi(e.key),
              _selIsi('${e.value}'),
              _selIsi(totalSebaran == 0
                  ? '0,0%'
                  : '${(e.value / totalSebaran * 100).toStringAsFixed(1).replaceAll('.', ',')}%'),
            ],
          if (sebaran.isEmpty)
            [_selIsi('Belum ada data pemeriksaan'), _selIsi('0'), _selIsi('0,0%')],
        ],
        const {
          0: pw.FlexColumnWidth(3.4),
          1: pw.FlexColumnWidth(1.1),
          2: pw.FlexColumnWidth(1.3),
        },
      ));

      int hitungLabel(bool Function(String) uji) => sebaran.entries
          .where((e) => uji(e.key))
          .fold<int>(0, (a, e) => a + e.value);
      final nStunting = hitungLabel(
          (s) => s.contains('Stunting') || s.contains('Pendek'));
      final nKurang = hitungLabel((s) => s.contains('Kurang'));
      final nBuruk = hitungLabel((s) => s.contains('Buruk'));
      final bagian = <String>[
        if (nStunting > 0) '$nStunting balita terdeteksi pendek (stunting)',
        if (nKurang > 0) '$nKurang balita gizi kurang',
        if (nBuruk > 0) '$nBuruk balita gizi buruk',
      ];
      widgets.add(pw.SizedBox(height: 10));
      if (bagian.isEmpty) {
        widgets.add(pw.Text(
            'Catatan: Tidak ada balita terdeteksi stunting, gizi kurang, '
            'atau gizi buruk berdasarkan pemeriksaan terakhir tiap balita.',
            style: _gaya(10.5)));
      } else {
        widgets.add(pw.Text(
            'Catatan: Sebanyak ${bagian.join(' dan ')} berdasarkan '
            'pemeriksaan terakhir tiap balita. Balita tersebut masuk '
            'daftar pantauan risiko dan dijadwalkan menerima PMT '
            'pemulihan serta kunjungan ulang bulan depan.',
            style: _gaya(10.5)));
      }
    }

    // === BLOK TANDA TANGAN ===
    widgets.add(pw.SizedBox(height: 30));
    final tglCetak = tanggalPanjangId(DateTime.now());
    final bool isPmt = par.jenis == kJenisLaporan[3];

    final String teksKiri;
    final String teksKanan;
    if (isPmt) {
      teksKiri = 'Mengetahui,\nPenanggung Jawab';
      var rtLabel = 'RT ....';
      var namaPj = '.......................';
      if (par.rt != null) {
        rtLabel = 'RT ${par.rt!['rt']}';
        namaPj = par.rt!['penanggung_jawab'] ?? namaPj;
      }
      teksKanan = '$kota, $tglCetak\nPenanggung Jawab $rtLabel';
      widgets.add(pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(children: [
              pw.Text(teksKiri, style: _gaya(11), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 60),
              _teksNama('...........................'),
            ]),
          ),
          pw.Expanded(
            child: pw.Column(children: [
              pw.Text(teksKanan, style: _gaya(11), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 60),
              _teksNama(namaPj),
            ]),
          ),
        ],
      ));
    } else {
      teksKiri = 'Mengetahui,\nKepala / Ketua Posyandu';
      teksKanan = '$kota, $tglCetak\nPetugas / Bidan';
      widgets.add(pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(children: [
              pw.Text(teksKiri, style: _gaya(11), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 60),
              _teksNama(namaKetua),
            ]),
          ),
          pw.Expanded(
            child: pw.Column(children: [
              pw.Text(teksKanan, style: _gaya(11), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 60),
              _teksNama(SesiUser.namaLengkap ?? ''),
            ]),
          ),
        ],
      ));
    }

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
