import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../db/database.dart';
import '../format.dart';
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
  static final _fontBiasa = pw.Font.helvetica();
  static final _fontTebal = pw.Font.helveticaBold();
  static final _fontMiring = pw.Font.helveticaOblique();

  static pw.TextStyle _gaya(double ukuran, {bool tebal = false}) =>
      pw.TextStyle(font: tebal ? _fontTebal : _fontBiasa, fontSize: ukuran);

  static pw.Widget _selHeader(String teks) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      alignment: pw.Alignment.center,
      child: pw.Text(teks,
          style: _gaya(11, tebal: true), textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _selIsi(String? teks, {bool kanan = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: kanan ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(teksDb(teks),
          style: _gaya(11),
          textAlign: kanan ? pw.TextAlign.right : pw.TextAlign.left),
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
        namaPosyandu.length > 30 ? 18.0 : (namaPosyandu.length > 20 ? 20.0 : 22.0);

    final widgets = <pw.Widget>[];

    // === KOP SURAT ===
    final teksKop = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(namaPosyandu,
            style: _gaya(ukuranKop, tebal: true),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 4),
        pw.Text('$alamat\nTelp: $telp',
            style: _gaya(10), textAlign: pw.TextAlign.center),
      ],
    );
    if (logo != null) {
      widgets.add(pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: 70,
            height: 70,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.Expanded(child: teksKop),
          pw.SizedBox(width: 70),
        ],
      ));
    } else {
      widgets.add(teksKop);
    }
    widgets.add(pw.SizedBox(height: 8));
    widgets.add(pw.Container(
        height: 2, decoration: const pw.BoxDecoration(color: PdfColors.black)));
    widgets.add(pw.SizedBox(height: 14));

    String? rentangTeks;
    String? dariDb;
    String? sampaiDb;
    if (par.pakaiFilter && par.dari != null && par.sampai != null) {
      dariDb = keTeksDb(par.dari);
      sampaiDb = keTeksDb(par.sampai);
      rentangTeks =
          'Periode: ${keTeksTampil(par.dari)} s/d ${keTeksTampil(par.sampai)}';
    }

    void tambahJudul(String judul, {String? subTambahan}) {
      widgets.add(pw.Text(judul,
          style: _gaya(14, tebal: true), textAlign: pw.TextAlign.center));
      widgets.add(pw.SizedBox(height: 4));
      final sub = <String>[
        if (rentangTeks != null) rentangTeks,
        if (subTambahan != null) subTambahan,
      ];
      if (sub.isNotEmpty) {
        widgets.add(pw.Text(sub.join('\n'),
            style: _gaya(10), textAlign: pw.TextAlign.center));
      }
      widgets.add(pw.SizedBox(height: 12));
    }

    pw.Table tabelDari(List<pw.Widget> headers, List<List<pw.Widget>> baris,
        Map<int, pw.TableColumnWidth> lebar) {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
        columnWidths: lebar,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
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
    } else if (par.jenis == kJenisLaporan[1]) {
      tambahJudul('LAPORAN RIWAYAT PEMERIKSAAN KESELURUHAN');
      var sql = 'SELECT p.id_periksa, b.nama_balita, p.tanggal, p.berat_badan, '
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
          _selHeader('ID Periksa'),
          _selHeader('Nama Balita'),
          _selHeader('Tanggal'),
          _selHeader('Berat(Kg)'),
          _selHeader('Tinggi(Cm)'),
          _selHeader('Status Gizi'),
        ],
        [
          for (final r in rows)
            [
              _selIsi(r['id_periksa']?.toString()),
              _selIsi(r['nama_balita']?.toString()),
              _selIsi(formatTanggalID(r['tanggal']?.toString())),
              _selIsi(r['berat_badan']?.toString()),
              _selIsi(r['tinggi_badan']?.toString()),
              _selIsi(r['status_gizi']?.toString()),
            ],
        ],
        const {
          0: pw.FlexColumnWidth(1.8),
          1: pw.FlexColumnWidth(3.5),
          2: pw.FlexColumnWidth(2),
          3: pw.FlexColumnWidth(2),
          4: pw.FlexColumnWidth(2.3),
          5: pw.FlexColumnWidth(3.5),
        },
      ));
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
    } else if (par.jenis == kJenisLaporan[3]) {
      final rtDipilih = par.rt;
      tambahJudul(
        'LAPORAN KONSUMSI PMT WARGA',
        subTambahan: rtDipilih != null
            ? 'Filter Wilayah: RT ${rtDipilih['rt']}'
            : null,
      );
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
          _selIsi('${(r['jumlah_balita'] as num?)?.toInt() ?? 0} Anak'),
          _selIsi(formatRupiah(total), kanan: true),
        ]);
      }
      widgets.add(tabelDari(
        [
          _selHeader('ID Konsumsi'),
          _selHeader('Tanggal'),
          _selHeader('Nama Kegiatan'),
          _selHeader('Pemberian MT'),
          _selHeader('Jumlah Balita'),
          _selHeader('Total Biaya'),
        ],
        baris,
        const {
          0: pw.FlexColumnWidth(1.8),
          1: pw.FlexColumnWidth(3.2),
          2: pw.FlexColumnWidth(3.5),
          3: pw.FlexColumnWidth(3.5),
          4: pw.FlexColumnWidth(2.2),
          5: pw.FlexColumnWidth(3),
        },
      ));
      // Baris total: sel pertama colspan 5 (1.8+3.2+3.5+3.5+2.2 = 14.2) + nilai.
      widgets.add(pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(14.2),
          1: pw.FlexColumnWidth(3),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                alignment: pw.Alignment.centerRight,
                child: pw.Text('TOTAL PENGELUARAN BIAYA KONSUMSI PMT',
                    style: _gaya(11, tebal: true)),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(formatRupiah(grandTotal),
                    style: _gaya(11, tebal: true)),
              ),
            ],
          ),
        ],
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

      widgets.add(pw.Text('BIODATA ANAK & ORANG TUA', style: _gaya(11, tebal: true)));
      widgets.add(pw.SizedBox(height: 5));
      pw.Widget bioBaris(String label, String nilai) {
        return pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 130, child: pw.Text(label, style: _gaya(12))),
            pw.Expanded(child: pw.Text(': $nilai', style: _gaya(12))),
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
      widgets.add(pw.SizedBox(height: 15));
      widgets.add(
          pw.Text('GRAFIK / RIWAYAT PEMERIKSAAN', style: _gaya(11, tebal: true)));
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

      String fmtZKolo(Map<String, Object?> r, String kolom, String fallback) {
        final v = r[kolom];
        if (v is num) return '(Z-Score: ${v.toStringAsFixed(2)})';
        return fallback;
      }

      final baris = <List<pw.Widget>>[];
      for (final r in rows) {
        final rawCatatan = r['catatan_bidan']?.toString();
        final usiaStr = extractValue(rawCatatan, '- Usia Anak:', '\n');
        final bbuStr = fmtZKolo(
            r, 'z_bbu', extractValue(rawCatatan, '- BB/U', '\n'));
        final tbuStr = fmtZKolo(
            r, 'z_tbu', extractValue(rawCatatan, '- TB/U', '\n'));
        final bbtbStr = fmtZKolo(
            r, 'z_bbtb', extractValue(rawCatatan, '- BB/TB', '\n'));

        var posisiStr = r['posisi_ukur']?.toString() ?? '';
        if (posisiStr.isEmpty) {
          posisiStr = extractValue(rawCatatan, '- Posisi Ukur:', '\n');
        }
        final asiStr = extractValue(rawCatatan, '- ASI Eksklusif:', '\n');
        final vitAStr = extractValue(rawCatatan, '- Kapsul Vit A:', '\n');
        final cacingStr = extractValue(rawCatatan, '- Obat Cacing:', '\n');
        final imunStr =
            extractValue(rawCatatan, '- Imunisasi Diberikan:', '\n');

        var catatanManual = '-';
        if (rawCatatan != null && rawCatatan.contains('--- Catatan Manual ---')) {
          catatanManual = rawCatatan
              .substring(rawCatatan.indexOf('--- Catatan Manual ---') + 22)
              .trim();
        }
        if (catatanManual.isEmpty) catatanManual = '-';

        final col2 = 'BB: ${r['berat_badan']} Kg\n'
            'TB: ${r['tinggi_badan']} Cm\n'
            'LK: ${r['lingkar_kepala']} Cm\n'
            'Pos: ${posisiStr.replaceAll(RegExp(r'\(.*?\)'), '').trim()}';
        final sg = r['status_gizi']?.toString();
        final col3 = 'VONIS: ${sg != null ? sg.toUpperCase() : '-'}\n\n'
            '  BB/U $bbuStr\n'
            '  TB/U $tbuStr\n'
            '  BB/TB $bbtbStr';
        final col4 = 'Vit A: $vitAStr\n'
            'Cacing: $cacingStr\n'
            'Imun: $imunStr\n'
            'ASI: $asiStr';

        baris.add([
          _selIsi(usiaStr),
          _selIsi(col2),
          _selIsi(col3),
          _selIsi(col4),
          _selIsi(catatanManual),
        ]);
      }

      widgets.add(tabelDari(
        [
          _selHeader('Usia'),
          _selHeader('Hasil Ukur'),
          _selHeader('Z-Score & Status'),
          _selHeader('Intervensi'),
          _selHeader('Catatan Khusus'),
        ],
        baris,
        const {
          0: pw.FlexColumnWidth(1.5),
          1: pw.FlexColumnWidth(2.2),
          2: pw.FlexColumnWidth(3.8),
          3: pw.FlexColumnWidth(2.5),
          4: pw.FlexColumnWidth(2.5),
        },
      ));
    } else if (par.jenis == kJenisLaporan[5]) {
      // Laporan bulanan ringkas untuk Puskesmas: indikator utama,
      // distribusi status gizi, dan daftar anak yang perlu perhatian.
      final kini = DateTime.now();
      final awal = dariDb ??
          '${kini.year}-${kini.month.toString().padLeft(2, '0')}-01';
      final hariAkhir = DateTime(kini.year, kini.month + 1, 0).day;
      final akhir = sampaiDb ??
          '${kini.year}-${kini.month.toString().padLeft(2, '0')}-'
              '${hariAkhir.toString().padLeft(2, '0')}';
      tambahJudul('LAPORAN BULANAN POSYANDU UNTUK PUSKESMAS',
          subTambahan:
              'Periode: ${formatTanggalID(awal)} s/d ${formatTanggalID(akhir)}');

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
      final anakBerisiko = await hitungSatu(
          'SELECT COUNT(DISTINCT id_balita) FROM pemeriksaan '
          'WHERE tanggal BETWEEN ? AND ? AND (status_gizi LIKE ? '
          'OR status_gizi LIKE ? OR status_gizi LIKE ?)',
          [awal, akhir, '%Buruk%', '%Stunting%', '%Kurang%']);
      final cakupan = await GrowTrackDB.ambilCakupanImunisasi();
      final rataCakupan = cakupan.isEmpty
          ? 0.0
          : cakupan.fold<double>(0, (a, c) {
                final selesai = (c['selesai'] as num?)?.toDouble() ?? 0;
                final total = (c['total_balita'] as num?)?.toDouble() ?? 0;
                return a + (total == 0 ? 0.0 : selesai / total * 100);
              }) /
              cakupan.length;

      widgets.add(tabelDari(
        [_selHeader('Indikator'), _selHeader('Jumlah')],
        [
          [_selIsi('Balita terdaftar'), _selIsi('$totalBalita anak', kanan: true)],
          [
            _selIsi('Pemeriksaan bulan ini'),
            _selIsi('$periksaBulan kali', kanan: true)
          ],
          [
            _selIsi('Imunisasi diberikan bulan ini'),
            _selIsi('$imunisasiBulan kali', kanan: true)
          ],
          [
            _selIsi('Anak berisiko (gizi buruk, kurang, stunting)'),
            _selIsi('$anakBerisiko anak', kanan: true)
          ],
          [
            _selIsi('Rata-rata cakupan imunisasi'),
            _selIsi('${rataCakupan.toStringAsFixed(1)}%', kanan: true)
          ],
        ],
        const {0: pw.FlexColumnWidth(3.4), 1: pw.FlexColumnWidth(1.4)},
      ));
      widgets.add(pw.SizedBox(height: 16));
      widgets.add(pw.Text('Distribusi Status Gizi Bulan Ini',
          style: _gaya(12, tebal: true)));
      widgets.add(pw.SizedBox(height: 8));
      final distribusi = await db.rawQuery(
          'SELECT status_gizi, COUNT(*) AS c FROM pemeriksaan '
          'WHERE tanggal BETWEEN ? AND ? GROUP BY status_gizi '
          'ORDER BY c DESC',
          [awal, akhir]);
      widgets.add(tabelDari(
        [_selHeader('Status Gizi'), _selHeader('Jumlah Pemeriksaan')],
        [
          for (final r in distribusi)
            [
              _selIsi(r['status_gizi']?.toString()),
              _selIsi('${r['c']}', kanan: true),
            ],
          if (distribusi.isEmpty)
            [_selIsi('Belum ada pemeriksaan pada periode ini'), _selIsi('0')],
        ],
        const {0: pw.FlexColumnWidth(3.4), 1: pw.FlexColumnWidth(1.4)},
      ));
      widgets.add(pw.SizedBox(height: 16));
      widgets.add(pw.Text('Anak yang Perlu Perhatian',
          style: _gaya(12, tebal: true)));
      widgets.add(pw.SizedBox(height: 8));
      final risiko = await db.rawQuery(
          'SELECT b.nama_balita AS nama, p.tanggal AS tgl, '
          'p.status_gizi AS status FROM pemeriksaan p '
          'JOIN balita b ON b.id_balita = p.id_balita '
          'WHERE p.tanggal BETWEEN ? AND ? AND (p.status_gizi LIKE ? '
          'OR p.status_gizi LIKE ? OR p.status_gizi LIKE ?) '
          'ORDER BY p.tanggal DESC LIMIT 60',
          [awal, akhir, '%Buruk%', '%Stunting%', '%Kurang%']);
      widgets.add(tabelDari(
        [_selHeader('Nama Anak'), _selHeader('Tanggal'), _selHeader('Status Gizi')],
        [
          for (final r in risiko)
            [
              _selIsi(r['nama']?.toString()),
              _selIsi(formatTanggalID(r['tgl']?.toString())),
              _selIsi(r['status']?.toString()),
            ],
          if (risiko.isEmpty)
            [
              _selIsi('Tidak ada anak berisiko pada periode ini'),
              _selIsi('-'),
              _selIsi('-'),
            ],
        ],
        const {
          0: pw.FlexColumnWidth(1.8),
          1: pw.FlexColumnWidth(1.1),
          2: pw.FlexColumnWidth(2.2),
        },
      ));
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
              pw.Text('( ................................... )',
                  style: _gaya(11), textAlign: pw.TextAlign.center),
            ]),
          ),
          pw.Expanded(
            child: pw.Column(children: [
              pw.Text(teksKanan, style: _gaya(11), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 60),
              pw.Text('( $namaPj )',
                  style: _gaya(11), textAlign: pw.TextAlign.center),
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
              pw.Text('( $namaKetua )',
                  style: _gaya(11), textAlign: pw.TextAlign.center),
            ]),
          ),
          pw.Expanded(
            child: pw.Column(children: [
              pw.Text(teksKanan, style: _gaya(11), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 60),
              pw.Text('( ${SesiUser.namaLengkap ?? ''} )',
                  style: _gaya(11), textAlign: pw.TextAlign.center),
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
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 50),
        footer: (pw.Context context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Dicetak dari Sistem GrowTrack | Halaman ${context.pageNumber}',
            style: pw.TextStyle(
              font: _fontMiring,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ),
        build: (pw.Context context) => widgets,
      ),
    );
    return doc.save();
  }
}
