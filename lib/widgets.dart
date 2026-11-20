import 'package:flutter/material.dart';

import 'format.dart';

/// Palet redesign v1.3: hijau daun GrowTrack di atas kertas hangat.
/// Nama variabel lama dipertahankan agar seluruh layar ikut berubah.
const Color kTeal = Color(0xFF1E7A46);
const Color kHijauTerang = Color(0xFF2FA84F);
const Color kLatar = Color(0xFFF7F5EF);
const Color kTinta = Color(0xFF1C2A21);
const Color kRisiko = Color(0xFFC0392B);
const Color kObservasi = Color(0xFF9A6B14);

/// Transisi halaman global: halaman baru masuk memudar sambil naik
/// pelan, halaman lama sedikit mengecil dan meredup (rasa kedalaman),
/// supaya perpindahan layar tidak kaku.
class PembuatTransisiHalus extends PageTransitionsBuilder {
  const PembuatTransisiHalus();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final masuk = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final keluar = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.045),
        end: Offset.zero,
      ).animate(masuk),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(masuk),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.86).animate(keluar),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: 0.985).animate(keluar),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Animasi masuk sekali jalan: konten memudar sambil naik pelan, dengan
/// jeda berjenjang mengikuti [indeks] agar daftar dan kartu terasa hidup.
class AnimasiMasuk extends StatefulWidget {
  final Widget child;
  final int indeks;

  const AnimasiMasuk({super.key, required this.child, this.indeks = 0});

  @override
  State<AnimasiMasuk> createState() => _AnimasiMasukState();
}

class _AnimasiMasukState extends State<AnimasiMasuk>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol;

  @override
  void initState() {
    super.initState();
    _kontrol = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    final jeda = widget.indeks.clamp(0, 8) * 55;
    if (jeda == 0) {
      _kontrol.forward();
    } else {
      Future.delayed(Duration(milliseconds: jeda), () {
        if (mounted) _kontrol.forward();
      });
    }
  }

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kurva = CurvedAnimation(parent: _kontrol, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: kurva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(kurva),
        child: widget.child,
      ),
    );
  }
}

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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(pesan),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
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
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
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
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_outlined,
                  size: 40, color: Color(0xFF94A3B8)),
            ),
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

class _HasilCari<T> {
  const _HasilCari(this.nilai);
  final T? nilai;
}

/// Kolom pemilih entitas yang bisa dicari dengan mengetik nama.
///
/// Pengganti dropdown untuk daftar panjang seperti balita, orang tua, dan
/// vaksin: ketuk kolomnya, lalu ketik nama pada kotak pencarian di dialog.
class KolomPilihCari<T> extends StatelessWidget {
  final String label;
  final String petunjuk;
  final T? nilai;
  final List<T> daftar;
  final String Function(T item) labelItem;
  final ValueChanged<T?> onBerubah;
  final bool bolehKosong;
  final String labelKosong;

  const KolomPilihCari({
    super.key,
    required this.label,
    required this.petunjuk,
    required this.nilai,
    required this.daftar,
    required this.labelItem,
    required this.onBerubah,
    this.bolehKosong = false,
    this.labelKosong = '- Tidak Ada -',
  });

  Future<void> _buka(BuildContext context) async {
    final hasil = await showDialog<_HasilCari<T>>(
      context: context,
      builder: (ctx) {
        var kata = '';
        return StatefulBuilder(
          builder: (ctx, atur) {
            final saring = daftar
                .where((e) =>
                    kata.isEmpty ||
                    labelItem(e).toLowerCase().contains(kata.toLowerCase()))
                .toList();
            return AlertDialog(
              title: Text('Pilih $label',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              content: SizedBox(
                width: double.maxFinite,
                height: 430,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: dekorasiInput('',
                              ikon: Icons.search,
                              hint: 'Ketik nama untuk mencari...')
                          .copyWith(
                              labelText: null,
                              contentPadding: const EdgeInsets.all(12)),
                      onChanged: (v) => atur(() => kata = v.trim()),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          if (bolehKosong)
                            ListTile(
                              leading: const Icon(Icons.block_outlined),
                              title: Text(labelKosong),
                              onTap: () =>
                                  Navigator.pop(ctx, _HasilCari<T>(null)),
                            ),
                          if (saring.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                kata.isEmpty
                                    ? 'Daftar masih kosong.'
                                    : 'Tidak ada hasil untuk "$kata".',
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(color: Color(0xFF64748B)),
                              ),
                            ),
                          for (final item in saring)
                            ListTile(
                              title: Text(labelItem(item),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              trailing: nilai == item
                                  ? const Icon(Icons.check_circle,
                                      color: kTeal)
                                  : null,
                              onTap: () =>
                                  Navigator.pop(ctx, _HasilCari<T>(item)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
              ],
            );
          },
        );
      },
    );
    if (hasil != null) onBerubah(hasil.nilai);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _buka(context),
      child: InputDecorator(
        decoration: dekorasiInput(label)
            .copyWith(suffixIcon: const Icon(Icons.search)),
        child: Text(
          nilai == null ? petunjuk : labelItem(nilai as T),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nilai == null
              ? const TextStyle(color: Color(0xFF94A3B8))
              : null,
        ),
      ),
    );
  }
}

/// Gaya karakter untuk [AvatarKarakter].
enum GayaKarakter { anakLaki, anakPerempuan, bayi, ibu, ibuHijab, kader }

/// Avatar karakter bergambar (bukan inisial, bukan ikon generik):
/// wajah digambar vektor oleh [_PelukisKarakter], variasi warna
/// ditentukan dari hash nama agar tiap orang konsisten tampilannya.
class AvatarKarakter extends StatelessWidget {
  final GayaKarakter gaya;
  final String nama;
  final double ukuran;

  const AvatarKarakter({
    super.key,
    required this.gaya,
    required this.nama,
    this.ukuran = 44,
  });

  /// Avatar anak: bayi bila umur di bawah 12 bulan, selain itu
  /// mengikuti jenis kelamin ('P' perempuan, lainnya laki-laki).
  factory AvatarKarakter.anak({
    Key? key,
    required String nama,
    String? jenisKelamin,
    DateTime? tglLahir,
    double ukuran = 44,
  }) {
    var gaya = jenisKelamin == 'P'
        ? GayaKarakter.anakPerempuan
        : GayaKarakter.anakLaki;
    if (tglLahir != null) {
      final now = DateTime.now();
      var bulan = (now.year - tglLahir.year) * 12 + (now.month - tglLahir.month);
      if (now.day < tglLahir.day) bulan--;
      if (bulan < 12) gaya = GayaKarakter.bayi;
    }
    return AvatarKarakter(key: key, gaya: gaya, nama: nama, ukuran: ukuran);
  }

  /// Avatar ibu: sebagian tampil berhijab mengikuti hash nama.
  factory AvatarKarakter.ibu({
    Key? key,
    required String nama,
    double ukuran = 44,
  }) {
    final h = nama.codeUnits.fold<int>(0, (a, b) => a + b);
    return AvatarKarakter(
      key: key,
      gaya: h.isEven ? GayaKarakter.ibuHijab : GayaKarakter.ibu,
      nama: nama,
      ukuran: ukuran,
    );
  }

  /// Avatar kader: berhijab hijau khas Posyandu.
  factory AvatarKarakter.kader({
    Key? key,
    required String nama,
    double ukuran = 44,
  }) {
    return AvatarKarakter(
      key: key,
      gaya: GayaKarakter.kader,
      nama: nama,
      ukuran: ukuran,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(ukuran),
      painter: _PelukisKarakter(gaya: gaya, nama: nama),
    );
  }
}

class _PelukisKarakter extends CustomPainter {
  final GayaKarakter gaya;
  final String nama;

  const _PelukisKarakter({required this.gaya, required this.nama});

  static const _kulit = [
    Color(0xFFF2C29B),
    Color(0xFFE8B088),
    Color(0xFFF6CFA8),
    Color(0xFFD99E6A),
  ];
  static const _rambut = [
    Color(0xFF3E2A20),
    Color(0xFF5A3A22),
    Color(0xFF2E1D12),
    Color(0xFF4A3226),
  ];
  static const _baju = [
    Color(0xFF2FA84F),
    Color(0xFF4A7FD4),
    Color(0xFFC65D8F),
    Color(0xFF7A6FD0),
    Color(0xFF3AA79B),
    Color(0xFFE9A23B),
  ];
  static const _latar = [
    Color(0xFFDFF2E4),
    Color(0xFFFDEBD2),
    Color(0xFFDCE9FA),
    Color(0xFFFBE3EF),
    Color(0xFFE6E1FA),
    Color(0xFFD8F0EC),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48.0;
    canvas.scale(s);
    final h = nama.codeUnits.fold<int>(0, (a, b) => a + b);
    final skin = _kulit[h % _kulit.length];
    final hair = _rambut[(h ~/ 3) % _rambut.length];
    final cloth = _baju[(h ~/ 5) % _baju.length];
    final bg = _latar[(h ~/ 7) % _latar.length];
    final hijab = gaya == GayaKarakter.kader
        ? const Color(0xFF1E7A46)
        : cloth;

    canvas.clipRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 48, 48),
      const Radius.circular(14),
    ));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 48, 48), Paint()..color = bg);

    // Bahu / baju.
    final bahu = Path()
      ..moveTo(7, 48)
      ..quadraticBezierTo(24, 36.5, 41, 48)
      ..close();
    canvas.drawPath(bahu, Paint()..color = cloth);

    final berhijab =
        gaya == GayaKarakter.ibuHijab || gaya == GayaKarakter.kader;
    if (berhijab) {
      canvas.drawCircle(const Offset(24, 21.5), 15.2, Paint()..color = hijab);
      final drape = Path()
        ..moveTo(10.5, 26)
        ..quadraticBezierTo(24, 34, 37.5, 26)
        ..lineTo(37.5, 48)
        ..lineTo(10.5, 48)
        ..close();
      canvas.drawPath(drape, Paint()..color = hijab);
    } else {
      canvas.drawCircle(const Offset(13.8, 24.5), 2, Paint()..color = skin);
      canvas.drawCircle(const Offset(34.2, 24.5), 2, Paint()..color = skin);
      if (gaya == GayaKarakter.anakPerempuan) {
        canvas.drawCircle(const Offset(12.4, 27.5), 4.4, Paint()..color = hair);
        canvas.drawCircle(const Offset(35.6, 27.5), 4.4, Paint()..color = hair);
      }
      if (gaya == GayaKarakter.ibu) {
        canvas.drawCircle(const Offset(24, 9.6), 3.7, Paint()..color = hair);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(12.2, 20, 3.6, 13), const Radius.circular(1.8)),
          Paint()..color = hair,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(32.2, 20, 3.6, 13), const Radius.circular(1.8)),
          Paint()..color = hair,
        );
      }
    }

    // Wajah.
    canvas.drawCircle(const Offset(24, 24.5), 10.6, Paint()..color = skin);

    if (!berhijab) {
      // Poni: lingkaran rambut di belakang wajah, digeser ke atas.
      canvas.save();
      canvas.clipPath(Path()
        ..addOval(Rect.fromCircle(center: const Offset(24, 24.5), radius: 10.6)));
      canvas.drawCircle(
        const Offset(24, 13.5),
        gaya == GayaKarakter.bayi ? 9.8 : 10.2,
        Paint()..color = hair,
      );
      canvas.restore();
      if (gaya == GayaKarakter.anakPerempuan) {
        final pita = Paint()..color = const Color(0xFFE2607E);
        final kiri = Path()
          ..moveTo(24, 12.6)
          ..lineTo(17.6, 9.2)
          ..lineTo(18.4, 15.2)
          ..close();
        final kanan = Path()
          ..moveTo(24, 12.6)
          ..lineTo(30.4, 9.2)
          ..lineTo(29.6, 15.2)
          ..close();
        canvas.drawPath(kiri, pita);
        canvas.drawPath(kanan, pita);
        canvas.drawCircle(const Offset(24, 12.4), 1.7, pita);
      }
      if (gaya == GayaKarakter.bayi) {
        final jambul = Paint()
          ..color = hair
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.9
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          const Rect.fromLTWH(22.4, 8.6, 6.4, 5.4),
          3.5,
          1.9,
          false,
          jambul,
        );
      }
    }

    // Mata, pipi, senyum.
    final mata = Paint()..color = const Color(0xFF33302B);
    canvas.drawCircle(const Offset(20.1, 24.8), 1.35, mata);
    canvas.drawCircle(const Offset(27.9, 24.8), 1.35, mata);
    final pipi = Paint()..color = const Color(0xFFF0997F).withOpacity(0.55);
    canvas.drawOval(const Rect.fromLTWH(15.5, 28, 3.8, 2.4), pipi);
    canvas.drawOval(const Rect.fromLTWH(28.7, 28, 3.8, 2.4), pipi);
    final senyum = Paint()
      ..color = const Color(0xFFA05C2C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final mulut = Path()
      ..moveTo(20.6, 28.9)
      ..quadraticBezierTo(24, 31.6, 27.4, 28.9);
    canvas.drawPath(mulut, senyum);
  }

  @override
  bool shouldRepaint(covariant _PelukisKarakter oldDelegate) =>
      oldDelegate.gaya != gaya || oldDelegate.nama != nama;
}
