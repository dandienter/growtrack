import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/database.dart';
import '../format.dart';
import '../kurva_who.dart';
import '../models.dart';
import '../session.dart';
import '../sync/sync_service.dart';
import '../sync/update_service.dart';
import '../widgets.dart';
import 'edukasi.dart';
import 'info.dart';
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

/// Ringkasan satu anak untuk kartu beranda orang tua.
class _InfoAnak {
  final Pemeriksaan? terakhir;
  final int jadwalTotal;
  final int jadwalSelesai;
  final JadwalImunisasi? berikutnya;

  const _InfoAnak({
    this.terakhir,
    this.jadwalTotal = 0,
    this.jadwalSelesai = 0,
    this.berikutnya,
  });
}

/// Beranda khusus peran Orang Tua: kartu anak informatif (status gizi,
/// berat/tinggi terakhir, progres imunisasi), edukasi offline, dan
/// tombol hubungi Posyandu. Sifatnya melihat (read-only).
class BerandaOrangTuaScreen extends StatefulWidget {
  const BerandaOrangTuaScreen({super.key});

  @override
  State<BerandaOrangTuaScreen> createState() => _BerandaOrangTuaState();
}

class _BerandaOrangTuaState extends State<BerandaOrangTuaScreen> {
  Pengaturan? _pengaturan;
  List<Balita> _anak = [];
  Map<String, _InfoAnak> _info = {};
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    LayananSinkron.sinkronkan();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LayananUpdate.cekOtomatis(context);
    });
    _muat();
  }

  Future<void> _muat() async {
    try {
      final pg = await GrowTrackDB.ambilPengaturan();
      final idOrtu = SesiUser.idOrtu;
      final anak = idOrtu == null || idOrtu.isEmpty
          ? <Balita>[]
          : await GrowTrackDB.ambilBalitaByOrtu(idOrtu);
      final info = <String, _InfoAnak>{};
      for (final b in anak) {
        final periksa =
            await GrowTrackDB.ambilPemeriksaan(idBalita: b.idBalita);
        final jadwal = await GrowTrackDB.ambilJadwal(idBalita: b.idBalita);
        final belum = jadwal
            .where((j) => j.status.toLowerCase() != 'selesai')
            .toList();
        info[b.idBalita] = _InfoAnak(
          terakhir: periksa.isEmpty ? null : periksa.first,
          jadwalTotal: jadwal.length,
          jadwalSelesai: jadwal.length - belum.length,
          berikutnya: belum.isEmpty ? null : belum.first,
        );
      }
      if (!mounted) return;
      setState(() {
        _pengaturan = pg;
        _anak = anak;
        _info = info;
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
            icon: const Icon(Icons.info_outline),
            tooltip: 'Info Aplikasi',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InfoScreen()),
            ),
          ),
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
                    for (final b in _anak)
                      _kartuAnak(b, _info[b.idBalita] ?? const _InfoAnak()),
                  const SizedBox(height: 18),
                  const SeksiEdukasi(),
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
                  const SizedBox(height: 8),
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

  Widget _kartuAnak(Balita b, _InfoAnak info) {
    final t = info.terakhir;
    final persen =
        info.jadwalTotal == 0 ? 0.0 : info.jadwalSelesai / info.jadwalTotal;
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetailAnakOrtuScreen(balita: b)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarKarakter.anak(
                    nama: b.namaBalita,
                    jenisKelamin: b.jenisKelamin,
                    tglLahir: parseTanggalDb(b.tglLahir),
                    ukuran: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.namaBalita,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '${b.jenisKelamin == 'L' ? 'Laki-laki' : 'Perempuan'} • ${teksUmurAnak(b.tglLahir)}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  if (t?.statusGizi != null)
                    ChipStatus(
                      teks: t!.statusGizi!,
                      warna: warnaStatusGizi(t.statusGizi),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _miniStat('Berat Terakhir',
                      t == null ? '-' : '${t.beratBadan} kg'),
                  _miniStat('Tinggi Terakhir',
                      t == null ? '-' : '${t.tinggiBadan} cm'),
                  _miniStat('Periksa Terakhir',
                      t == null ? '-' : formatTanggalID(t.tanggal)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.vaccines,
                      size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      info.jadwalTotal == 0
                          ? 'Belum ada catatan imunisasi'
                          : 'Imunisasi ${info.jadwalSelesai} dari ${info.jadwalTotal} selesai',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                  Text(
                    '${(persen * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: kTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: persen,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: kTeal,
                ),
              ),
              if (info.berikutnya != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Berikutnya: ${info.berikutnya!.namaImunisasi ?? ''}'
                  '${info.berikutnya!.tglBerikutnya == null ? '' : ' • ${formatTanggalID(info.berikutnya!.tglBerikutnya)}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String nilai) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nilai,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

/// Detail anak untuk orang tua: penilaian Z-Score terakhir, kurva
/// pertumbuhan WHO (berat dan tinggi), riwayat pemeriksaan, dan
/// status imunisasi. Semua read-only.
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

  List<TitikKurva> _titikKurva(bool berat) {
    final lahir = parseTanggalDb(widget.balita.tglLahir);
    if (lahir == null) return const [];
    final hasil = <TitikKurva>[];
    for (final p in _periksa) {
      final tgl = parseTanggalDb(p.tanggal);
      if (tgl == null) continue;
      final bulan = tgl.difference(lahir).inDays / 30.4375;
      if (bulan < 0) continue;
      hasil.add(TitikKurva(bulan, berat ? p.beratBadan : p.tinggiBadan));
    }
    return hasil;
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
                _kartuProfil(b),
                if (terakhir != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Penilaian Gizi Terakhir',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  _kartuZScore(terakhir),
                ],
                if (_periksa.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Kurva Berat Badan (WHO)',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  _kartuKurva(KurvaPertumbuhan(
                    jenisKelamin: b.jenisKelamin,
                    berat: true,
                    titik: _titikKurva(true),
                  )),
                  const SizedBox(height: 16),
                  const Text(
                    'Kurva Tinggi Badan (WHO)',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  _kartuKurva(KurvaPertumbuhan(
                    jenisKelamin: b.jenisKelamin,
                    berat: false,
                    titik: _titikKurva(false),
                  )),
                ],
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

  Widget _kartuProfil(Balita b) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    );
  }

  Widget _kartuKurva(Widget kurva) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: kurva,
      ),
    );
  }

  Widget _kartuZScore(Pemeriksaan t) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _barisZ('Berat menurut Umur (BB/U)', t.zBbu,
                const ['Sangat Kurang', 'Kurang', 'Normal', 'Lebih']),
            const Divider(height: 18),
            _barisZ('Tinggi menurut Umur (TB/U)', t.zTbu,
                const ['Sangat Pendek', 'Pendek', 'Normal', 'Tinggi']),
            const Divider(height: 18),
            _barisZ('Berat menurut Tinggi (BB/TB)', t.zBbtb,
                const ['Sangat Kurang', 'Kurang', 'Normal', 'Lebih']),
          ],
        ),
      ),
    );
  }

  Widget _barisZ(String label, double? z, List<String> labelStatus) {
    final String status;
    final Color warna;
    if (z == null) {
      status = '-';
      warna = const Color(0xFF94A3B8);
    } else if (z < -3) {
      status = labelStatus[0];
      warna = const Color(0xFFEF4444);
    } else if (z < -2) {
      status = labelStatus[1];
      warna = const Color(0xFFF59E0B);
    } else if (z <= 2) {
      status = labelStatus[2];
      warna = const Color(0xFF16A34A);
    } else {
      status = labelStatus[3];
      warna = const Color(0xFFF59E0B);
    }
    // Posisi penanda pada skala -3,5 s.d. +3,5
    final frac = z == null ? 0.5 : ((z + 3.5) / 7).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155)),
              ),
            ),
            Text(
              z == null ? '-' : 'Z ${fmtZ(z)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            ChipStatus(teks: status, warna: warna),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 10,
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                        flex: 1,
                        child: Container(color: const Color(0xFFFECACA))),
                    Expanded(
                        flex: 2,
                        child: Container(color: const Color(0xFFFDE68A))),
                    Expanded(
                        flex: 8,
                        child: Container(color: const Color(0xFFBBF7D0))),
                    Expanded(
                        flex: 3,
                        child: Container(color: const Color(0xFFFDE68A))),
                  ],
                ),
              ),
              Align(
                alignment: Alignment(frac * 2 - 1, 0),
                child: Container(
                  width: 3.5,
                  height: 10,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
