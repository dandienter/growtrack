import 'package:flutter/material.dart';

import '../db/database.dart';
import '../session.dart';
import '../widgets.dart';
import 'beranda_orang_tua.dart';
import 'login.dart';
import 'utama.dart';

/// Layar pembuka HD: logo Posyandu resolusi penuh, nama aplikasi dan
/// tagline. Menahan sesi dipulihkan dulu, lalu mengarahkan sesuai peran
/// akun (Kader ke cangkang utama, Orang Tua ke berandanya sendiri).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _namaPosyandu = 'Posyandu Beringin DDN';

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  Future<void> _mulai() async {
    final tunda = Future.delayed(const Duration(milliseconds: 1700));
    var sudahLogin = false;
    try {
      final pg = await GrowTrackDB.ambilPengaturan();
      _namaPosyandu = pg.namaPosyandu ?? '';
      sudahLogin = await GrowTrackDB.pulihkanSesi();
    } catch (_) {}
    await tunda;
    if (!mounted) return;
    final tujuan = !sudahLogin
        ? const LoginScreen()
        : SesiUser.isOrangTua
            ? const BerandaOrangTuaScreen()
            : const UtamaScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => tujuan,
        transitionsBuilder: (_, anim, __, anak) =>
            FadeTransition(opacity: anim, child: anak),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLatar,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimasiMasuk(
                indeks: 0,
                child: Container(
                  width: 168,
                  height: 168,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kTeal.withOpacity(0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icon/posyandu-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              AnimasiMasuk(
                indeks: 1,
                child: const Text(
                  'GrowTrack',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: kTeal,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AnimasiMasuk(
                indeks: 2,
                child: const Text(
                  'Sistem Informasi Monitoring\nTumbuh Kembang Anak Terpadu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: kTeal,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _namaPosyandu.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
