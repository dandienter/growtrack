import 'dart:math' as math;

import '../data/who_lms.dart';

/// Port proses/StandarWHO.java + proses/ProsesPemeriksaan.java
/// + logika perhitungan pada tampilan/FormPemeriksaan.java.
///
/// Standar Antropometri WHO Child Growth Standards 2006 (Kemenkes RI,
/// PMK No. 2 Tahun 2020). Z-Score metode LMS: z = ((y/M)^L - 1) / (L * S).

// ---------------------------------------------------------------------------
// Tabel LMS (parse string "L,M,S;L,M,S;..." persis StandarWHO.parse)
// ---------------------------------------------------------------------------

final Map<String, List<List<double>>> _cacheTabel = {};

List<List<double>> _parse(String data) {
  return data.split(';').map((baris) {
    final c = baris.split(',');
    return <double>[
      double.parse(c[0]),
      double.parse(c[1]),
      double.parse(c[2]),
    ];
  }).toList();
}

List<List<double>> _tabel(String kunci, String data) =>
    _cacheTabel.putIfAbsent(kunci, () => _parse(data));

List<List<double>> _wfa(bool laki) =>
    _tabel(laki ? 'wfaL' : 'wfaP', laki ? kWFA_LAKI : kWFA_PEREMPUAN);

List<List<double>> _lhfa(bool laki) =>
    _tabel(laki ? 'lhfaL' : 'lhfaP', laki ? kLHFA_LAKI : kLHFA_PEREMPUAN);

List<List<double>> _wfl(bool laki) =>
    _tabel(laki ? 'wflL' : 'wflP', laki ? kWFL_LAKI : kWFL_PEREMPUAN);

List<List<double>> _wfh(bool laki) =>
    _tabel(laki ? 'wfhL' : 'wfhP', laki ? kWFH_LAKI : kWFH_PEREMPUAN);

/// Interpolasi linear antar titik (persis StandarWHO.interp, penjepitan ujung).
List<double> _interp(List<List<double>> t, double x) {
  final n = t.length - 1;
  if (x <= 0) return t[0];
  if (x >= n) return t[n];
  final i = x.floor();
  final f = x - i;
  return <double>[
    t[i][0] + f * (t[i + 1][0] - t[i][0]),
    t[i][1] + f * (t[i + 1][1] - t[i][1]),
    t[i][2] + f * (t[i + 1][2] - t[i][2]),
  ];
}

/// Rumus Z-Score LMS WHO; hasil dijepit ke rentang -6..6.
double zLMS(double y, double l, double m, double s) {
  if (m <= 0 || s <= 0 || y <= 0) return double.nan;
  final z = (math.pow(y / m, l).toDouble() - 1.0) / (l * s);
  if (z > 6.0) return 6.0;
  if (z < -6.0) return -6.0;
  return z;
}

/// Z-Score BB/U. umurBulan boleh desimal.
double zBBU(double bbKg, double umurBulan, bool laki) {
  final lms = _interp(_wfa(laki), umurBulan);
  return zLMS(bbKg, lms[0], lms[1], lms[2]);
}

/// Z-Score TB/U (atau PB/U). umurBulan boleh desimal.
double zTBU(double tbCm, double umurBulan, bool laki) {
  final lms = _interp(_lhfa(laki), umurBulan);
  return zLMS(tbCm, lms[0], lms[1], lms[2]);
}

/// Z-Score BB/TB (atau BB/PB).
/// umur < 24 bln memakai tabel WFL dengan x = (tb - 45) / 0.5;
/// umur >= 24 bln memakai tabel WFH dengan x = (tb - 65) / 0.5.
double zBBTB(double bbKg, double tbCm, double umurBulan, bool laki) {
  final List<List<double>> t;
  final double x;
  if (umurBulan < 24) {
    t = _wfl(laki);
    x = (tbCm - 45.0) / 0.5;
  } else {
    t = _wfh(laki);
    x = (tbCm - 65.0) / 0.5;
  }
  final lms = _interp(t, x);
  return zLMS(bbKg, lms[0], lms[1], lms[2]);
}

bool isLaki(String? jk) =>
    jk != null && (jk.toUpperCase() == 'L' || jk.toLowerCase().startsWith('laki'));

// ---------------------------------------------------------------------------
// Umur & koreksi tinggi (FormPemeriksaan.kalkulasiOtomatis)
// ---------------------------------------------------------------------------

/// Umur dalam bulan persis cara Java: selisih milidetik dibagi
/// (1000*60*60*24*30.44), dibulatkan trunc ke int, minimum 0.
int hitungUmurBulan(DateTime tglLahir, DateTime tglPeriksa) {
  final diffMs =
      tglPeriksa.millisecondsSinceEpoch - tglLahir.millisecondsSinceEpoch;
  var umur = (diffMs / (1000 * 60 * 60 * 24 * 30.44)).truncate();
  if (umur < 0) umur = 0;
  return umur;
}

class KoreksiTinggi {
  final double tinggiKoreksi;
  final String catatan; // mis. " (+0.7 cm krn <24 bln)" atau ""
  const KoreksiTinggi(this.tinggiKoreksi, this.catatan);
}

/// Koreksi 0.7 cm berdasarkan umur & posisi ukur (aturan WHO pada desktop).
KoreksiTinggi koreksiTinggi(double tinggi, int umurBulan, String posisi) {
  if (umurBulan < 24 && posisi == 'Berdiri') {
    return KoreksiTinggi(tinggi + 0.7, ' (+0.7 cm krn <24 bln)');
  }
  if (umurBulan >= 24 && posisi == 'Telentang') {
    return KoreksiTinggi(tinggi - 0.7, ' (-0.7 cm krn >=24 bln)');
  }
  return KoreksiTinggi(tinggi, '');
}

// ---------------------------------------------------------------------------
// Klasifikasi Kemenkes (ProsesPemeriksaan)
// ---------------------------------------------------------------------------

String tentukanBBU(double z) {
  if (z.isNaN) return '-';
  if (z < -3.0) return 'Sangat Kurang';
  if (z < -2.0) return 'Kurang';
  if (z <= 1.0) return 'Berat Badan Normal';
  return 'Risiko Berat Badan Lebih';
}

String tentukanTBU(double z) {
  if (z.isNaN) return '-';
  if (z < -3.0) return 'Sangat Pendek';
  if (z < -2.0) return 'Pendek';
  if (z <= 3.0) return 'Tinggi Normal';
  return 'Tinggi';
}

String tentukanBBTB(double z) {
  if (z.isNaN) return '-';
  if (z < -3.0) return 'Gizi Buruk';
  if (z < -2.0) return 'Gizi Kurang';
  if (z <= 1.0) return 'Gizi Baik';
  if (z <= 2.0) return 'Berisiko Gizi Lebih';
  if (z <= 3.0) return 'Gizi Lebih';
  return 'Obesitas';
}

String _fmt(double z) => z.isNaN ? '-' : z.toStringAsFixed(2);

/// Hasil lengkap penilaian status gizi (padanan hitungStatusGiziDetail).
class HasilGizi {
  final double zBBU;
  final double zTBU;
  final double zBBTB;
  final String statusBBU;
  final String statusTBU;
  final String statusBBTB;
  final String statusUtama;

  /// Blok teks "[AUTO] Evaluasi Antropometri WHO 2006 (Kemenkes): ..."
  final String detail;

  const HasilGizi({
    required this.zBBU,
    required this.zTBU,
    required this.zBBTB,
    required this.statusBBU,
    required this.statusTBU,
    required this.statusBBTB,
    required this.statusUtama,
    required this.detail,
  });
}

/// Menghitung ketiga Z-Score memakai tinggi yang SUDAH dikoreksi posisi ukur.
HasilGizi hitungStatusGiziDetail(
    double bb, double tbCm, int umurBulan, String? jk) {
  final laki = isLaki(jk);
  final zBbu = zBBU(bb, umurBulan.toDouble(), laki);
  final zTbu = zTBU(tbCm, umurBulan.toDouble(), laki);
  final zBbtb = zBBTB(bb, tbCm, umurBulan.toDouble(), laki);

  final statusBBU = tentukanBBU(zBbu);
  final statusTBU = tentukanTBU(zTbu);
  final statusBBTB = tentukanBBTB(zBbtb);

  final String statusUtama;
  // SMART DETECTOR: flag WHO untuk kemungkinan kesalahan input
  final anomaliBBU = zBbu < -6 || zBbu > 5;
  final anomaliTBU = zTbu < -6 || zTbu > 6;
  final anomaliBBTB = zBbtb < -5 || zBbtb > 5;
  if (zBbu.isNaN || zTbu.isNaN || zBbtb.isNaN ||
      anomaliBBU || anomaliTBU || anomaliBBTB) {
    statusUtama = 'Data Anomali (Cek Ulang Input!)';
  } else {
    final isStunted = statusTBU.contains('Pendek');
    if (isStunted && statusBBTB.contains('Buruk')) {
      statusUtama = 'Gizi Buruk & Stunting';
    } else if (isStunted && statusBBTB.contains('Kurang')) {
      statusUtama = 'Gizi Kurang & Stunting';
    } else if (isStunted && statusBBTB.contains('Obesitas')) {
      statusUtama = 'Stunting & Obesitas';
    } else if (isStunted) {
      statusUtama = 'Stunting';
    } else if (statusBBTB.contains('Buruk')) {
      statusUtama = 'Gizi Buruk';
    } else if (statusBBTB.contains('Kurang')) {
      statusUtama = 'Gizi Kurang';
    } else if (statusBBTB.contains('Obesitas')) {
      statusUtama = 'Obesitas';
    } else if (statusBBTB.contains('Lebih')) {
      statusUtama = 'Berisiko Gizi Lebih';
    } else if (statusBBU.contains('Kurang')) {
      statusUtama = 'BB Kurang';
    } else {
      statusUtama = 'Normal / Gizi Baik';
    }
  }

  final detail = StringBuffer()
    ..writeln('[AUTO] Evaluasi Antropometri WHO 2006 (Kemenkes):')
    ..writeln('- Usia Anak: $umurBulan Bulan')
    ..writeln('- BB/U (Z-Score: ${_fmt(zBbu)}): $statusBBU')
    ..writeln('- TB/U (Z-Score: ${_fmt(zTbu)}): $statusTBU')
    ..writeln('- BB/TB (Z-Score: ${_fmt(zBbtb)}): $statusBBTB');

  return HasilGizi(
    zBBU: zBbu,
    zTBU: zTbu,
    zBBTB: zBbtb,
    statusBBU: statusBBU,
    statusTBU: statusTBU,
    statusBBTB: statusBBTB,
    statusUtama: statusUtama,
    detail: detail.toString(),
  );
}

/// Menyusun catatan_bidan lengkap persis format FormPemeriksaan:
/// blok [AUTO] + blok [DATA TAMBAHAN POSYANDU] + catatan manual.
String bangunCatatanBidan({
  required HasilGizi hasil,
  required int umurBulan,
  required String posisiUkur,
  required String noteKoreksi,
  required String asi, // '- Pilih -' / 'Ya' / 'Tidak'
  required String vitA, // '- Pilih -' / 'Biru' / 'Merah' / 'Tidak'
  required String cacing, // '- Pilih -' / 'Ya' / 'Tidak'
  required String namaImunisasi, // nama vaksin atau '-'
  required String catatanManual,
}) {
  final asiTeks = umurBulan > 6
      ? 'Tidak Wajib (>6 Bln)'
      : (asi != '- Pilih -' ? asi : '-');
  final dataPosyandu = '\n[DATA TAMBAHAN POSYANDU]\n'
      '- Posisi Ukur: $posisiUkur$noteKoreksi\n'
      '- ASI Eksklusif: $asiTeks\n'
      '- Kapsul Vit A: ${vitA != '- Pilih -' ? vitA : '-'}\n'
      '- Obat Cacing: ${cacing != '- Pilih -' ? cacing : '-'}\n'
      '- Imunisasi Diberikan: $namaImunisasi\n';
  return '${hasil.detail}$dataPosyandu\n\n--- Catatan Manual ---\n$catatanManual';
}

/// Penanda pemisah catatan manual di dalam catatan_bidan.
const String kPemisahManual = '--- Catatan Manual ---';

/// Mengambil isi catatan manual dari catatan_bidan tersimpan.
String ambilCatatanManual(String? catatan) {
  if (catatan == null) return '';
  final idx = catatan.indexOf(kPemisahManual);
  if (idx == -1) {
    // Catatan lama tanpa blok otomatis: seluruhnya dianggap manual
    if (!catatan.contains('[AUTO]')) return catatan.trim();
    return '';
  }
  var sisa = catatan.substring(idx + kPemisahManual.length);
  sisa = sisa.replaceFirst(RegExp(r'^\s+'), '');
  return sisa.trimRight();
}

// ---------------------------------------------------------------------------
// Aturan kolom tambahan pemeriksaan berdasarkan umur (FormPemeriksaan)
// ---------------------------------------------------------------------------

/// ASI Eksklusif hanya aktif untuk umur <= 6 bulan.
bool asiAktif(int umurBulan) => umurBulan <= 6;

/// Pilihan kapsul Vitamin A menurut kelompok umur.
List<String> opsiVitA(int umurBulan) {
  if (umurBulan < 6) return const ['Tidak'];
  if (umurBulan <= 11) return const ['- Pilih -', 'Biru', 'Tidak'];
  if (umurBulan <= 59) return const ['- Pilih -', 'Merah', 'Tidak'];
  return const ['Tidak'];
}

/// Kapsul Vitamin A dapat dipilih pada umur 6-59 bulan.
bool vitAAktif(int umurBulan) => umurBulan >= 6 && umurBulan <= 59;

/// Obat cacing hanya aktif untuk umur 12-59 bulan.
bool cacingAktif(int umurBulan) => umurBulan >= 12 && umurBulan <= 59;

/// Bulan pemberian Vitamin A massal (Februari & Agustus).
bool bulanVitA(int bulan) => bulan == 2 || bulan == 8;
