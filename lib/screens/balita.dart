import 'package:flutter/material.dart';

import '../db/database.dart';
import '../format.dart';
import '../logic/gizi.dart';
import '../models.dart';
import '../widgets.dart';

/// Port tampilan/FormBalita.java: daftar, form, dan detail balita.
class BalitaListScreen extends StatefulWidget {
  const BalitaListScreen({super.key});

  @override
  State<BalitaListScreen> createState() => _BalitaListScreenState();
}

class _BalitaListScreenState extends State<BalitaListScreen> {
  List<Balita> _daftar = [];
  bool _memuat = true;
  String _cari = '';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final data = await GrowTrackDB.ambilBalita(cari: _cari);
    if (!mounted) return;
    setState(() {
      _daftar = data;
      _memuat = false;
    });
  }

  Future<void> _tambah() async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const BalitaFormScreen()),
    );
    if (simpan == true) _muat();
  }

  Future<void> _bukaDetail(Balita b) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BalitaDetailScreen(balita: b)),
    );
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Balita')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambah,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          KotakCari(
            hint: 'Cari nama / ID balita...',
            onBerubah: (v) {
              _cari = v;
              _muat();
            },
          ),
          Expanded(
            child: _memuat
                ? const Center(child: CircularProgressIndicator())
                : _daftar.isEmpty
                    ? const TampilanKosong(pesan: 'Belum ada data balita.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _daftar.length,
                        itemBuilder: (_, i) {
                          final b = _daftar[i];
                          final lahir = parseTanggalDb(b.tglLahir);
                          final umur = lahir == null
                              ? null
                              : hitungUmurBulan(lahir, DateTime.now());
                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              onTap: () => _bukaDetail(b),
                              leading: CircleAvatar(
                                backgroundColor: b.jenisKelamin == 'L'
                                    ? const Color(0xFFDBEAFE)
                                    : const Color(0xFFFCE7F3),
                                child: Icon(
                                  b.jenisKelamin == 'L'
                                      ? Icons.boy_outlined
                                      : Icons.girl_outlined,
                                  color: b.jenisKelamin == 'L'
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFDB2777),
                                ),
                              ),
                              title: Text(b.namaBalita,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${b.jenisKelaminLengkap} • Lahir ${formatTanggalID(b.tglLahir)}'
                                '${umur == null ? '' : ' • $umur bulan'}\n'
                                'Ibu: ${b.namaIbu ?? '-'}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class BalitaFormScreen extends StatefulWidget {
  final Balita? balita;
  const BalitaFormScreen({super.key, this.balita});

  @override
  State<BalitaFormScreen> createState() => _BalitaFormScreenState();
}

class _BalitaFormScreenState extends State<BalitaFormScreen> {
  final _txtNama = TextEditingController();
  final _txtBerat = TextEditingController();
  final _txtTinggi = TextEditingController();
  String _jk = 'Laki-laki';
  DateTime? _tglLahir;
  DateTime? _tglDaftar;
  List<OrangTua> _daftarOrtu = [];
  OrangTua? _ortuDipilih;
  String? _idBaru;
  bool _memuat = true;

  bool get _modeUbah => widget.balita != null;

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  Future<void> _siapkan() async {
    final ortu = await GrowTrackDB.ambilOrangTua();
    final b = widget.balita;
    if (!mounted) return;
    setState(() {
      _daftarOrtu = ortu;
      if (b != null) {
        _txtNama.text = b.namaBalita;
        _jk = b.jenisKelamin == 'L' ? 'Laki-laki' : 'Perempuan';
        _tglLahir = parseTanggalDb(b.tglLahir);
        _tglDaftar = parseTanggalDb(b.tglDaftar);
        _txtBerat.text = b.beratLahir == 0 ? '' : b.beratLahir.toString();
        _txtTinggi.text = b.tinggiLahir == 0 ? '' : b.tinggiLahir.toString();
        for (final o in ortu) {
          if (o.idOrtu == b.idOrtu) _ortuDipilih = o;
        }
      } else {
        _tglDaftar = DateTime.now();
      }
      _memuat = false;
    });
    if (b == null) {
      final id = await GrowTrackDB.buatId('balita', 'id_balita', 'BAL-');
      if (mounted) setState(() => _idBaru = id);
    }
  }

  @override
  void dispose() {
    _txtNama.dispose();
    _txtBerat.dispose();
    _txtTinggi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_txtNama.text.trim().isEmpty ||
        _tglLahir == null ||
        _ortuDipilih == null) {
      tampilSnack(context,
          'Data belum lengkap atau Nama Orang Tua belum dipilih dengan benar!');
      return;
    }
    final berat = parseAngka(_txtBerat.text);
    final tinggi = parseAngka(_txtTinggi.text);
    if (berat == null || tinggi == null) {
      tampilSnack(context, 'Berat dan Tinggi harus berupa angka!');
      return;
    }
    final b = Balita(
      idBalita: widget.balita?.idBalita ?? _idBaru ?? '',
      namaBalita: _txtNama.text.trim(),
      jenisKelamin: _jk.substring(0, 1), // 'L' / 'P' seperti desktop
      tglLahir: keTeksDb(_tglLahir),
      beratLahir: berat,
      tinggiLahir: tinggi,
      idOrtu: _ortuDipilih!.idOrtu,
      tglDaftar: keTeksDb(_tglDaftar),
    );
    try {
      await GrowTrackDB.simpanBalita(b, baru: !_modeUbah);
      if (!_modeUbah) {
        // B-07: otomatis buatkan jadwal imunisasi dari master imunisasi
        await GrowTrackDB.buatJadwalImunisasiOtomatis(b.idBalita, _tglLahir!);
      }
      if (!mounted) return;
      tampilSnack(
        context,
        _modeUbah
            ? 'Update success!'
            : 'Data balita tersimpan! Jadwal imunisasi otomatis dibuat.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) tampilSnack(context, 'Error saving data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return Scaffold(
        appBar: AppBar(title: const Text('Data Balita')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar:
          AppBar(title: Text(_modeUbah ? 'Ubah Balita' : 'Tambah Balita')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            enabled: false,
            decoration: dekorasiInput(
                'ID Balita (Auto): ${widget.balita?.idBalita ?? _idBaru ?? '...'}'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _txtNama,
            decoration:
                dekorasiInput('Nama Balita', ikon: Icons.child_care_outlined),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _jk,
            decoration: dekorasiInput('Jenis Kelamin'),
            items: const ['Laki-laki', 'Perempuan']
                .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                .toList(),
            onChanged: (v) => setState(() => _jk = v ?? 'Laki-laki'),
          ),
          const SizedBox(height: 14),
          KolomTanggal(
            label: 'Tanggal Lahir',
            nilai: _tglLahir,
            onBerubah: (v) => setState(() => _tglLahir = v),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _txtBerat,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: dekorasiInput('Berat Lahir (Kg)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _txtTinggi,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: dekorasiInput('Tinggi Lahir (Cm)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<OrangTua>(
            value: _ortuDipilih,
            decoration: dekorasiInput('Orang Tua'),
            hint: const Text('-- Pilih Orang Tua --'),
            items: _daftarOrtu
                .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        '${o.idOrtu} - Ibu: ${o.namaIbu} | Ayah: ${o.namaAyah}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _ortuDipilih = v),
          ),
          const SizedBox(height: 14),
          if (_modeUbah)
            TextField(
              enabled: false,
              decoration: dekorasiInput(
                  'Tanggal Daftar: ${formatTanggalID(widget.balita!.tglDaftar)}'),
            )
          else
            KolomTanggal(
              label: 'Tanggal Daftar',
              nilai: _tglDaftar,
              onBerubah: (v) => setState(() => _tglDaftar = v),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _simpan,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
          ),
        ],
      ),
    );
  }
}

/// Halaman detail balita: biodata + riwayat pemeriksaan + jadwal imunisasi.
class BalitaDetailScreen extends StatefulWidget {
  final Balita balita;
  const BalitaDetailScreen({super.key, required this.balita});

  @override
  State<BalitaDetailScreen> createState() => _BalitaDetailScreenState();
}

class _BalitaDetailScreenState extends State<BalitaDetailScreen> {
  Balita? _balita;
  List<Pemeriksaan> _riwayat = [];
  List<JadwalImunisasi> _jadwal = [];
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _balita = widget.balita;
    _muat();
  }

  Future<void> _muat() async {
    final b = await GrowTrackDB.ambilBalitaById(widget.balita.idBalita);
    final rw = await GrowTrackDB.ambilPemeriksaan(idBalita: widget.balita.idBalita);
    final jd = await GrowTrackDB.ambilJadwal(idBalita: widget.balita.idBalita);
    if (!mounted) return;
    setState(() {
      _balita = b ?? widget.balita;
      _riwayat = rw;
      _jadwal = jd;
      _memuat = false;
    });
  }

  Future<void> _ubah() async {
    final simpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BalitaFormScreen(balita: _balita)),
    );
    if (simpan == true) _muat();
  }

  Future<void> _hapus() async {
    final b = _balita!;
    final terkait = await GrowTrackDB.hitungTerkaitBalita(b.idBalita);
    if (!mounted) return;
    final jmlPeriksa = terkait['pemeriksaan'] ?? 0;
    final jmlJadwal = terkait['jadwal'] ?? 0;
    var pesan = 'Yakin ingin menghapus data balita ini?';
    if (jmlPeriksa > 0 || jmlJadwal > 0) {
      pesan = 'Balita ini memiliki $jmlPeriksa riwayat pemeriksaan dan '
          '$jmlJadwal jadwal imunisasi.\nSemua data terkait akan ikut terhapus. Lanjutkan?';
    }
    final yakin = await tampilKonfirmasi(
      context,
      judul: 'Konfirmasi Hapus',
      pesan: pesan,
      teksYa: 'Ya, Hapus',
    );
    if (!yakin) return;
    await GrowTrackDB.hapusBalitaCascade(b.idBalita);
    if (!mounted) return;
    tampilSnack(context, 'Data balita beserta riwayatnya berhasil dihapus!');
    Navigator.pop(context, true);
  }

  Widget _baris(String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(nilai,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = _balita ?? widget.balita;
    final lahir = parseTanggalDb(b.tglLahir);
    final umur =
        lahir == null ? null : hitungUmurBulan(lahir, DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(b.namaBalita),
        actions: [
          IconButton(onPressed: _ubah, icon: const Icon(Icons.edit_outlined)),
          IconButton(
              onPressed: _hapus, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: b.jenisKelamin == 'L'
                                  ? const Color(0xFFDBEAFE)
                                  : const Color(0xFFFCE7F3),
                              child: Icon(
                                b.jenisKelamin == 'L'
                                    ? Icons.boy_outlined
                                    : Icons.girl_outlined,
                                color: b.jenisKelamin == 'L'
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFDB2777),
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.namaBalita,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  Text('${b.idBalita} • ${b.jenisKelaminLengkap}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _baris('Tanggal Lahir', formatTanggalID(b.tglLahir)),
                        _baris('Umur Saat Ini',
                            umur == null ? '-' : '$umur bulan'),
                        _baris('Berat Lahir', '${b.beratLahir} Kg'),
                        _baris('Tinggi Lahir', '${b.tinggiLahir} Cm'),
                        _baris('Nama Ayah', b.namaAyah ?? '-'),
                        _baris('Nama Ibu', b.namaIbu ?? '-'),
                        _baris('Tanggal Daftar', formatTanggalID(b.tglDaftar)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Riwayat Pemeriksaan',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_riwayat.isEmpty)
                  const Text('Belum ada riwayat pemeriksaan.',
                      style: TextStyle(color: Color(0xFF64748B)))
                else
                  for (final pr in _riwayat)
                    Card(
                      color: Colors.white,
                      child: ListTile(
                        title: Text(formatTanggalID(pr.tanggal)),
                        subtitle: Text(
                            'BB ${pr.beratBadan} Kg • TB ${pr.tinggiBadan} Cm • LK ${pr.lingkarKepala} Cm'),
                        trailing: ChipStatus(
                          teks: pr.statusGizi ?? '-',
                          warna: warnaStatusGizi(pr.statusGizi),
                        ),
                      ),
                    ),
                const SizedBox(height: 20),
                const Text('Jadwal Imunisasi',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_jadwal.isEmpty)
                  const Text('Belum ada jadwal imunisasi.',
                      style: TextStyle(color: Color(0xFF64748B)))
                else
                  for (final j in _jadwal)
                    Card(
                      color: Colors.white,
                      child: ListTile(
                        title: Text(j.namaImunisasi ?? j.idImunisasi),
                        subtitle: Text(
                            'Diberikan: ${formatTanggalID(j.tglDiberikan)}\nBerikutnya: ${formatTanggalID(j.tglBerikutnya)}'),
                        isThreeLine: true,
                        trailing: ChipStatus(
                          teks: j.status,
                          warna: j.status == 'Selesai'
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
