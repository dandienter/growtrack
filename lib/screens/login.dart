import 'package:flutter/material.dart';

import '../db/database.dart';
import '../session.dart';
import '../widgets.dart';
import 'utama.dart';

/// Port tampilan/MenuLogin.java.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _txtUsername = TextEditingController();
  final _txtPassword = TextEditingController();
  String _rolePilihan = 'Admin';
  String _namaPosyandu = '';
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
      if (mounted) {
        setState(() => _namaPosyandu = pg.namaPosyandu ?? '');
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
      setState(() => _pesanSalah = 'Username dan Password wajib diisi!');
      return;
    }
    setState(() {
      _proses = true;
      _pesanSalah = null;
    });
    final salah =
        await GrowTrackDB.validasiLogin(username, password, _rolePilihan);
    if (!mounted) return;
    setState(() => _proses = false);
    if (salah != null) {
      setState(() => _pesanSalah = salah);
      return;
    }
    final nama = SesiUser.namaLengkap ?? username;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const UtamaScreen()),
    );
    tampilSnack(context, 'Selamat datang, $nama!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimasiMasuk(
                    child: Image.asset('assets/icon/posyandu-logo.png', height: 150),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'GROWTRACK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: kTeal,
                      letterSpacing: 1.5,
                    ),
                  ),
                  if (_namaPosyandu.isNotEmpty)
                    Text(
                      _namaPosyandu,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'Silakan masuk untuk melanjutkan',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _txtUsername,
                    decoration: dekorasiInput('USERNAME',
                        ikon: Icons.person_outline),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _txtPassword,
                    obscureText: _sembunyiPassword,
                    decoration:
                        dekorasiInput('PASSWORD', ikon: Icons.lock_outline)
                            .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_sembunyiPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                            () => _sembunyiPassword = !_sembunyiPassword),
                      ),
                    ),
                    onSubmitted: (_) => _masuk(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _rolePilihan,
                    decoration:
                        dekorasiInput('MASUK SEBAGAI', ikon: Icons.badge_outlined),
                    items: const ['Admin', 'Petugas']
                        .map((r) =>
                            DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _rolePilihan = v ?? 'Admin'),
                  ),
                  if (_pesanSalah != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pesanSalah!,
                              style:
                                  const TextStyle(color: Color(0xFFB91C1C)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _proses ? null : _masuk,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _proses
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'MASUK SISTEM',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
