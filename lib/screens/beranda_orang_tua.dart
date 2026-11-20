import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/database.dart';
import '../format.dart';
import '../models.dart';
import '../session.dart';
import '../sync/sync_service.dart';
import '../widgets.dart';
import 'login.dart';

/// Teks umur ringkas dari tanggal lahir db (yyyy-MM-dd):
/// "2 th 8 bln", "8 bln", "12 hari".
String teksUmurAnak(String? tglLahirDb) {
  final lahir = parseTanggalDb(tglLahirDb);
  if (lahir == null) return '-';
  final kini = DateTime.now();
  var bulan = (kini.year - lahir.year) * 12 + (kini.month - lahir.month);
  if (kini.day < lahir.day) bulan -= 1;
  if (bulan < 0) return '-';
  if (bulan < 1) {
    final hari = kini.difference(lahir).inDays;
    return '$hari hari';
  }
  final th = bulan ~/ 12;
  final bl = bulan % 12;
  if (th == 0) return '$bl bln';
  if (bl == 0) return '$th th';
  return '$th th $bl bln';
}

/// Beranda khusus peran Orang Tua: hanya data anaknya sendiri,
/// sifatnya melihat (read-only). Kader yang menginput data.
class BerandaOrangTuaScreen extends StatefulWidget {
  const BerandaOrangTuaScreen({super.key});

  @override
  State<BerandaOrangTuaScreen> createState() => _BerandaOrangTuaState();
}

class _BerandaOrangTuaState extends State<BerandaOrangTuaScreen> {
  Pengaturan? _pengaturan;
  List<Balita> _anak = [];
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    LayananSinkron.sinkronkan();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final pg = await GrowTrackDB.ambilPengaturan();
      final idOrtu = SesiUser.idOrtu;
      final anak = idOrtu == null || idOrtu.isEmpty
          ? <Balita>[]
          : await GrowTrackDB.ambilBalitaByOrtu(idOrtu);
      if (!mounted) return;
      setState(() {
        _pengaturan = pg;
        _anak = anak;
        _memuat = false;
      });
    } catch (_) {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _keluar() async {
    await GrowTrackDB.hapusSesiLogin();
    SesiUser.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _hubungiPosyandu() async {
    final mentah = _pengaturan?.noTelepon ?? '';
    var nomor = mentah.replaceAll(RegExp(r'[^0-9]'), '');
    if (nomor.startsWith('0')) nomor = '62${nomor.substring(1)}';
    if (nomor.isEmpty) {
      tampilSnack(context, 'Nomor telepon Posyandu belum diatur.');
      return;
    }
    final uri = Uri.parse(
        'https://wa.me/$nomor?text=${Uri.encodeComponent('Halo, saya ${SesiUser.namaLengkap ?? 'orang tua'} dari ${_pengaturan?.namaPosyandu ?? 'Posyandu'}.')}');
    final bisa = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!bisa && mounted) {
      tampilSnack(context, 'Tidak bisa membuka WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          (_pengaturan?.namaPosyandu ?? 'Posyandu').toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            tooltip: 'Keluar',
            onPressed: _keluar,
          ),
        ],
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _kepalaSapaan(),
                  const SizedBox(height: 18),
                  const Text(
                    'Anak Saya',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_anak.isEmpty)
                    const Card(
                      color: Colors.white,
                      child: ListTile(
                        subtitle: Text(
                            'Belum ada data anak yang tertaut ke akun ini. '
                            'Minta kader menautkan akun Anda ke data orang tua.'),
                      ),
                    )
                  else
                    for (final b in _anak) _kartuAnak(b),
                  const SizedBox(height: 18),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.chat,
                            color: Color(0xFF16A34A), size: 21),
                      ),
                      title: const Text('Hubungi Posyandu',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Chat WhatsApp ke kader/posyandu'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _hubungiPosyandu,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _kepalaSapaan() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kTeal, Color(0xFF14532D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AvatarKarakter.ibu(nama: SesiUser.namaLengkap ?? '', ukuran: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, ${SesiUser.namaLengkap ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pantau tumbuh kembang anak Anda di sini.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuAnak(Balita b) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: AvatarKarakter.anak(
          nama: b.namaBalita,
          jenisKelamin: b.jenisKelamin,
          tglLahir: parseTanggalDb(b.tglLahir),
          ukuran: 48,
        ),
        title: Text(
          b.namaBalita,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
            '${b.jenisKelamin == 'L' ? 'Laki-laki' : 'Perempuan'} • ${teksUmurAnak(b.tglLahir)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetailAnakOrtuScreen(balita: b)),
        ),
      ),
    );
  }
}

/// Detail anak untuk orang tua: pemeriksaan terakhir, riwayat
/// pemeriksaan, dan status imunisasi. Semua read-only.
class DetailAnakOrtuScreen extends StatefulWidget {
  final Balita balita;

  const DetailAnakOrtuScreen({super.key, required this.balita});

  @override
  State<DetailAnakOrtuScreen> createState() => _DetailAnakOrtuState();
}

class _DetailAnakOrtuState extends State<DetailAnakOrtuScreen> {
  List<Pemeriksaan> _periksa = [];
  List<JadwalImunisasi> _jadwal = [];
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final p =
          await GrowTrackDB.ambilPemeriksaan(idBalita: widget.balita.idBalita);
      final j =
          await GrowTrackDB.ambilJadwal(idBalita: widget.balita.idBalita);
      if (!mounted) return;
      setState(() {
        _periksa = p;
        _jadwal = j;
        _memuat = false;
      });
    } catch (_) {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.balita;
    final terakhir = _periksa.isEmpty ? null : _periksa.first;
    final selesai =
        _jadwal.where((j) => j.status.toLowerCase() == 'selesai').length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          b.namaBalita,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        AvatarKarakter.anak(
                          nama: b.namaBalita,
                          jenisKelamin: b.jenisKelamin,
                          tglLahir: parseTanggalDb(b.tglLahir),
                          ukuran: 60,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.namaBalita,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${b.jenisKelamin == 'L' ? 'Laki-laki' : 'Perempuan'} • ${teksUmurAnak(b.tglLahir)}',
                                style: const TextStyle(
                                    fontSize: 12.5, color: Color(0xFF64748B)),
                              ),
                              Text(
                                'Lahir ${formatTanggalID(b.tglLahir)} • ${b.beratLahir} kg / ${b.tinggiLahir} cm',
                                style: const TextStyle(
                                    fontSize: 12.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pemeriksaan Terakhir',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                if (terakhir == null)
                  const Card(
                    color: Colors.white,
                    child: ListTile(
                      subtitle: Text('Belum ada data pemeriksaan.'),
                    ),
                  )
                else
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  formatTanggalID(terakhir.tanggal),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (terakhir.statusGizi != null)
                                ChipStatus(
                                  teks: terakhir.statusGizi!,
                                  warna:
                                      warnaStatusGizi(terakhir.statusGizi),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Berat ${terakhir.beratBadan} kg • Tinggi ${terakhir.tinggiBadan} cm • Lingkar kepala ${terakhir.lingkarKepala} cm',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF475569)),
                          ),
                          if (terakhir.catatanBidan != null &&
                              terakhir.catatanBidan!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Catatan: ${terakhir.catatanBidan}',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF475569)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Riwayat Pemeriksaan (${_periksa.length})',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                if (_periksa.length > 1)
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        for (final p in _periksa.skip(1))
                          ListTile(
                            dense: true,
                            title: Text(formatTanggalID(p.tanggal)),
                            subtitle: Text(
                                'BB ${p.beratBadan} kg • TB ${p.tinggiBadan} cm'),
                            trailing: p.statusGizi == null
                                ? null
                                : ChipStatus(
                                    teks: p.statusGizi!,
                                    warna: warnaStatusGizi(p.statusGizi),
                                  ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Imunisasi ($selesai dari ${_jadwal.length} tercatat)',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                if (_jadwal.isEmpty)
                  const Card(
                    color: Colors.white,
                    child: ListTile(
                      subtitle: Text('Belum ada catatan imunisasi.'),
                    ),
                  )
                else
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        for (final j in _jadwal)
                          ListTile(
                            dense: true,
                            title: Text(j.namaImunisasi ?? ''),
                            subtitle: Text(j.status.toLowerCase() == 'selesai'
                                ? 'Diberikan ${formatTanggalID(j.tglDiberikan)}'
                                : 'Jadwal berikutnya ${formatTanggalID(j.tglBerikutnya)}'),
                            trailing: ChipStatus(
                              teks: j.status,
                              warna: j.status.toLowerCase() == 'selesai'
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}
