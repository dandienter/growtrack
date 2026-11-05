import 'package:intl/intl.dart';

/// Helper pemformatan tanggal & angka mengikuti perilaku aplikasi desktop.

final NumberFormat _fmtRupiah =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

/// Format Rupiah gaya desktop: "Rp 1.234.567".
String formatRupiah(num nilai) => _fmtRupiah.format(nilai);

/// "yyyy-MM-dd" -> "dd-MM-yyyy" (port formatTanggalID pada DialogLaporan).
String formatTanggalID(String? tgl) {
  if (tgl == null || tgl.isEmpty || tgl == '-') return '-';
  try {
    if (tgl.length >= 10) {
      final y = tgl.substring(0, 4);
      final m = tgl.substring(5, 7);
      final d = tgl.substring(8, 10);
      return '$d-$m-$y';
    }
    return tgl;
  } catch (_) {
    return tgl;
  }
}

/// DateTime -> "yyyy-MM-dd" (format simpan database).
String keTeksDb(DateTime? d) =>
    d == null ? '' : DateFormat('yyyy-MM-dd').format(d);

/// DateTime -> "dd-MM-yyyy" (tampilan).
String keTeksTampil(DateTime? d) =>
    d == null ? '-' : DateFormat('dd-MM-yyyy').format(d);

/// "yyyy-MM-dd" -> DateTime (null bila tidak valid).
DateTime? parseTanggalDb(String? teks) {
  if (teks == null || teks.isEmpty) return null;
  try {
    return DateFormat('yyyy-MM-dd').parseStrict(teks.substring(0, 10));
  } catch (_) {
    return null;
  }
}

/// "dd MMMM yyyy" Bahasa Indonesia, untuk blok tanda tangan laporan.
String tanggalPanjangId(DateTime d) =>
    DateFormat('dd MMMM yyyy', 'id_ID').format(d);

/// Format z-score "%.2f"; NaN/null menjadi "-".
String fmtZ(double? z) {
  if (z == null || z.isNaN) return '-';
  return z.toStringAsFixed(2);
}

/// Parse angka dengan koma sebagai pemisah desimal (gaya FormPemeriksaan).
double? parseAngka(String teks) {
  final t = teks.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Parse angka gaya FormKonsumsi: koma dibuang (pemisah ribuan).
double? parseAngkaRibuan(String teks) {
  var t = teks.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  final langsung = double.tryParse(t.replaceAll(',', '.'));
  if (langsung != null) return langsung;
  t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

/// Nilai database apa pun menjadi teks tampilan; null/kosong/"null" -> "-".
String teksDb(Object? v) {
  if (v == null) return '-';
  final s = v.toString();
  if (s.trim().isEmpty || s.toLowerCase() == 'null') return '-';
  return s;
}

/// Port extractValue() pada DialogLaporan: ambil teks di antara penanda.
String extractValue(String? text, String startMarker, String endMarker) {
  if (text == null) return '-';
  var startIndex = text.indexOf(startMarker);
  if (startIndex == -1) return '-';
  startIndex += startMarker.length;
  var endIndex = text.indexOf(endMarker, startIndex);
  if (endIndex == -1) endIndex = text.length;
  var result = text.substring(startIndex, endIndex).trim();
  if (result.startsWith(':')) result = result.substring(1).trim();
  return result;
}
