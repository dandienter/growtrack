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

List<List<double>> _hcfa(bool laki) =>
    _tabel(laki ? 'hcfaL' : 'hcfaP', laki ? kHCFA_LAKI : kHCFA_PEREMPUAN);

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

/// Invers LMS: nilai pengukuran pada Z-Score tertentu (dipakai penyesuaian ekor).
double _nilaiPadaZ(double z, double l, double m, double s) {
  if (m <= 0 || s <= 0) return double.nan;
  if (l.abs() < 1e-9) return m * math.exp(s * z);
  final dasar = 1 + l * s * z;
  if (dasar <= 0) return double.nan;
  return m * math.pow(dasar, 1 / l).toDouble();
}

/// Rumus Z-Score LMS WHO, lengkap dengan:
/// - cabang L = 0: z = ln(y/M) / S (menghindari pembagian dengan nol)
/// - penyesuaian ekor WHO untuk |z| > 3 SD: z dihitung linear dari jarak
///   nilai SD2 dan SD3 (restricted z-score ala WHO Anthro) agar nilai
///   ekstrem tidak terkompresi oleh kurva LMS.
/// Hasil akhir dijepit ke rentang -6..6.
double zLMS(double y, double l, double m, double s) {
  if (m <= 0 || s <= 0 || y <= 0) return double.nan;
  double z;
  if (l.abs() < 1e-9) {
    z = math.log(y / m) / s;
  } else {
    z = (math.pow(y / m, l).toDouble() - 1.0) / (l * s);
  }
  if (z > 3.0) {
    final sd3 = _nilaiPadaZ(3.0, l, m, s);
    final sd2 = _nilaiPadaZ(2.0, l, m, s);
    if (!sd3.isNaN && !sd2.isNaN && sd3 > sd2) {
      z = 3.0 + (y - sd3) / (sd3 - sd2);
    }
  } else if (z < -3.0) {
    final sd3 = _nilaiPadaZ(-3.0, l, m, s);
    final sd2 = _nilaiPadaZ(-2.0, l, m, s);
    if (!sd3.isNaN && !sd2.isNaN && sd2 > sd3) {
      z = -3.0 + (y - sd3) / (sd2 - sd3);
    }
  }
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

/// Z-Score LK/U (Lingkar Kepala menurut Umur), WHO 2006.
/// Tabel hanya tersedia untuk umur 0-60 bulan; di luar itu NaN.
double zLKU(double lkCm, double umurBulan, bool laki) {
  if (umurBulan < 0 || umurBulan > 60) return double.nan;
  final lms = _interp(_hcfa(laki), umurBulan);
  return zLMS(lkCm, lms[0], lms[1], lms[2]);
}

/// Median WHO (nilai M hasil interpolasi) untuk tampilan detail indikator.
double medianBBU(double umurBulan, bool laki) =>
    _interp(_wfa(laki), umurBulan)[1];

/// Median WHO TB/U untuk tampilan detail indikator.
double medianTBU(double umurBulan, bool laki) =>
    _interp(_lhfa(laki), umurBulan)[1];

/// Median WHO BB/TB untuk tampilan detail indikator
/// (pemilihan tabel WFL/WFH sama seperti zBBTB).
double medianBBTB(double tbCm, double umurBulan, bool laki) {
  if (umurBulan < 24) {
    return _interp(_wfl(laki), (tbCm - 45.0) / 0.5)[1];
  }
  return _interp(_wfh(laki), (tbCm - 65.0) / 0.5)[1];
}

/// Median WHO LK/U; NaN di luar umur 0-60 bulan.
double medianLKU(double umurBulan, bool laki) {
  if (umurBulan < 0 || umurBulan > 60) return double.nan;
  return _interp(_hcfa(laki), umurBulan)[1];
}

bool isLaki(String? jk) =>
    jk != null && (jk.toUpperCase() == 'L' || jk.toLowerCase().startsWith('laki'));

// ---------------------------------------------------------------------------
// WHO Reference 2007 (usia 61-228 bulan; BB/U hanya 61-120 bulan).
// Indeks tabel 0 = umur 61 bulan.
// ---------------------------------------------------------------------------

List<List<double>> _hfa07(bool laki) =>
    _tabel(laki ? 'hfa07L' : 'hfa07P', laki ? kHFA07_LAKI : kHFA07_PEREMPUAN);

List<List<double>> _bfa07(bool laki) =>
    _tabel(laki ? 'bfa07L' : 'bfa07P', laki ? kBFA07_LAKI : kBFA07_PEREMPUAN);

List<List<double>> _wfa07(bool laki) =>
    _tabel(laki ? 'wfa07L' : 'wfa07P', laki ? kWFA07_LAKI : kWFA07_PEREMPUAN);

/// Z-Score TB/U menurut WHO Reference 2007 (61-228 bulan).
double zTBU2007(double tbCm, double umurBulan, bool laki) {
  if (umurBulan < 61 || umurBulan > 228) return double.nan;
  final lms = _interp(_hfa07(laki), umurBulan - 61);
  return zLMS(tbCm, lms[0], lms[1], lms[2]);
}

/// Z-Score BB/U menurut WHO Reference 2007 (61-120 bulan saja).
double zBBU2007(double bbKg, double umurBulan, bool laki) {
  if (umurBulan < 61 || umurBulan > 120) return double.nan;
  final lms = _interp(_wfa07(laki), umurBulan - 61);
  return zLMS(bbKg, lms[0], lms[1], lms[2]);
}

/// Indeks Massa Tubuh: BB (kg) / TB (m) kuadrat.
double imt(double bbKg, double tbCm) {
  final m = tbCm / 100.0;
  if (m <= 0) return double.nan;
  return bbKg / (m * m);
}

/// Z-Score IMT/U menurut WHO Reference 2007 (61-228 bulan).
double zIMTU(double bbKg, double tbCm, double umurBulan, bool laki) {
  if (umurBulan < 61 || umurBulan > 228) return double.nan;
  final nilaiImt = imt(bbKg, tbCm);
  if (nilaiImt.isNaN) return double.nan;
  final lms = _interp(_bfa07(laki), umurBulan - 61);
  return zLMS(nilaiImt, lms[0], lms[1], lms[2]);
}

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

/// Klasifikasi LK/U menurut Permenkes No. 2 Tahun 2020:
/// < -2 SD di bawah normal, -2 s.d. +2 SD normal, > +2 SD di atas normal.
String tentukanLKU(double z) {
  if (z.isNaN) return '-';
  if (z < -2.0) return 'Di Bawah Normal';
  if (z <= 2.0) return 'Normal';
  return 'Di Atas Normal';
}

/// Klasifikasi IMT/U usia 5-18 tahun menurut Permenkes No. 2 Tahun 2020.
String tentukanIMTU(double z) {
  if (z.isNaN) return '-';
  if (z < -3.0) return 'Gizi Buruk';
  if (z < -2.0) return 'Gizi Kurang';
  if (z <= 1.0) return 'Gizi Baik';
  if (z <= 2.0) return 'Gizi Lebih';
  return 'Obesitas';
}

String _fmt(double z) => z.isNaN ? '-' : z.toStringAsFixed(2);

/// Hasil lengkap penilaian status gizi (padanan hitungStatusGiziDetail).
class HasilGizi {
  final double zBBU;
  final double zTBU;
  final double zBBTB;

  /// Z-Score IMT/U (WHO 2007); NaN untuk anak usia 0-60 bulan.
  final double zIMTU;

  /// Z-Score LK/U (WHO 2006); NaN bila LK tidak diukur atau umur > 60 bulan.
  /// Dihitung on-the-fly, tidak disimpan sebagai kolom database.
  final double zLKU;
  final String statusBBU;
  final String statusTBU;
  final String statusBBTB;

  /// Kategori IMT/U (WHO 2007); '-' untuk anak usia 0-60 bulan.
  final String statusIMTU;

  /// Kategori LK/U; '-' bila LK tidak diukur atau umur > 60 bulan.
  final String statusLKU;
  final String statusUtama;

  /// Blok teks "[AUTO] Evaluasi Antropometri WHO 2006 (Kemenkes): ..."
  final String detail;

  const HasilGizi({
    required this.zBBU,
    required this.zTBU,
    required this.zBBTB,
    this.zIMTU = double.nan,
    this.zLKU = double.nan,
    required this.statusBBU,
    required this.statusTBU,
    required this.statusBBTB,
    this.statusIMTU = '-',
    this.statusLKU = '-',
    required this.statusUtama,
    required this.detail,
  });
}

/// Penilaian anak usia lebih dari 60 bulan memakai WHO Reference 2007
/// sesuai Permenkes No. 2 Tahun 2020: indeks utama IMT/U, didampingi TB/U
/// (pemantauan stunting) dan BB/U (hanya sampai 120 bulan).
HasilGizi _hitungStatusGizi2007(
    double bb, double tbCm, int umurBulan, String? jk) {
  final laki = isLaki(jk);
  if (umurBulan > 228) {
    final detail = StringBuffer()
      ..writeln('[AUTO] Evaluasi Antropometri WHO Reference 2007 (Kemenkes):')
      ..writeln('- Usia Anak: $umurBulan Bulan')
      ..writeln('- LK/U: - (hanya sampai usia 60 bulan)')
      ..writeln('- Di luar rentang standar 61-228 bulan (5-18 tahun).');
    return HasilGizi(
      zBBU: double.nan,
      zTBU: double.nan,
      zBBTB: double.nan,
      statusBBU: '-',
      statusTBU: '-',
      statusBBTB: '-',
      statusUtama: 'Di Luar Rentang Usia Standar',
      detail: detail.toString(),
    );
  }
  final zBbu = zBBU2007(bb, umurBulan.toDouble(), laki);
  final zTbu = zTBU2007(tbCm, umurBulan.toDouble(), laki);
  final zImtu = zIMTU(bb, tbCm, umurBulan.toDouble(), laki);

  final statusBBU = tentukanBBU(zBbu);
  final statusTBU = tentukanTBU(zTbu);
  final statusIMTU = tentukanIMTU(zImtu);

  // Flag plausibilitas WHO AnthroPlus: BB/U di luar -6..+5,
  // TB/U di luar -6..+6, IMT/U di luar -5..+5.
  final bbuBerlaku = umurBulan <= 120;
  final anomali = (bbuBerlaku && (zBbu.isNaN || zBbu < -6 || zBbu > 5)) ||
      zTbu.isNaN ||
      zTbu < -6 ||
      zTbu > 6 ||
      zImtu.isNaN ||
      zImtu < -5 ||
      zImtu > 5;

  final String statusUtama;
  if (anomali) {
    statusUtama = 'Data Anomali (Cek Ulang Input!)';
  } else {
    final isStunted = statusTBU.contains('Pendek');
    if (isStunted && statusIMTU.contains('Buruk')) {
      statusUtama = 'Gizi Buruk & Stunting';
    } else if (isStunted && statusIMTU.contains('Kurang')) {
      statusUtama = 'Gizi Kurang & Stunting';
    } else if (isStunted && statusIMTU.contains('Obesitas')) {
      statusUtama = 'Stunting & Obesitas';
    } else if (isStunted) {
      statusUtama = 'Stunting';
    } else if (statusIMTU.contains('Buruk')) {
      statusUtama = 'Gizi Buruk';
    } else if (statusIMTU.contains('Kurang')) {
      statusUtama = 'Gizi Kurang';
    } else if (statusIMTU.contains('Obesitas')) {
      statusUtama = 'Obesitas';
    } else if (statusIMTU.contains('Lebih')) {
      statusUtama = 'Gizi Lebih';
    } else if (bbuBerlaku && statusBBU.contains('Kurang')) {
      statusUtama = 'BB Kurang';
    } else {
      statusUtama = 'Normal / Gizi Baik';
    }
  }

  final detail = StringBuffer()
    ..writeln('[AUTO] Evaluasi Antropometri WHO Reference 2007 (Kemenkes):')
    ..writeln('- Usia Anak: $umurBulan Bulan');
  if (bbuBerlaku) {
    detail.writeln('- BB/U (Z-Score: ${_fmt(zBbu)}): $statusBBU');
  } else {
    detail.writeln('- BB/U: - (hanya sampai usia 120 bulan)');
  }
  detail
    ..writeln('- TB/U (Z-Score: ${_fmt(zTbu)}): $statusTBU')
    ..writeln('- IMT/U (IMT: ${imt(bb, tbCm).toStringAsFixed(2)}, '
        'Z-Score: ${_fmt(zImtu)}): $statusIMTU')
    ..writeln('- LK/U: - (hanya sampai usia 60 bulan)');

  return HasilGizi(
    zBBU: zBbu,
    zTBU: zTbu,
    zBBTB: double.nan,
    zIMTU: zImtu,
    statusBBU: statusBBU,
    statusTBU: statusTBU,
    statusBBTB: '-',
    statusIMTU: statusIMTU,
    statusUtama: statusUtama,
    detail: detail.toString(),
  );
}

/// Menghitung ketiga Z-Score memakai tinggi yang SUDAH dikoreksi posisi ukur.
/// Umur lebih dari 60 bulan otomatis memakai WHO Reference 2007.
/// [lingkarKepala] (cm) opsional: bila > 0 dan umur <= 60 bulan, Z-Score
/// LK/U ikut dihitung untuk baris LK/U pada catatan [AUTO]; status utama
/// tidak dipengaruhi oleh LK/U.
HasilGizi hitungStatusGiziDetail(double bb, double tbCm, int umurBulan,
    String? jk,
    {double lingkarKepala = 0}) {
  if (umurBulan > 60) {
    return _hitungStatusGizi2007(bb, tbCm, umurBulan, jk);
  }
  final laki = isLaki(jk);
  final zBbu = zBBU(bb, umurBulan.toDouble(), laki);
  final zTbu = zTBU(tbCm, umurBulan.toDouble(), laki);
  final zBbtb = zBBTB(bb, tbCm, umurBulan.toDouble(), laki);
  final zLku = lingkarKepala > 0
      ? zLKU(lingkarKepala, umurBulan.toDouble(), laki)
      : double.nan;
  final statusLKU = tentukanLKU(zLku);

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
    ..writeln('- BB/TB (Z-Score: ${_fmt(zBbtb)}): $statusBBTB')
    ..writeln('- LK/U (Z-Score: ${_fmt(zLku)}): $statusLKU');

  return HasilGizi(
    zBBU: zBbu,
    zTBU: zTbu,
    zBBTB: zBbtb,
    zLKU: zLku,
    statusBBU: statusBBU,
    statusTBU: statusTBU,
    statusBBTB: statusBBTB,
    statusLKU: statusLKU,
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
