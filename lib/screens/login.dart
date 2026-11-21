import 'package:flutter/material.dart';

import '../db/database.dart';
import '../session.dart';
import '../sync/update_service.dart';
import '../widgets.dart';
import 'beranda_orang_tua.dart';
import 'info.dart';
import 'utama.dart';

/// Layar masuk: kepala hijau berisi logo dan identitas posyandu,
/// kartu formulir, tombol info aplikasi, dan hak cipta KKP UNINDRA.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _txtUsername = TextEditingController();
  final _txtPassword = TextEditingController();
  String _namaPosyandu = 'Posyandu Beringin DDN';
  String? _pesanSalah;
  bool _proses = false;
  bool _sembunyiPassword = true;

  @override
  void initState() {
    super.initState();
    _muatProfil();
  }

  Future<void> _muatProfil() async {
    try {
      final pg = await GrowTrackDB.ambilPengaturan();
      if (mounted && (pg.namaPosyandu ?? '').isNotEmpty) {
        setState(() => _namaPosyandu = pg.namaPosyandu!);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _txtUsername.dispose();
    _txtPassword.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    final username = _txtUsername.text.trim();
    final password = _txtPassword.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _pesanSalah = 'Nama pengguna dan kata sandi wajib diisi.');
      return;
    }
    setState(() {
      _proses = true;
      _pesanSalah = null;
    });
    final salah = await GrowTrackDB.validasiLogin(username, password);
    if (!mounted) return;
    setState(() => _proses = false);
    if (salah != null) {
      setState(() => _pesanSalah = salah);
      return;
    }
    final nama = SesiUser.namaLengkap ?? username;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => SesiUser.isOrangTua
              ? const BerandaOrangTuaScreen()
              : const UtamaScreen()),
    );
    tampilSnack(context, 'Selamat datang, $nama!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLatar,
      body: Column(
        children: [
          // ---- Kepala hijau ----
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E7A46), Color(0xFF14532D)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(34),
                bottomRight: Radius.circular(34),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(
                    top: 2,
                    right: 6,
                    child: IconButton(
                      icon: const Icon(Icons.info_outline,
                          color: Colors.white, size: 24),
                      tooltip: 'Info Aplikasi',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const InfoScreen()),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
                    child: Column(
                      children: [
                        AnimasiMasuk(
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(7),
                            child: ClipOval(
                              child: Image.asset(
                                  'assets/icon/posyandu-logo.png',
                                  fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'GrowTrack',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _namaPosyandu,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Sistem Informasi Monitoring Tumbuh Kembang Anak Terpadu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ---- Formulir ----
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimasiMasuk(
                      indeks: 1,
                      child: Card(
                        color: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Selamat Datang',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1C2A21),
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Silakan masuk dengan akun Anda.',
                                style: TextStyle(
                                    color: Color(0xFF64748B), fontSize: 13),
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _txtUsername,
                                decoration: dekorasiInput('NAMA PENGGUNA',
                                    ikon: Icons.person_outline),
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _txtPassword,
                                obscureText: _sembunyiPassword,
                                decoration: dekorasiInput('KATA SANDI',
                                        ikon: Icons.lock_outline)
                                    .copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(_sembunyiPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() =>
                                        _sembunyiPassword =
                                            !_sembunyiPassword),
                                  ),
                                ),
                                onSubmitted: (_) => _masuk(),
                              ),
                              if (_pesanSalah != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: Color(0xFFEF4444), size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _pesanSalah!,
                                          style: const TextStyle(
                                              color: Color(0xFFB91C1C)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _proses ? null : _masuk,
                                style: FilledButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: _proses
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text(
                                        'MASUK',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.6),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ---- Kaki ----
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                Text(
                  'Versi $kNamaVersiIni',
                  style:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                ),
                const SizedBox(height: 2),
                const Text(
                  '© 2026 KKP Teknik Informatika UNINDRA',
                  style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
