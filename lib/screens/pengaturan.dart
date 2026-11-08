import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../db/database.dart';
import '../models.dart';
import '../session.dart';
import '../widgets.dart';

/// Port tampilan/FormPengaturan.java: identitas posyandu + manajemen akun.
/// (Tab Backup & Restore MySQL lama digantikan fitur Kelola Database
/// karena aplikasi ini memakai SQLite lokal.)
class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Profil
  final _txtNama = TextEditingController();
  final _txtAlamat = TextEditingController();
  final _txtTelp = TextEditingController();
  final _txtKota = TextEditingController();
  final _txtKetua = TextEditingController();
  final _txtLogo = TextEditingController();

  // Pengguna
  List<UserAkun> _pengguna = [];
  String _cariUser = '';
  bool _memuatUser = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
    _muatProfil();
    _muatPengguna();
  }

  @override
  void dispose() {
    _tab.dispose();
    _txtNama.dispose();
    _txtAlamat.dispose();
    _txtTelp.dispose();
    _txtKota.dispose();
    _txtKetua.dispose();
    _txtLogo.dispose();
    super.dispose();
  }

  Future<void> _muatProfil() async {
    final pg = await GrowTrackDB.ambilPengaturan();
    if (!mounted) return;
    setState(() {
      _txtNama.text = pg.namaPosyandu ?? '';
      _txtAlamat.text = pg.alamat ?? '';
      _txtTelp.text = pg.noTelepon ?? '';
      _txtKota.text = pg.kota ?? '';
      _txtKetua.text = pg.namaKetua ?? '';
      _txtLogo.text = pg.logoPath ?? '';
    });
  }

  Future<void> _pilihLogo() async {
    final hasil = await FilePicker.pickFiles(type: FileType.image);
    if (hasil.isEmpty || hasil.first.path == null) return;
    final sumber = File(hasil.first.path!);
    final dirDb = p.dirname(await GrowTrackDB.jalurDb());
    final ekstensi = p.extension(sumber.path);
    final tujuan = File(p.join(
        dirDb, 'logo_posyandu_${DateTime.now().millisecondsSinceEpoch}$ekstensi'));
    await sumber.copy(tujuan.path);
    if (!mounted) return;
    setState(() => _txtLogo.text = tujuan.path);
    tampilSnack(context, 'Logo berhasil dipilih!');
  }

  Future<void> _simpanProfil() async {
    final pg = Pengaturan(
      namaPosyandu: _txtNama.text.trim(),
      alamat: _txtAlamat.text.trim(),
      noTelepon: _txtTelp.text.trim(),
      namaKetua: _txtKetua.text.trim(),
      kota: _txtKota.text.trim(),
      logoPath: _txtLogo.text.trim().isEmpty ? null : _txtLogo.text.trim(),
    );
    await GrowTrackDB.simpanPengaturan(pg);
    if (!mounted) return;
    tampilSnack(context, 'Identitas Posyandu/Klinik berhasil diperbarui!');
  }

  Future<void> _muatPengguna() async {
    final data = await GrowTrackDB.ambilUsers(cari: _cariUser);
    if (!mounted) return;
    setState(() {
      _pengguna = data;
      _memuatUser = false;
    });
  }

  Future<void> _formPengguna([UserAkun? u]) async {
    final txtUser = TextEditingController(text: u?.username ?? '');
    final txtPass = TextEditingController();
    final txtNama = TextEditingController(text: u?.namaLengkap ?? '');
    var role = u?.role ?? 'Petugas';
    final simpan = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(u == null ? 'Tambah Pengguna' : 'Ubah Pengguna'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: txtNama,
                decoration: dekorasiInput('Nama Lengkap'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: txtUser,
                decoration: dekorasiInput('Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: txtPass,
                obscureText: true,
                decoration: dekorasiInput(u == null
                    ? 'Password'
                    : 'Password Baru (kosongkan bila tidak diubah)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: dekorasiInput('Hak Akses (Role)'),
                items: const [
                  DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'Petugas', child: Text('Petugas')),
                ],
                onChanged: (v) => role = v!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (simpan != true) return;
    if (txtNama.text.trim().isEmpty ||
        txtUser.text.trim().isEmpty ||
        (u == null && txtPass.text.isEmpty)) {
      tampilSnack(context, 'Nama, Username, dan Password wajib diisi!');
      return;
    }
    try {
      if (u == null) {
        await GrowTrackDB.tambahUser(
          username: txtUser.text.trim(),
          password: txtPass.text,
          namaLengkap: txtNama.text.trim(),
          role: role,
        );
        if (!mounted) return;
        tampilSnack(context, 'Pengguna baru berhasil ditambahkan!');
      } else {
        await GrowTrackDB.ubahUser(
          idUser: u.idUser,
          username: txtUser.text.trim(),
          namaLengkap: txtNama.text.trim(),
          role: role,
          passwordBaru: txtPass.text.isEmpty ? null : txtPass.text,
        );
        if (!mounted) return;
        tampilSnack(context, 'Data pengguna berhasil diubah!');
      }
      if (u != null && u.idUser == SesiUser.idUser) {
        SesiUser.namaLengkap = txtNama.text.trim();
        SesiUser.role = role;
      }
      _muatPengguna();
    } catch (e) {
      if (mounted) tampilSnack(context, 'Gagal: $e');
    }
  }

  Future<void> _hapusPengguna(UserAkun u) async {
    if (!SesiUser.isAdmin) {
      tampilSnack(context, 'Hanya Admin yang boleh menghapus pengguna!');
      return;
    }
    if (u.idUser == SesiUser.idUser) {
      tampilSnack(
          context, 'Tidak dapat menghapus akun Anda sendiri yang sedang aktif!');
      return;
    }
    final yakin = await tampilKonfirmasi(
      context,
      judul: 'Konfirmasi',
      pesan: 'Yakin hapus user ini?',
      teksYa: 'Ya, Hapus',
    );
    if (!yakin) return;
    try {
      await GrowTrackDB.hapusUser(u.idUser);
      if (!mounted) return;
      tampilSnack(context, 'Pengguna berhasil dihapus!');
      _muatPengguna();
    } catch (e) {
      if (mounted) tampilSnack(context, 'Gagal: $e');
    }
  }

  Widget _tabProfil() {
    final logoAda =
        _txtLogo.text.isNotEmpty && File(_txtLogo.text).existsSync();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _txtNama,
          decoration: dekorasiInput('Nama Posyandu / Klinik',
              ikon: Icons.local_hospital_outlined),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _txtAlamat,
          maxLines: 3,
          decoration:
              dekorasiInput('Alamat Lengkap', ikon: Icons.place_outlined),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _txtTelp,
          decoration:
              dekorasiInput('No. Telepon', ikon: Icons.phone_outlined),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _txtKota,
          decoration: dekorasiInput('Kota (Untuk Tanda Tangan Laporan)',
              ikon: Icons.location_city_outlined),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _txtKetua,
          decoration: dekorasiInput('Nama Ketua / Kepala Posyandu',
              ikon: Icons.person_outline),
        ),
        const SizedBox(height: 20),
        Card(
          color: const Color(0xFFF1F5F9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: logoAda
                      ? Image.file(File(_txtLogo.text), fit: BoxFit.contain)
                      : const Icon(Icons.image_outlined,
                          size: 40, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 10),
                Text(
                  _txtLogo.text.isEmpty ? 'Belum ada logo' : _txtLogo.text,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pilihLogo,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Pilih Logo...'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _simpanProfil,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Simpan Identitas'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
        ),
      ],
    );
  }

  Widget _tabPengguna() {
    return Column(
      children: [
        KotakCari(
          hint: 'Cari pengguna (nama)...',
          onBerubah: (v) {
            _cariUser = v;
            _muatPengguna();
          },
        ),
        Expanded(
          child: _memuatUser
              ? const Center(child: CircularProgressIndicator())
              : _pengguna.isEmpty
                  ? const TampilanKosong(pesan: 'Tidak ada pengguna.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _pengguna.length,
                      itemBuilder: (_, i) {
                        final u = _pengguna[i];
                        final admin = u.role == 'Admin';
                        return Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: admin
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFCCFBF1),
                              child: Icon(
                                admin
                                    ? Icons.admin_panel_settings_outlined
                                    : Icons.badge_outlined,
                                color: admin
                                    ? const Color(0xFFEF4444)
                                    : kTeal,
                              ),
                            ),
                            title: Text(u.namaLengkap,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text('@${u.username} • ${u.role}'),
                            trailing: PopupMenuButton<String>(
                              onSelected: (pil) {
                                if (pil == 'ubah') _formPengguna(u);
                                if (pil == 'hapus') _hapusPengguna(u);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'ubah', child: Text('Ubah')),
                                PopupMenuItem(
                                    value: 'hapus', child: Text('Hapus')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Sistem'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Identitas & Logo Posyandu'),
            Tab(text: 'Manajemen Akun Pengguna'),
          ],
        ),
      ),
      floatingActionButton: _tab.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _formPengguna(),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Tambah User'),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        children: [_tabProfil(), _tabPengguna()],
      ),
    );
  }
}
