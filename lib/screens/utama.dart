import 'package:flutter/material.dart';

import '../db/database.dart';
import '../session.dart';
import '../sync/sync_service.dart';
import '../sync/update_service.dart';
import '../widgets.dart';
import 'balita.dart';
import '../notifikasi.dart';
import 'cakupan_imunisasi.dart';
import 'home.dart';
import 'info.dart';
import 'jadwal.dart';
import 'kelola_database.dart';
import 'konsumsi.dart';
import 'konten.dart';
import 'laporan.dart';
import 'login.dart';
import 'orang_tua.dart';
import 'panduan.dart';
import 'pantauan_risiko.dart';
import 'pemeriksaan.dart';
import 'pengaturan.dart';
import 'vaksin.dart';

/// Cangkang utama sesudah login: AppBar + navigasi bawah 5 tab.
/// Menggantikan pola Drawer lama di home.dart.
class UtamaScreen extends StatefulWidget {
  const UtamaScreen({super.key});

  @override
  State<UtamaScreen> createState() => _UtamaScreenState();
}

class _UtamaScreenState extends State<UtamaScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  String _namaPosyandu = 'POSYANDU BERINGIN DDN';
  late final AnimationController _animTab;
  late Animation<Offset> _geserTab;
  late Animation<double> _pudarTab;

  @override
  void initState() {
    super.initState();
    _animTab = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _siapkanAnimasiTab(1);
    _animTab.value = 1;
    LayananNotifikasi.jadwalkanUlang();
    _muatNama();
    // Sinkronisasi latar saat aplikasi dibuka; kegagalan (offline)
    // diabaikan diam-diam, data lokal tetap yang utama.
    LayananSinkron.sinkronkan();
    // Cek pembaruan otomatis (maksimal sekali per 12 jam).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LayananUpdate.cekOtomatis(context);
    });
  }

  void _siapkanAnimasiTab(int arah) {
    final kurva = CurvedAnimation(parent: _animTab, curve: Curves.easeOutCubic);
    _geserTab = Tween<Offset>(
      begin: Offset(0.035 * arah, 0),
      end: Offset.zero,
    ).animate(kurva);
    _pudarTab = Tween<double>(begin: 0.35, end: 1).animate(kurva);
  }

  void _pindahTab(int i) {
    if (i == _tab) return;
    _siapkanAnimasiTab(i > _tab ? 1 : -1);
    setState(() => _tab = i);
    _animTab.forward(from: 0);
  }

  @override
  void dispose() {
    _animTab.dispose();
    super.dispose();
  }

  Future<void> _muatNama() async {
    try {
      final pg = await GrowTrackDB.ambilPengaturan();
      final nama = pg.namaPosyandu;
      if (!mounted) return;
      if (nama != null && nama.isNotEmpty) {
        setState(() => _namaPosyandu = nama);
      }
    } catch (_) {}
  }

  /// Bilah sisi untuk layar lebar (desktop): logo dan nama posyandu
  /// di kepala, lima menu utama, versi aplikasi di kaki.
  Widget _sidebar() {
    final item = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, 'Beranda'),
      (Icons.dataset_outlined, Icons.dataset, 'Data Utama'),
      (Icons.medical_services_outlined, Icons.medical_services, 'Pelayanan'),
      (Icons.picture_as_pdf_outlined, Icons.picture_as_pdf, 'Laporan'),
      (Icons.settings_outlined, Icons.settings_rounded, 'Pengaturan'),
    ];
    return Container(
      width: 248,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/icon/posyandu-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _namaPosyandu,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          for (var i = 0; i < item.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: _tab == i ? const Color(0xFFDFF2E4) : null,
                leading: Icon(
                  _tab == i ? item[i].$2 : item[i].$1,
                  color: _tab == i ? kTeal : const Color(0xFF64748B),
                  size: 21,
                ),
                title: Text(
                  item[i].$3,
                  style: TextStyle(
                    fontWeight:
                        _tab == i ? FontWeight.bold : FontWeight.w500,
                    color: const Color(0xFF1E293B),
                    fontSize: 14,
                  ),
                ),
                onTap: () => _pindahTab(i),
              ),
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'GrowTrack v$kNamaVersiIni',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isi = FadeTransition(
      opacity: _pudarTab,
      child: SlideTransition(
        position: _geserTab,
        child: IndexedStack(
          index: _tab,
          children: const [
            HomeScreen(),
            MasterDataHub(),
            PelayananHub(),
            LaporanScreen(),
            PengaturanHub(),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (ctx, batas) {
        // Layar lebar (desktop): bilah sisi + konten dibatasi lebarnya
        // agar tetap lega dan tidak melebar penuh.
        if (batas.maxWidth >= 900) {
          return Scaffold(
            body: Row(
              children: [
                _sidebar(),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: isi,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            leadingWidth: 58,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/icon/posyandu-logo.png',
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            title: Text(
              _namaPosyandu.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          body: isi,
          bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE0F2F1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 68,
        selectedIndex: _tab,
        onDestinationSelected: _pindahTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: kTeal),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.dataset_outlined),
            selectedIcon: Icon(Icons.dataset, color: kTeal),
            label: 'Data Utama',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services, color: kTeal),
            label: 'Pelayanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.picture_as_pdf_outlined),
            selectedIcon: Icon(Icons.picture_as_pdf, color: kTeal),
            label: 'Laporan',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: kTeal),
            label: 'Pengaturan',
          ),
        ],
          ),
        );
      },
    );
  }
}

/// Judul seksi kecil huruf kapital abu di atas daftar hub,
/// pola sama seperti kategori pada drawer lama.
class _JudulHub extends StatelessWidget {
  final String teks;
  const _JudulHub(this.teks);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF94A3B8),
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Ubin menu besar untuk halaman hub: kartu putih radius 16, ikon di dalam
/// kotak radius 12 berwarna lembut, judul tebal, subjudul abu, chevron kanan.
class _UbinMenu extends StatelessWidget {
  final IconData ikon;
  final String judul;
  final String subJudul;
  final Widget tujuan;
  final Color warnaIkon;
  final Color warnaLatarIkon;

  final int indeks;

  const _UbinMenu({
    required this.ikon,
    required this.judul,
    required this.subJudul,
    required this.tujuan,
    this.warnaIkon = kTeal,
    this.warnaLatarIkon = const Color(0xFFE0F2F1),
    this.indeks = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimasiMasuk(
      indeks: indeks,
      child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: warnaLatarIkon,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(ikon, color: warnaIkon),
          ),
          title: Text(
            judul,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          subtitle: Text(
            subJudul,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          trailing: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: Color(0xFF94A3B8)),
          ),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => tujuan)),
        ),
      ),
      ),
    );
  }
}

/// Tab Master Data: orang tua, balita, vaksin.
class MasterDataHub extends StatelessWidget {
  const MasterDataHub({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _JudulHub('DATA UTAMA'),
        _UbinMenu(
          ikon: Icons.family_restroom,
          judul: 'Data Orang Tua',
          subJudul: 'Kelola data ayah dan ibu balita',
          tujuan: OrangTuaListScreen(),
          indeks: 0,
        ),
        _UbinMenu(
          ikon: Icons.child_care,
          judul: 'Data Balita',
          subJudul: 'Kelola data anak terdaftar',
          tujuan: BalitaListScreen(),
          indeks: 1,
        ),
        _UbinMenu(
          ikon: Icons.vaccines,
          judul: 'Data Vaksin',
          subJudul: 'Kelola daftar vaksin dan imunisasi',
          tujuan: VaksinListScreen(),
          indeks: 2,
        ),
      ],
    );
  }
}

/// Tab Pelayanan: pemeriksaan, jadwal imunisasi, konsumsi/PMT.
class PelayananHub extends StatelessWidget {
  const PelayananHub({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _JudulHub('TRANSAKSI & PELAYANAN'),
        _UbinMenu(
          ikon: Icons.monitor_weight,
          judul: 'Pemeriksaan',
          subJudul: 'Pencatatan dan hasil ukur balita',
          tujuan: PemeriksaanListScreen(),
          indeks: 0,
        ),
        _UbinMenu(
          ikon: Icons.event_note,
          judul: 'Jadwal Imunisasi',
          subJudul: 'Jadwal dan status imunisasi',
          tujuan: JadwalListScreen(),
          indeks: 1,
        ),
        _UbinMenu(
          ikon: Icons.restaurant,
          judul: 'Konsumsi / PMT',
          subJudul: 'Pencatatan konsumsi dan PMT',
          tujuan: KonsumsiListScreen(),
          indeks: 2,
        ),
        _UbinMenu(
          ikon: Icons.health_and_safety_outlined,
          judul: 'Pantauan Risiko',
          subJudul: 'Peringatan dini stunting dan gizi buruk',
          tujuan: PantauanRisikoScreen(),
          indeks: 3,
        ),
        _UbinMenu(
          ikon: Icons.verified_outlined,
          judul: 'Cakupan Imunisasi',
          subJudul: 'Persentase balita yang sudah imunisasi',
          tujuan: CakupanImunisasiScreen(),
          indeks: 4,
        ),
      ],
    );
  }
}

/// Tab Pengaturan: pengaturan sistem dan kelola database khusus Admin,
/// info aplikasi dan keluar untuk semua peran.
class PengaturanHub extends StatelessWidget {
  const PengaturanHub({super.key});

  Future<void> _keluar(BuildContext context) async {
    final yakin = await tampilKonfirmasi(
      context,
      judul: 'Konfirmasi Logout',
      pesan: 'Yakin ingin keluar dari sistem?',
      teksYa: 'Ya, Keluar',
      teksTidak: 'Batal',
    );
    if (!yakin || !context.mounted) return;
    await GrowTrackDB.hapusSesiLogin();
    SesiUser.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _JudulHub('PENGATURAN'),
        if (SesiUser.isAdmin) ...[
          const _UbinMenu(
            ikon: Icons.settings,
            judul: 'Pengaturan Akun & Sistem',
            subJudul: 'Identitas posyandu dan akun pengguna',
            tujuan: PengaturanScreen(),
            indeks: 0,
          ),
          const _UbinMenu(
            ikon: Icons.storage,
            judul: 'Kelola Database',
            subJudul: 'Lihat data, cadangan, dan pemulihan',
            tujuan: KelolaDatabaseScreen(),
            indeks: 1,
          ),
          const _UbinMenu(
            ikon: Icons.campaign_outlined,
            judul: 'Konten & Pengumuman',
            subJudul: 'Materi edukasi dan pengumuman untuk orang tua',
            tujuan: KelolaKontenScreen(),
            indeks: 2,
          ),
        ],
        const _UbinMenu(
          ikon: Icons.menu_book_outlined,
          judul: 'Panduan Penggunaan',
          subJudul: 'Langkah demi langkah tiap fitur untuk kader',
          tujuan: PanduanKaderScreen(),
          indeks: 3,
        ),
        const _UbinMenu(
          ikon: Icons.info_outline,
          judul: 'Info Aplikasi',
          subJudul: 'Versi dan tentang aplikasi',
          tujuan: InfoScreen(),
          indeks: 4,
        ),
        AnimasiMasuk(
          indeks: 5,
          child: Card(
          color: Colors.white,
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            ),
            title: const Text(
              'Keluar (Logout)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444),
              ),
            ),
            subtitle: const Text(
              'Akhiri sesi dan kembali ke halaman masuk',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            trailing: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: Color(0xFF94A3B8)),
            ),
            onTap: () => _keluar(context),
          ),
          ),
        ),
      ],
    );
  }
}
