import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'data/who_lms.dart';

/// Satu titik pengukuran anak pada kurva (x = umur dalam bulan pecahan).
class TitikKurva {
  final double bulan;
  final double nilai;

  const TitikKurva(this.bulan, this.nilai);
}

final Map<String, List<List<double>>> _cacheLms = {};

/// Parse tabel LMS "L,M,S;L,M,S;..." menjadi daftar per bulan (0..60).
List<List<double>> _parseLms(String mentah) {
  return _cacheLms.putIfAbsent(
    mentah,
    () => mentah
        .split(';')
        .map((t) => t.split(',').map((e) => double.parse(e)).toList())
        .toList(),
  );
}

/// Nilai acuan WHO pada skor z tertentu: M * (1 + L*S*z)^(1/L).
double _nilaiZ(List<double> lms, double z) {
  final l = lms[0], m = lms[1], s = lms[2];
  if (l == 0) return m * math.exp(s * z);
  return m * math.pow(1 + l * s * z, 1 / l).toDouble();
}

/// Tiga garis acuan (median, +2SD, -2SD) pada umur bulan pecahan,
/// dengan interpolasi linear antarbulan seperti perhitungan Z-Score.
List<double> _garisAcuan(List<List<double>> tabel, double bulan) {
  final i = bulan.floor().clamp(0, tabel.length - 2);
  final f = (bulan - i).clamp(0.0, 1.0);
  final a = tabel[i], b = tabel[i + 1];
  final lms = [
    a[0] + (b[0] - a[0]) * f,
    a[1] + (b[1] - a[1]) * f,
    a[2] + (b[2] - a[2]) * f,
  ];
  return [_nilaiZ(lms, 0), _nilaiZ(lms, 2), _nilaiZ(lms, -2)];
}

/// Skala gambar kurva: batas sumbu dan pemetaan nilai ke piksel.
/// Dipakai bersama oleh pelukis dan oleh penanganan sentuhan,
/// supaya titik yang diketuk sama persis dengan titik yang digambar.
class _Skala {
  static const padKiri = 30.0;
  static const padBawah = 16.0;
  static const padAtas = 8.0;
  static const padKanan = 8.0;

  final double xMaks;
  final double yMin;
  final double yMaks;

  const _Skala(this.xMaks, this.yMin, this.yMaks);

  factory _Skala.hitung(List<List<double>> tabel, List<TitikKurva> titik) {
    var xMaks = 24.0;
    for (final t in titik) {
      xMaks = math.max(xMaks, t.bulan + 4);
    }
    xMaks = math.min(xMaks, 61.0);

    var yMin = double.infinity;
    var yMaks = -double.infinity;
    for (var x = 0.0; x <= xMaks; x += 2) {
      final g = _garisAcuan(tabel, x);
      yMin = math.min(yMin, g[2]);
      yMaks = math.max(yMaks, g[1]);
    }
    for (final t in titik) {
      yMin = math.min(yMin, t.nilai);
      yMaks = math.max(yMaks, t.nilai);
    }
    if (!yMin.isFinite || !yMaks.isFinite) {
      yMin = 0;
      yMaks = 10;
    }
    final rentang = (yMaks - yMin).abs() < 0.001 ? 1.0 : (yMaks - yMin);
    return _Skala(xMaks, yMin - rentang * 0.12, yMaks + rentang * 0.12);
  }

  double px(Size size, double bulan) =>
      padKiri + (bulan / xMaks) * (size.width - padKiri - padKanan);

  double py(Size size, double nilai) =>
      padAtas +
      (size.height - padAtas - padBawah) -
      ((nilai - yMin) / (yMaks - yMin)) *
          (size.height - padAtas - padBawah);
}

/// Kurva pertumbuhan WHO interaktif: zona normal (-2SD s.d. +2SD)
/// hijau muda, garis median dan batas SD, titik anak garis hijau tua.
/// Ketuk atau geser pada kurva untuk memilih titik pengukuran dan
/// melihat umur serta nilainya.
class KurvaPertumbuhan extends StatefulWidget {
  final String jenisKelamin; // 'L' atau 'P'
  final bool berat; // true = BB/U (kg), false = TB/U (cm)

  /// true = LK/U (cm); mengabaikan [berat]. Tabel WHO hanya 0-60 bulan.
  final bool lingkarKepala;
  final List<TitikKurva> titik;

  const KurvaPertumbuhan({
    super.key,
    required this.jenisKelamin,
    required this.berat,
    required this.titik,
    this.lingkarKepala = false,
  });

  @override
  State<KurvaPertumbuhan> createState() => _KurvaPertumbuhanState();
}

class _KurvaPertumbuhanState extends State<KurvaPertumbuhan> {
  int? _dipilih;

  List<TitikKurva> get _urut =>
      [...widget.titik]..sort((a, b) => a.bulan.compareTo(b.bulan));

  List<List<double>> get _tabel => _parseLms(widget.lingkarKepala
      ? (widget.jenisKelamin == 'P' ? kHCFA_PEREMPUAN : kHCFA_LAKI)
      : widget.berat
          ? (widget.jenisKelamin == 'P' ? kWFA_PEREMPUAN : kWFA_LAKI)
          : (widget.jenisKelamin == 'P' ? kLHFA_PEREMPUAN : kLHFA_LAKI));

  void _sentuh(Offset lokal, Size ukuran) {
    final urut = _urut;
    if (urut.isEmpty) return;
    final skala = _Skala.hitung(_tabel, urut);
    var terbaik = 0;
    var jarakTerbaik = double.infinity;
    for (var i = 0; i < urut.length; i++) {
      final o = Offset(
        skala.px(ukuran, urut[i].bulan),
        skala.py(ukuran, urut[i].nilai),
      );
      final j = (o - lokal).distance;
      if (j < jarakTerbaik) {
        jarakTerbaik = j;
        terbaik = i;
      }
    }
    if (_dipilih != terbaik) setState(() => _dipilih = terbaik);
  }

  String _teksInfo() {
    final urut = _urut;
    if (urut.isEmpty) return 'Belum ada data pengukuran.';
    final i = _dipilih ?? urut.length - 1;
    final t = urut[i];
    final umur = t.bulan == t.bulan.roundToDouble()
        ? '${t.bulan.toInt()} bulan'
        : '${t.bulan.toStringAsFixed(1)} bulan';
    final satuan = widget.berat && !widget.lingkarKepala ? 'kg' : 'cm';
    final label =
        widget.lingkarKepala ? 'LK' : (widget.berat ? 'BB' : 'TB');
    return 'Umur $umur: $label ${t.nilai.toStringAsFixed(1)} $satuan';
  }

  @override
  Widget build(BuildContext context) {
    final urut = _urut;
    final dipilih = _dipilih ?? (urut.isEmpty ? null : urut.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.55,
          child: LayoutBuilder(
            builder: (ctx, batas) {
              final ukuran = Size(batas.maxWidth, batas.maxHeight);
              return GestureDetector(
                onTapDown: (d) => _sentuh(d.localPosition, ukuran),
                onHorizontalDragUpdate: (d) =>
                    _sentuh(d.localPosition, ukuran),
                child: CustomPaint(
                  painter: _PelukisKurva(
                    tabel: _tabel,
                    titik: widget.titik,
                    dipilih: dipilih,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.touch_app_outlined,
                size: 14, color: Color(0xFF1E7A46)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                urut.isEmpty ? _teksInfo() : '${_teksInfo()} (ketuk titik lain untuk berpindah)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E7A46),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Row(
          children: [
            _Legenda(warna: Color(0xFF1E7A46), teks: 'Anak'),
            SizedBox(width: 12),
            _Legenda(warna: Color(0xFF94A3B8), teks: 'Median WHO'),
            SizedBox(width: 12),
            _Legenda(warna: Color(0xFFF59E0B), teks: 'Batas ±2SD'),
          ],
        ),
      ],
    );
  }
}

class _Legenda extends StatelessWidget {
  final Color warna;
  final String teks;

  const _Legenda({required this.warna, required this.teks});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 3, color: warna),
        const SizedBox(width: 5),
        Text(teks,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
      ],
    );
  }
}

class _PelukisKurva extends CustomPainter {
  final List<List<double>> tabel;
  final List<TitikKurva> titik;
  final int? dipilih;

  _PelukisKurva({required this.tabel, required this.titik, this.dipilih});

  @override
  void paint(Canvas canvas, Size size) {
    final skala = _Skala.hitung(tabel, titik);
    const padKiri = _Skala.padKiri;
    const padAtas = _Skala.padAtas;
    final w = size.width - _Skala.padKiri - _Skala.padKanan;
    final h = size.height - _Skala.padAtas - _Skala.padBawah;
    final xMaks = skala.xMaks;
    final yMin = skala.yMin;
    final yMaks = skala.yMaks;

    double px(double bulan) => skala.px(size, bulan);
    double py(double nilai) => skala.py(size, nilai);

    // Zona normal antara -2SD dan +2SD
    final zona = Path();
    final zonaBawah = Path();
    for (var x = 0.0; x <= xMaks; x += 1) {
      final g = _garisAcuan(tabel, x);
      if (x == 0) {
        zona.moveTo(px(x), py(g[1]));
        zonaBawah.moveTo(px(x), py(g[2]));
      } else {
        zona.lineTo(px(x), py(g[1]));
        zonaBawah.lineTo(px(x), py(g[2]));
      }
    }
    final zonaPenuh = Path.from(zona);
    final titikBawah = <Offset>[];
    for (var x = xMaks; x >= 0; x -= 1) {
      final g = _garisAcuan(tabel, x);
      titikBawah.add(Offset(px(x), py(g[2])));
    }
    for (final o in titikBawah) {
      zonaPenuh.lineTo(o.dx, o.dy);
    }
    zonaPenuh.close();
    canvas.drawPath(
      zonaPenuh,
      Paint()..color = const Color(0xFF22C55E).withOpacity(0.10),
    );

    // Garis acuan: median + batas SD
    void gambarGaris(int idx, Color warna, double tebal) {
      final path = Path();
      for (var x = 0.0; x <= xMaks; x += 1) {
        final g = _garisAcuan(tabel, x);
        if (x == 0) {
          path.moveTo(px(x), py(g[idx]));
        } else {
          path.lineTo(px(x), py(g[idx]));
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = warna
          ..style = PaintingStyle.stroke
          ..strokeWidth = tebal,
      );
    }

    gambarGaris(1, const Color(0xFFF59E0B), 1.2);
    gambarGaris(2, const Color(0xFFF59E0B), 1.2);
    gambarGaris(0, const Color(0xFF94A3B8), 1.2);

    // Garis bantu + label sumbu Y (4 tingkat)
    final catGaris = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.7;
    for (var i = 0; i <= 3; i++) {
      final nilai = yMin + (yMaks - yMin) * i / 3;
      final y = py(nilai);
      canvas.drawLine(Offset(padKiri, y), Offset(padKiri + w, y), catGaris);
      final tp = TextPainter(
        text: TextSpan(
          text: nilai.toStringAsFixed(nilai >= 20 ? 0 : 1),
          style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padKiri - tp.width - 3, y - tp.height / 2));
    }

    // Label sumbu X tiap 12 bulan
    for (var m = 0; m <= xMaks; m += 12) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$m',
          style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px(m.toDouble()) - tp.width / 2, padAtas + h + 3));
    }
    final tpBln = TextPainter(
      text: const TextSpan(
        text: 'bulan',
        style: TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpBln.paint(canvas, Offset(padKiri + w - tpBln.width, padAtas + h + 3));

    // Titik dan garis anak
    if (titik.isNotEmpty) {
      final urut = [...titik]..sort((a, b) => a.bulan.compareTo(b.bulan));
      final path = Path();
      for (var i = 0; i < urut.length; i++) {
        final o = Offset(px(urut[i].bulan), py(urut[i].nilai));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF1E7A46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
      for (var i = 0; i < urut.length; i++) {
        final t = urut[i];
        final o = Offset(px(t.bulan), py(t.nilai));
        if (dipilih != null && i == dipilih) {
          // Titik terpilih: garis penuntun + lingkaran sorot.
          canvas.drawLine(
            Offset(o.dx, padAtas),
            Offset(o.dx, padAtas + h),
            Paint()
              ..color = const Color(0xFF1E7A46).withOpacity(0.35)
              ..strokeWidth = 1,
          );
          canvas.drawCircle(
            o,
            8,
            Paint()
              ..color = const Color(0xFF1E7A46).withOpacity(0.18),
          );
          canvas.drawCircle(
            o,
            5,
            Paint()
              ..color = const Color(0xFF1E7A46)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
        canvas.drawCircle(o, 3.6, Paint()..color = const Color(0xFF1E7A46));
        canvas.drawCircle(o, 1.7, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisKurva oldDelegate) =>
      oldDelegate.tabel != tabel ||
      oldDelegate.titik != titik ||
      oldDelegate.dipilih != dipilih;
}
