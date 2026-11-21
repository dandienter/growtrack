/// Model data sesuai tabel pada konfigurasi/KoneksiDB.java (edisi SQLite).

double _keDouble(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
}

double? _keDoubleNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.'));
}

int _keInt(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

class OrangTua {
  String idOrtu;
  String namaAyah;
  String namaIbu;
  String? pekerjaan;
  String? noHp;
  String? alamat;

  OrangTua({
    required this.idOrtu,
    required this.namaAyah,
    required this.namaIbu,
    this.pekerjaan,
    this.noHp,
    this.alamat,
  });

  factory OrangTua.fromMap(Map<String, Object?> m) => OrangTua(
        idOrtu: m['id_ortu']?.toString() ?? '',
        namaAyah: m['nama_ayah']?.toString() ?? '',
        namaIbu: m['nama_ibu']?.toString() ?? '',
        pekerjaan: m['pekerjaan']?.toString(),
        noHp: m['no_hp']?.toString(),
        alamat: m['alamat']?.toString(),
      );

  Map<String, Object?> toMap() => {
        'id_ortu': idOrtu,
        'nama_ayah': namaAyah,
        'nama_ibu': namaIbu,
        'pekerjaan': pekerjaan,
        'no_hp': noHp,
        'alamat': alamat,
      };
}

class Balita {
  String idBalita;
  String namaBalita;
  String jenisKelamin; // 'L' atau 'P'
  String tglLahir; // yyyy-MM-dd
  double beratLahir;
  double tinggiLahir;
  String? idOrtu;
  String? tglDaftar; // yyyy-MM-dd
  String? namaIbu; // hasil join (tampilan)
  String? namaAyah; // hasil join (tampilan)

  Balita({
    required this.idBalita,
    required this.namaBalita,
    required this.jenisKelamin,
    required this.tglLahir,
    this.beratLahir = 0,
    this.tinggiLahir = 0,
    this.idOrtu,
    this.tglDaftar,
    this.namaIbu,
    this.namaAyah,
  });

  String get jenisKelaminLengkap =>
      jenisKelamin == 'L' ? 'Laki-laki' : 'Perempuan';

  factory Balita.fromMap(Map<String, Object?> m) => Balita(
        idBalita: m['id_balita']?.toString() ?? '',
        namaBalita: m['nama_balita']?.toString() ?? '',
        jenisKelamin: m['jenis_kelamin']?.toString() ?? 'L',
        tglLahir: m['tgl_lahir']?.toString() ?? '',
        beratLahir: _keDouble(m['berat_lahir']),
        tinggiLahir: _keDouble(m['tinggi_lahir']),
        idOrtu: m['id_ortu']?.toString(),
        tglDaftar: m['tgl_daftar']?.toString(),
        namaIbu: m['nama_ibu']?.toString(),
        namaAyah: m['nama_ayah']?.toString(),
      );

  Map<String, Object?> toMap() => {
        'id_balita': idBalita,
        'nama_balita': namaBalita,
        'jenis_kelamin': jenisKelamin,
        'tgl_lahir': tglLahir,
        'berat_lahir': beratLahir,
        'tinggi_lahir': tinggiLahir,
        'id_ortu': idOrtu,
        'tgl_daftar': tglDaftar,
      };
}

class Pemeriksaan {
  String idPeriksa;
  String idBalita;
  String tanggal; // yyyy-MM-dd
  double beratBadan;
  double tinggiBadan;
  double lingkarKepala;
  String? posisiUkur;
  double? zBbu;
  double? zTbu;
  double? zBbtb;
  String? statusGizi;
  String? catatanBidan;
  String? namaBalita; // hasil join (tampilan)
  String? jenisKelamin; // hasil join (tampilan avatar)
  String? tglLahir; // hasil join (tampilan avatar)

  Pemeriksaan({
    required this.idPeriksa,
    required this.idBalita,
    required this.tanggal,
    required this.beratBadan,
    required this.tinggiBadan,
    this.lingkarKepala = 0,
    this.posisiUkur,
    this.zBbu,
    this.zTbu,
    this.zBbtb,
    this.statusGizi,
    this.catatanBidan,
    this.namaBalita,
    this.jenisKelamin,
    this.tglLahir,
  });

  factory Pemeriksaan.fromMap(Map<String, Object?> m) => Pemeriksaan(
        idPeriksa: m['id_periksa']?.toString() ?? '',
        idBalita: m['id_balita']?.toString() ?? '',
        tanggal: m['tanggal']?.toString() ?? '',
        beratBadan: _keDouble(m['berat_badan']),
        tinggiBadan: _keDouble(m['tinggi_badan']),
        lingkarKepala: _keDouble(m['lingkar_kepala']),
        posisiUkur: m['posisi_ukur']?.toString(),
        zBbu: _keDoubleNull(m['z_bbu']),
        zTbu: _keDoubleNull(m['z_tbu']),
        zBbtb: _keDoubleNull(m['z_bbtb']),
        statusGizi: m['status_gizi']?.toString(),
        catatanBidan: m['catatan_bidan']?.toString(),
        namaBalita: m['nama_balita']?.toString(),
        jenisKelamin: m['jenis_kelamin']?.toString(),
        tglLahir: m['tgl_lahir']?.toString(),
      );

  Map<String, Object?> toMap() => {
        'id_periksa': idPeriksa,
        'id_balita': idBalita,
        'tanggal': tanggal,
        'berat_badan': beratBadan,
        'tinggi_badan': tinggiBadan,
        'lingkar_kepala': lingkarKepala,
        'posisi_ukur': posisiUkur,
        'z_bbu': zBbu,
        'z_tbu': zTbu,
        'z_bbtb': zBbtb,
        'status_gizi': statusGizi,
        'catatan_bidan': catatanBidan,
      };
}

class ImunisasiVaksin {
  String idImunisasi;
  String namaImunisasi;
  String? merkProdusen;
  String? dosis;
  String? usiaPemberian;
  String? kategori;

  ImunisasiVaksin({
    required this.idImunisasi,
    required this.namaImunisasi,
    this.merkProdusen,
    this.dosis,
    this.usiaPemberian,
    this.kategori,
  });

  factory ImunisasiVaksin.fromMap(Map<String, Object?> m) => ImunisasiVaksin(
        idImunisasi: m['id_imunisasi']?.toString() ?? '',
        namaImunisasi: m['nama_imunisasi']?.toString() ?? '',
        merkProdusen: m['merk_produsen']?.toString(),
        dosis: m['dosis']?.toString(),
        usiaPemberian: m['usia_pemberian']?.toString(),
        kategori: m['kategori']?.toString(),
      );

  Map<String, Object?> toMap() => {
        'id_imunisasi': idImunisasi,
        'nama_imunisasi': namaImunisasi,
        'merk_produsen': merkProdusen,
        'dosis': dosis,
        'usia_pemberian': usiaPemberian,
        'kategori': kategori,
      };
}

class JadwalImunisasi {
  String idJadwal;
  String idBalita;
  String idImunisasi;
  String? tglDiberikan; // yyyy-MM-dd
  String? tglBerikutnya; // yyyy-MM-dd
  String status; // 'Belum' / 'Selesai'
  String? namaBalita; // hasil join (tampilan)
  String? namaImunisasi; // hasil join (tampilan)

  JadwalImunisasi({
    required this.idJadwal,
    required this.idBalita,
    required this.idImunisasi,
    this.tglDiberikan,
    this.tglBerikutnya,
    this.status = 'Belum',
    this.namaBalita,
    this.namaImunisasi,
  });

  factory JadwalImunisasi.fromMap(Map<String, Object?> m) => JadwalImunisasi(
        idJadwal: m['id_jadwal']?.toString() ?? '',
        idBalita: m['id_balita']?.toString() ?? '',
        idImunisasi: m['id_imunisasi']?.toString() ?? '',
        tglDiberikan: m['tgl_diberikan']?.toString(),
        tglBerikutnya: m['tgl_berikutnya']?.toString(),
        status: m['status']?.toString() ?? 'Belum',
        namaBalita: m['nama_balita']?.toString(),
        namaImunisasi: m['nama_imunisasi']?.toString(),
      );

  Map<String, Object?> toMap() => {
        'id_jadwal': idJadwal,
        'id_balita': idBalita,
        'id_imunisasi': idImunisasi,
        'tgl_diberikan': tglDiberikan,
        'tgl_berikutnya': tglBerikutnya,
        'status': status,
      };
}

class Konsumsi {
  String idKonsumsi;
  String tanggal; // yyyy-MM-dd
  String namaKegiatan;
  String? pemberianMt;
  String? rt;
  String? penanggungJawab;
  int jumlahBalita;
  double totalBiaya;
  String? keterangan;

  Konsumsi({
    required this.idKonsumsi,
    required this.tanggal,
    required this.namaKegiatan,
    this.pemberianMt,
    this.rt,
    this.penanggungJawab,
    this.jumlahBalita = 0,
    this.totalBiaya = 0,
    this.keterangan,
  });

  factory Konsumsi.fromMap(Map<String, Object?> m) => Konsumsi(
        idKonsumsi: m['id_konsumsi']?.toString() ?? '',
        tanggal: m['tanggal']?.toString() ?? '',
        namaKegiatan: m['nama_kegiatan']?.toString() ?? '',
        pemberianMt: m['pemberian_mt']?.toString(),
        rt: m['rt']?.toString(),
        penanggungJawab: m['penanggung_jawab']?.toString(),
        jumlahBalita: _keInt(m['jumlah_balita']),
        totalBiaya: _keDouble(m['total_biaya']),
        keterangan: m['keterangan']?.toString(),
      );

  Map<String, Object?> toMap() => {
        'id_konsumsi': idKonsumsi,
        'tanggal': tanggal,
        'nama_kegiatan': namaKegiatan,
        'pemberian_mt': pemberianMt,
        'rt': rt,
        'penanggung_jawab': penanggungJawab,
        'jumlah_balita': jumlahBalita,
        'total_biaya': totalBiaya,
        'keterangan': keterangan,
      };
}

class UserAkun {
  int idUser;
  String username;
  String passwordHash;
  String salt;
  String namaLengkap;
  String role; // 'Admin' / 'Petugas' / 'Orang Tua'
  String? idOrtu; // tautan ke data orang_tua, khusus akun Orang Tua

  UserAkun({
    required this.idUser,
    required this.username,
    required this.passwordHash,
    this.salt = '',
    required this.namaLengkap,
    required this.role,
    this.idOrtu,
  });

  factory UserAkun.fromMap(Map<String, Object?> m) => UserAkun(
        idUser: _keInt(m['id_user']),
        username: m['username']?.toString() ?? '',
        passwordHash: m['password_hash']?.toString() ?? '',
        salt: m['salt']?.toString() ?? '',
        namaLengkap: m['nama_lengkap']?.toString() ?? '',
        role: m['role']?.toString() ?? '',
        idOrtu: m['id_ortu']?.toString(),
      );
}

class Pengaturan {
  String? namaPosyandu;
  String? logoPath;
  String? alamat;
  String? noTelepon;
  String? namaKetua;
  String? kota;

  Pengaturan({
    this.namaPosyandu,
    this.logoPath,
    this.alamat,
    this.noTelepon,
    this.namaKetua,
    this.kota,
  });

  factory Pengaturan.fromMap(Map<String, Object?> m) => Pengaturan(
        namaPosyandu: m['nama_posyandu']?.toString(),
        logoPath: m['logo_path']?.toString(),
        alamat: m['alamat']?.toString(),
        noTelepon: m['no_telepon']?.toString(),
        namaKetua: m['nama_ketua']?.toString(),
        kota: m['kota']?.toString(),
      );
}

/// Konten buatan kader yang tersinkron ke semua perangkat: materi
/// edukasi untuk orang tua dan pengumuman posyandu.
class Konten {
  String idKonten;
  String jenis; // 'edukasi' | 'pengumuman'
  String judul;
  String? ringkasan;
  String isi;
  String? penulis;
  String? tanggal; // yyyy-MM-dd HH:mm:ss

  Konten({
    required this.idKonten,
    required this.jenis,
    required this.judul,
    this.ringkasan,
    required this.isi,
    this.penulis,
    this.tanggal,
  });

  bool get isPengumuman => jenis == 'pengumuman';

  factory Konten.fromMap(Map<String, Object?> m) => Konten(
        idKonten: m['id_konten']?.toString() ?? '',
        jenis: m['jenis']?.toString() ?? 'edukasi',
        judul: m['judul']?.toString() ?? '',
        ringkasan: m['ringkasan']?.toString(),
        isi: m['isi']?.toString() ?? '',
        penulis: m['penulis']?.toString(),
        tanggal: m['tanggal']?.toString(),
      );

  Map<String, Object?> toMap() => {
        'id_konten': idKonten,
        'jenis': jenis,
        'judul': judul,
        'ringkasan': ringkasan,
        'isi': isi,
        'penulis': penulis,
        'tanggal': tanggal,
      };
}
