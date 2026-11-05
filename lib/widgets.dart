import 'package:flutter/material.dart';

import 'format.dart';

/// Warna utama aplikasi (gaya desktop: teal #0F9D94).
const Color kTeal = Color(0xFF0F9D94);
const Color kLatar = Color(0xFFF8FAFC);

/// Warna status gizi mengikuti FormPemeriksaan desktop:
/// merah untuk Stunting/Buruk, kuning untuk Kurang/Lebih/Obesitas, hijau lainnya.
Color warnaStatusGizi(String? status) {
  final s = status ?? '';
  if (s.contains('Stunting') || s.contains('Buruk')) {
    return const Color(0xFFEF4444);
  }
  if (s.contains('Kurang') ||
      s.contains('Lebih') ||
      s.contains('Obesitas') ||
      s.contains('Anomali')) {
    return const Color(0xFFEAB308);
  }
  return const Color(0xFF22C55E);
}

void tampilSnack(BuildContext context, String pesan) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(pesan)));
}

Future<bool> tampilKonfirmasi(
  BuildContext context, {
  required String judul,
  required String pesan,
  String teksYa = 'Ya',
  String teksTidak = 'Tidak',
}) async {
  final hasil = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(judul),
      content: Text(pesan),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(teksTidak),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(teksYa),
        ),
      ],
    ),
  );
  return hasil ?? false;
}

/// Dekorasi kolom isian standar (sudut membulat, latar putih).
InputDecoration dekorasiInput(String label, {IconData? ikon, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: ikon == null ? null : Icon(ikon),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
  );
}

/// Kolom tanggal (ketuk untuk memilih). Bila [bolehKosong], ada tombol hapus.
class KolomTanggal extends StatelessWidget {
  final String label;
  final DateTime? nilai;
  final ValueChanged<DateTime?> onBerubah;
  final bool bolehKosong;

  const KolomTanggal({
    super.key,
    required this.label,
    required this.nilai,
    required this.onBerubah,
    this.bolehKosong = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final dipilih = await showDatePicker(
          context: context,
          initialDate: nilai ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (dipilih != null) onBerubah(dipilih);
      },
      child: InputDecorator(
        decoration: dekorasiInput(label, ikon: Icons.calendar_month_outlined)
            .copyWith(
          suffixIcon: bolehKosong && nilai != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onBerubah(null),
                )
              : null,
        ),
        child: Text(
          nilai == null ? '-' : keTeksTampil(nilai),
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}

/// Chip kecil berwarna untuk status (gizi, jadwal, kategori).
class ChipStatus extends StatelessWidget {
  final String teks;
  final Color warna;

  const ChipStatus({super.key, required this.teks, required this.warna});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: warna.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warna.withOpacity(0.45)),
      ),
      child: Text(
        teks,
        style: TextStyle(
          color: warna,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Kartu statistik Beranda gaya desktop: judul kapital kecil, angka besar
/// berwarna, subjudul abu-abu, ikon berwarna.
class KartuStatistik extends StatelessWidget {
  final String judul;
  final String nilai;
  final String subJudul;
  final Color warna;
  final IconData ikon;

  const KartuStatistik({
    super.key,
    required this.judul,
    required this.nilai,
    required this.subJudul,
    required this.warna,
    required this.ikon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    judul.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                Icon(ikon, color: warna, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              nilai,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: warna,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subJudul,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tampilan saat daftar kosong.
class TampilanKosong extends StatelessWidget {
  final String pesan;
  const TampilanKosong({super.key, required this.pesan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 56, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotak pencarian standar di atas daftar.
class KotakCari extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onBerubah;

  const KotakCari({super.key, required this.hint, required this.onBerubah});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        decoration: dekorasiInput('', ikon: Icons.search, hint: hint)
            .copyWith(labelText: null, contentPadding: const EdgeInsets.all(12)),
        onChanged: onBerubah,
      ),
    );
  }
}
