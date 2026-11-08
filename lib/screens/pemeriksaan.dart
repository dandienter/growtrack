import 'package:flutter/material.dart';

import '../db/database.dart';
import '../format.dart';
import '../logic/gizi.dart';
import '../models.dart';
import '../widgets.dart';

/// Port tampilan/FormPemeriksaan.java: daftar riwayat pemeriksaan.
class PemeriksaanListScreen extends StatefulWidget {
  const PemeriksaanListScreen({super.key});

  @override
  State<PemeriksaanListScreen> createState() => _PemeriksaanListScreenState();
}

class _PemeriksaanListScreenState extends State<PemeriksaanListScreen> {
  List<Pemeriksaan> _daftar = [];
  bool _memuat = true;
  String _cari = '';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final data = await GrowTrackDB.ambilPemeriksaan(cari: _cari);
    if (!mounted) return;
    setState(() {
      _daftar = data;
      _memuat = false;
    });
  }

  Future<void> _tambah() async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PemeriksaanFormScreen()),
    );
    if (simpan == true) _muat();
  }

  Future<void> _ubah(Pemeriksaan pr) async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PemeriksaanFormScreen(pemeriksaan: pr)),
    );
    if (simpan == true) _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pemeriksaan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: const Text('Periksa'),
      ),
      body: Column(
        children: [
          KotakCari(
            hint: 'Cari riwayat pemeriksaan balita...',
            onBerubah: (v) {
              _cari = v;
              _muat();
            },
          ),
          Expanded(
            child: _memuat
                ? const Center(child: CircularProgressIndicator())
                : _daftar.isEmpty
                    ? const TampilanKosong(
                        pesan: 'Belum ada data pemeriksaan.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _daftar.length,
                        itemBuilder: (_, i) {
                          final pr = _daftar[i];
                          return AnimasiMasuk(indeks: i, child: Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            child: ListTile(
                              onTap: () => _ubah(pr),
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE0F2F1),
                                child: Icon(Icons.monitor_weight, color: kTeal),
                              ),
                              title: Text(pr.namaBalita ?? pr.idBalita,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${formatTanggalID(pr.tanggal)} • BB ${pr.beratBadan} Kg • TB ${pr.tinggiBadan} Cm',
                              ),
                              trailing: ChipStatus(
                                teks: pr.statusGizi ?? '-',
                                warna: warnaStatusGizi(pr.statusGizi),
                              ),
                            ),
                          ));
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Form pemeriksaan dengan perhitungan status gizi langsung (live),
/// port logika kalkulasiOtomatis pada FormPemeriksaan desktop.
class PemeriksaanFormScreen extends StatefulWidget {
  final Pemeriksaan? pemeriksaan;
  const PemeriksaanFormScreen({super.key, this.pemeriksaan});

  @override
  State<PemeriksaanFormScreen> createState() => _PemeriksaanFormScreenState();
}

class _PemeriksaanFormScreenState extends State<PemeriksaanFormScreen> {
  final _txtBb = TextEditingController();
  final _txtTb = TextEditingController();
  final _txtLk = TextEditingController();
  final _txtManual = TextEditingController();

  List<Balita> _daftarBalita = [];
  List<ImunisasiVaksin> _daftarVaksin = [];
  Balita? _balita;
  DateTime _tanggal = DateTime.now();
  String _posisi = 'Berdiri';

  String _asi = '- Pilih -';
  bool _asiAktif = true;
  List<String> _opsiVitA = const ['- Pilih -', 'Biru', 'Merah', 'Tidak'];
  String _vitA = '- Pilih -';
  bool _vitAAktif = true;
  String _cacing = '- Pilih -';
  bool _cacingAktif = true;
  ImunisasiVaksin? _vaksinDipilih;

  HasilGizi? _hasil;
  int? _umur;
  double? _tinggiKoreksi;
  String _noteKoreksi = '';
  String _catatanPratinjau = '';
  String? _idBaru;
  bool _memuat = true;

  bool get _modeUbah => widget.pemeriksaan != null;

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  Future<void> _siapkan() async {
    final balita = await GrowTrackDB.ambilBalita();
    final vaksin = await GrowTrackDB.ambilVaksin();
    final pr = widget.pemeriksaan;
    if (!mounted) return;
    setState(() {
      _daftarBalita = balita;
      _daftarVaksin = vaksin;
      if (pr != null) {
        for (final b in balita) {
          if (b.idBalita == pr.idBalita) _balita = b;
        }
        _tanggal = parseTanggalDb(pr.tanggal) ?? DateTime.now();
        _txtBb.text = pr.beratBadan.toString();
        _txtTb.text = pr.tinggiBadan.toString();
        _txtLk.text = pr.lingkarKepala == 0 ? '' : pr.lingkarKepala.toString();
        _uraiCatatanTersimpan(pr);
      }
      _memuat = false;
    });
    setState(_hitungUlang);
    if (pr == null) {
      final id = await GrowTrackDB.buatId('pemeriksaan', 'id_periksa', 'PRX-');
      if (mounted) setState(() => _idBaru = id);
    }
  }

  /// Mengurai catatan_bidan tersimpan menjadi pilihan form (seperti
  /// tablePeriksaMouseClicked pada desktop).
  void _uraiCatatanTersimpan(Pemeriksaan pr) {
    final catatan = pr.catatanBidan ?? '';
    if (catatan.contains('- Posisi Ukur: Telentang')) {
      _posisi = 'Telentang';
    } else if (catatan.contains('- Posisi Ukur: Berdiri')) {
      _posisi = 'Berdiri';
    } else if (pr.posisiUkur == 'Telentang' || pr.posisiUkur == 'Berdiri') {
      _posisi = pr.posisiUkur!;
    }
    if (catatan.contains('- ASI Eksklusif: Ya')) {
      _asi = 'Ya';
    } else if (catatan.contains('- ASI Eksklusif: Tidak')) {
      _asi = 'Tidak';
    } else {
      _asi = '- Pilih -';
    }
    if (catatan.contains('- Kapsul Vit A: Biru')) {
      _vitA = 'Biru';
    } else if (catatan.contains('- Kapsul Vit A: Merah')) {
      _vitA = 'Merah';
    } else if (catatan.contains('- Kapsul Vit A: Tidak')) {
      _vitA = 'Tidak';
    } else {
      _vitA = '- Pilih -';
    }
    // Samakan daftar opsi agar nilai terurai selalu valid
    if (!_opsiVitA.contains(_vitA)) _vitA = '- Pilih -';
    if (catatan.contains('- Obat Cacing: Ya')) {
      _cacing = 'Ya';
    } else if (catatan.contains('- Obat Cacing: Tidak')) {
      _cacing = 'Tidak';
    } else {
      _cacing = '- Pilih -';
    }
    for (final v in _daftarVaksin) {
      if (catatan.contains('- Imunisasi Diberikan: ${v.namaImunisasi}')) {
        _vaksinDipilih = v;
        break;
      }
    }
    _txtManual.text = ambilCatatanManual(catatan);
  }

  @override
  void dispose() {
    _txtBb.dispose();
    _txtTb.dispose();
    _txtLk.dispose();
    _txtManual.dispose();
    super.dispose();
  }

  /// Port kalkulasiOtomatis(): validasi umur, koreksi tinggi, hitung z-score,
  /// susun catatan otomatis. Dipanggil di dalam setState oleh pemanggil.
  void _hitungUlang() {
    final balita = _balita;
    if (balita == null) {
      _hasil = null;
      _umur = null;
      _catatanPratinjau = '';
      return;
    }
    final lahir = parseTanggalDb(balita.tglLahir);
    if (lahir == null) {
      _hasil = null;
      return;
    }
    final umur = hitungUmurBulan(lahir, _tanggal);
    _umur = umur;

    // 1. Validasi ASI (hanya <= 6 bulan)
    _asiAktif = asiAktif(umur);
    if (!_asiAktif && _asi != '- Pilih -' && _asi != 'Tidak') {
      _asi = '- Pilih -';
    }

    // 2. Validasi Kapsul Vitamin A berdasarkan umur & bulan periksa
    final opsiBaru = opsiVitA(umur);
    final vitASebelum = _vitA;
    _vitAAktif = vitAAktif(umur);
    if (!_vitAAktif) {
      _vitA = 'Tidak';
    } else {
      _vitA = opsiBaru.contains(vitASebelum) ? vitASebelum : '- Pilih -';
      if (!bulanVitA(_tanggal.month) && _vitA == '- Pilih -') {
        _vitA = 'Tidak'; // otomatis "Tidak" di luar Feb/Agu
      }
    }
    _opsiVitA = opsiBaru;

    // 3. Obat cacing hanya untuk 12-59 bulan
    _cacingAktif = cacingAktif(umur);
    if (!_cacingAktif) _cacing = 'Tidak';

    // 4. Hitung z-score dari tinggi terkoreksi
    final bb = parseAngka(_txtBb.text);
    final tb = parseAngka(_txtTb.text);
    if (bb == null || tb == null) {
      _hasil = null;
      _catatanPratinjau = '';
      return;
    }
    final koreksi = koreksiTinggi(tb, umur, _posisi);
    _tinggiKoreksi = koreksi.tinggiKoreksi;
    _noteKoreksi = koreksi.catatan;
    _hasil = hitungStatusGiziDetail(
        bb, koreksi.tinggiKoreksi, umur, balita.jenisKelamin);
    _catatanPratinjau = bangunCatatanBidan(
      hasil: _hasil!,
      umurBulan: umur,
      posisiUkur: _posisi,
      noteKoreksi: _noteKoreksi,
      asi: _asi,
      vitA: _vitA,
      cacing: _cacing,
      namaImunisasi: _vaksinDipilih?.namaImunisasi ?? '-',
      catatanManual: _txtManual.text,
    );
  }

  double? _zDb(double z) => z.isNaN ? null : z;

  Future<void> _simpan() async {
    setState(_hitungUlang);
    final bb = parseAngka(_txtBb.text);
    final tb = parseAngka(_txtTb.text);
    if (_balita == null || bb == null || tb == null || _hasil == null) {
      tampilSnack(context,
          'Data belum lengkap atau Balita belum dipilih dengan benar!');
      return;
    }
    final lk = parseAngka(_txtLk.text) ?? 0;
    final hasil = _hasil!;
    final pr = Pemeriksaan(
      idPeriksa: widget.pemeriksaan?.idPeriksa ?? _idBaru ?? '',
      idBalita: _balita!.idBalita,
      tanggal: keTeksDb(_tanggal),
      beratBadan: bb,
      tinggiBadan: tb, // tinggi MENTAH yang disimpan, seperti desktop
      lingkarKepala: lk,
      posisiUkur: _posisi,
      zBbu: _zDb(hasil.zBBU),
      zTbu: _zDb(hasil.zTBU),
      zBbtb: _zDb(hasil.zBBTB),
      statusGizi: hasil.statusUtama,
      catatanBidan: _catatanPratinjau,
    );
    try {
      await GrowTrackDB.simpanPemeriksaan(pr, baru: !_modeUbah);
      if (!_modeUbah && _vaksinDipilih != null) {
        // P-5: sinkronkan imunisasi yang diberikan ke jadwal_imunisasi
        await GrowTrackDB.sinkronJadwalImunisasi(
          pr.idBalita,
          _vaksinDipilih!.idImunisasi,
          pr.tanggal,
        );
      }
      if (!mounted) return;
      tampilSnack(
          context, _modeUbah ? 'Update success!' : 'Berhasil menyimpan data!');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Error saving: $e');
    }
  }

  Future<void> _hapus() async {
    final yakin = await tampilKonfirmasi(
      context,
      judul: 'Konfirmasi',
      pesan: 'Hapus data pemeriksaan ini?',
      teksYa: 'Ya, Hapus',
    );
    if (!yakin) return;
    await GrowTrackDB.hapusPemeriksaan(widget.pemeriksaan!.idPeriksa);
    if (!mounted) return;
    tampilSnack(context, 'Deleted successfully!');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pemeriksaan Posyandu')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final hasil = _hasil;
    return Scaffold(
      appBar: AppBar(
        title:
            Text(_modeUbah ? 'Ubah Pemeriksaan' : 'Pemeriksaan Posyandu'),
        actions: [
          if (_modeUbah)
            IconButton(
              onPressed: _hapus,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            enabled: false,
            decoration: dekorasiInput(
                'ID Periksa (Auto): ${widget.pemeriksaan?.idPeriksa ?? _idBaru ?? '...'}'),
          ),
          const SizedBox(height: 14),
          KolomPilihCari<Balita>(
            label: 'Pilih Pasien Balita',
            petunjuk: '-- Pilih Pasien Balita --',
            nilai: _balita,
            daftar: _daftarBalita,
            labelItem: (b) => '${b.idBalita} - ${b.namaBalita}',
            onBerubah: (v) => setState(() {
              _balita = v;
              _hitungUlang();
            }),
          ),
          const SizedBox(height: 14),
          KolomTanggal(
            label: 'Tanggal Periksa',
            nilai: _tanggal,
            onBerubah: (v) => setState(() {
              if (v != null) _tanggal = v;
              _hitungUlang();
            }),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _txtBb,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: dekorasiInput('Berat Badan (Kg)'),
                  onChanged: (_) => setState(_hitungUlang),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _txtLk,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: dekorasiInput('Lingkar Kepala (Cm)'),
                  onChanged: (_) => setState(_hitungUlang),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _txtTb,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: dekorasiInput('Tinggi/Panjang (Cm)'),
                  onChanged: (_) => setState(_hitungUlang),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _posisi,
                  decoration: dekorasiInput('Posisi Ukur'),
                  items: const ['Berdiri', 'Telentang']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _posisi = v ?? 'Berdiri';
                    _hitungUlang();
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _asi,
                  decoration: dekorasiInput('ASI Eksklusif'),
                  items: const ['- Pilih -', 'Ya', 'Tidak']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: _asiAktif
                      ? (v) => setState(() {
                            _asi = v ?? '- Pilih -';
                            _hitungUlang();
                          })
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _vitA,
                  decoration: dekorasiInput('Kapsul Vit A'),
                  items: _opsiVitA
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: _vitAAktif
                      ? (v) => setState(() {
                            _vitA = v ?? '- Pilih -';
                            _hitungUlang();
                          })
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _cacing,
                  decoration: dekorasiInput('Obat Cacing'),
                  items: const ['- Pilih -', 'Ya', 'Tidak']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: _cacingAktif
                      ? (v) => setState(() {
                            _cacing = v ?? '- Pilih -';
                            _hitungUlang();
                          })
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KolomPilihCari<ImunisasiVaksin>(
                  label: 'Imunisasi Diberikan',
                  petunjuk: '- Tidak Ada -',
                  nilai: _vaksinDipilih,
                  daftar: _daftarVaksin,
                  labelItem: (v) => v.namaImunisasi,
                  bolehKosong: true,
                  labelKosong: '- Tidak Ada -',
                  onBerubah: (v) => setState(() {
                    _vaksinDipilih = v;
                    _hitungUlang();
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _kartuStatus(hasil),
          const SizedBox(height: 14),
          TextField(
            controller: _txtManual,
            maxLines: 4,
            decoration: dekorasiInput('Catatan Manual Bidan'),
            onChanged: (_) => setState(_hitungUlang),
          ),
          if (_catatanPratinjau.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Pratinjau Catatan Bidan (Otomatis)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(_catatanPratinjau,
                  style: const TextStyle(fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _simpan,
            icon: const Icon(Icons.save_outlined),
            label: Text(_modeUbah ? 'Ubah' : 'Simpan'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
          ),
          if (_modeUbah) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _hapus,
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFEF4444)),
              label: const Text('Hapus',
                  style: TextStyle(color: Color(0xFFEF4444))),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(14),
                side: const BorderSide(color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kartuStatus(HasilGizi? hasil) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status Gizi (Otomatis)',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            if (hasil == null)
              const Text('Isi balita, berat, dan tinggi untuk menghitung.',
                  style: TextStyle(color: Color(0xFF94A3B8)))
            else ...[
              Text(
                hasil.statusUtama,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: warnaStatusGizi(hasil.statusUtama),
                ),
              ),
              const SizedBox(height: 8),
              _barisZ('Usia Anak', '${_umur ?? 0} Bulan', null),
              _barisZ('BB/U', '${fmtZ(hasil.zBBU)} • ${hasil.statusBBU}',
                  hasil.zBBU),
              _barisZ('TB/U', '${fmtZ(hasil.zTBU)} • ${hasil.statusTBU}',
                  hasil.zTBU),
              _barisZ('BB/TB', '${fmtZ(hasil.zBBTB)} • ${hasil.statusBBTB}',
                  hasil.zBBTB),
              if (_noteKoreksi.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Tinggi terkoreksi: ${_tinggiKoreksi?.toStringAsFixed(1)} cm$_noteKoreksi',
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _barisZ(String label, String nilai, double? z) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(color: Color(0xFF64748B))),
          ),
          Expanded(child: Text(nilai)),
        ],
      ),
    );
  }
}
