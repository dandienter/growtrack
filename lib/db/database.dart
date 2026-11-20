import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../logic/keamanan.dart';
import '../models.dart';
import '../session.dart';

/// Port konfigurasi/KoneksiDB.java (edisi SQLite) + query-query yang dipakai
/// tampilan desktop. Nama berkas database: db_growtrack.db (lokal, offline).
class GrowTrackDB {
  static const String namaBerkas = 'db_growtrack.db';
  static Database? _db;
  static String? _jalurDb;

  /// Jalur berkas database aktif.
  static Future<String> jalurDb() async {
    _jalurDb ??= p.join(await getDatabasesPath(), namaBerkas);
    return _jalurDb!;
  }

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final jalur = await jalurDb();
    final db = await openDatabase(
      jalur,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    _db = db;
    await _buatSchemaDanDataAwal(db);
    return db;
  }

  static Future<void> tutup() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  // -------------------------------------------------------------------------
  // Skema + data awal (persis KoneksiDB.buatSchemaDanDataAwal)
  // -------------------------------------------------------------------------

  static Future<void> _buatSchemaDanDataAwal(Database db) async {
    final batch = db.batch();
    batch.execute('CREATE TABLE IF NOT EXISTS orang_tua ('
        'id_ortu TEXT PRIMARY KEY,'
        'nama_ayah TEXT NOT NULL, nama_ibu TEXT NOT NULL,'
        'pekerjaan TEXT, no_hp TEXT, alamat TEXT)');
    batch.execute('CREATE TABLE IF NOT EXISTS balita ('
        'id_balita TEXT PRIMARY KEY,'
        'nama_balita TEXT NOT NULL, jenis_kelamin TEXT NOT NULL,'
        'tgl_lahir TEXT NOT NULL, berat_lahir REAL DEFAULT 0,'
        'tinggi_lahir REAL DEFAULT 0, id_ortu TEXT,'
        'tgl_daftar TEXT,'
        'FOREIGN KEY(id_ortu) REFERENCES orang_tua(id_ortu))');
    batch.execute('CREATE TABLE IF NOT EXISTS pemeriksaan ('
        'id_periksa TEXT PRIMARY KEY,'
        'id_balita TEXT NOT NULL, tanggal TEXT NOT NULL,'
        'berat_badan REAL NOT NULL, tinggi_badan REAL NOT NULL,'
        'lingkar_kepala REAL DEFAULT 0, posisi_ukur TEXT DEFAULT \'Telentang\','
        'z_bbu REAL, z_tbu REAL, z_bbtb REAL,'
        'status_gizi TEXT, catatan_bidan TEXT,'
        'FOREIGN KEY(id_balita) REFERENCES balita(id_balita))');
    batch.execute('CREATE TABLE IF NOT EXISTS imunisasi ('
        'id_imunisasi TEXT PRIMARY KEY,'
        'nama_imunisasi TEXT NOT NULL, merk_produsen TEXT,'
        'dosis TEXT, usia_pemberian TEXT, kategori TEXT)');
    batch.execute('CREATE TABLE IF NOT EXISTS jadwal_imunisasi ('
        'id_jadwal TEXT PRIMARY KEY,'
        'id_balita TEXT NOT NULL, id_imunisasi TEXT NOT NULL,'
        'tgl_diberikan TEXT, tgl_berikutnya TEXT,'
        'status TEXT DEFAULT \'Belum\','
        'FOREIGN KEY(id_balita) REFERENCES balita(id_balita),'
        'FOREIGN KEY(id_imunisasi) REFERENCES imunisasi(id_imunisasi))');
    batch.execute('CREATE TABLE IF NOT EXISTS konsumsi ('
        'id_konsumsi TEXT PRIMARY KEY,'
        'tanggal TEXT NOT NULL, nama_kegiatan TEXT NOT NULL,'
        'pemberian_mt TEXT, rt TEXT, penanggung_jawab TEXT,'
        'jumlah_balita INTEGER DEFAULT 0, total_biaya REAL DEFAULT 0,'
        'keterangan TEXT)');
    batch.execute('CREATE TABLE IF NOT EXISTS users ('
        'id_user INTEGER PRIMARY KEY AUTOINCREMENT,'
        'username TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL,'
        'salt TEXT DEFAULT \'\', nama_lengkap TEXT NOT NULL,'
        'role TEXT NOT NULL)');
    batch.execute('CREATE TABLE IF NOT EXISTS pengaturan ('
        'id INTEGER PRIMARY KEY DEFAULT 1,'
        'nama_posyandu TEXT, logo_path TEXT, alamat TEXT,'
        'no_telepon TEXT, nama_ketua TEXT, kota TEXT DEFAULT \'Jakarta\')');
    batch.execute('CREATE TABLE IF NOT EXISTS sesi ('
        'id INTEGER PRIMARY KEY CHECK (id = 1),'
        'username TEXT, nama_lengkap TEXT, role TEXT)');
    await batch.commit(noResult: true);

    // Migrasi: kolom kota (diabaikan bila sudah ada, seperti desktop)
    try {
      await db.execute(
          "ALTER TABLE pengaturan ADD COLUMN kota TEXT DEFAULT 'Jakarta'");
    } catch (_) {}

    await _seed(db);
    await _pasangInfrastrukturSinkron(db);
  }

  /// Tabel yang ikut sinkronisasi cloud, memetakan nama tabel ke kolom
  /// primary key-nya. Tabel users dan sesi sengaja TIDAK ikut: kredensial
  /// dan sesi tetap lokal per perangkat.
  static const Map<String, String> tabelSinkron = {
    'orang_tua': 'id_ortu',
    'balita': 'id_balita',
    'pemeriksaan': 'id_periksa',
    'imunisasi': 'id_imunisasi',
    'jadwal_imunisasi': 'id_jadwal',
    'konsumsi': 'id_konsumsi',
    'pengaturan': 'id',
  };

  /// Infrastruktur sinkronisasi offline-first: tabel outbox (penanda baris
  /// kotor), tombstone (penanda hapus), dan sinkron_meta (watermark tarik
  /// + saklar tangkap). Trigger AFTER INSERT/UPDATE/DELETE pada tiap tabel
  /// sinkron mencatat perubahan tanpa mengubah kode CRUD yang sudah ada.
  /// Saklar 'tangkap' dimatikan sesaat saat hasil tarikan server diterapkan
  /// ke lokal agar tidak memantul kembali sebagai perubahan baru.
  static Future<void> _pasangInfrastrukturSinkron(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS outbox ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'tabel TEXT NOT NULL, id_baris TEXT NOT NULL, waktu TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS tombstone ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'tabel TEXT NOT NULL, id_baris TEXT NOT NULL, waktu TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS sinkron_meta ('
        'kunci TEXT PRIMARY KEY, nilai TEXT)');
    await db.execute(
        "INSERT OR IGNORE INTO sinkron_meta (kunci, nilai) VALUES ('tangkap', 'on')");

    const syarat = "WHERE COALESCE((SELECT nilai FROM sinkron_meta "
        "WHERE kunci = 'tangkap'), 'on') = 'on'";
    for (final e in tabelSinkron.entries) {
      final t = e.key;
      final pk = e.value;
      await db.execute('CREATE TRIGGER IF NOT EXISTS trg_sk_${t}_ins '
          'AFTER INSERT ON $t BEGIN '
          'INSERT INTO outbox (tabel, id_baris, waktu) '
          "SELECT '$t', CAST(NEW.$pk AS TEXT), datetime('now') $syarat; "
          'END');
      await db.execute('CREATE TRIGGER IF NOT EXISTS trg_sk_${t}_upd '
          'AFTER UPDATE ON $t BEGIN '
          'INSERT INTO outbox (tabel, id_baris, waktu) '
          "SELECT '$t', CAST(NEW.$pk AS TEXT), datetime('now') $syarat; "
          'END');
      await db.execute('CREATE TRIGGER IF NOT EXISTS trg_sk_${t}_del '
          'AFTER DELETE ON $t BEGIN '
          'INSERT INTO tombstone (tabel, id_baris, waktu) '
          "SELECT '$t', CAST(OLD.$pk AS TEXT), datetime('now') $syarat; "
          'DELETE FROM outbox '
          "WHERE tabel = '$t' AND id_baris = CAST(OLD.$pk AS TEXT); "
          'END');
    }

    // Sekali saja saat infrastruktur pertama terpasang: antrekan semua
    // baris lama agar ikut terkirim pada sinkronisasi pertama.
    final sudah = await db.query('sinkron_meta',
        where: 'kunci = ?', whereArgs: ['infra_v1']);
    if (sudah.isEmpty) {
      for (final e in tabelSinkron.entries) {
        await db.execute('INSERT INTO outbox (tabel, id_baris, waktu) '
            "SELECT '${e.key}', CAST(${e.value} AS TEXT), datetime('now') "
            'FROM ${e.key}');
      }
      await db.execute('INSERT INTO sinkron_meta (kunci, nilai) '
          "VALUES ('infra_v1', 'ya')");
    }
  }

  static Future<int> _hitung(Database db, String tabel) async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM $tabel');
    return (r.first['c'] as num?)?.toInt() ?? 0;
  }

  static Future<void> _seed(Database db) async {
    const hash =
        '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9';

    if (await _hitung(db, 'users') == 0) {
      await db.rawInsert(
          'INSERT INTO users (username, password_hash, salt, nama_lengkap, role) VALUES '
          "('admin', '$hash', '', 'Administrator', 'Admin'),"
          "('bidan', '$hash', '', 'Bidan Sari', 'Petugas')");
    }

    if (await _hitung(db, 'pengaturan') == 0) {
      await db.rawInsert(
          'INSERT INTO pengaturan (id, nama_posyandu, alamat, no_telepon, nama_ketua, kota) VALUES '
          "(1, 'Posyandu Beringin DDN', 'Jl. Beringin Raya No. 12, Jakarta Timur 13610', "
          "'(021) 8091234', 'Hj. Ratna Sari', 'Jakarta')");
    }

    if (await _hitung(db, 'imunisasi') == 0) {
      const data = <List<String>>[
        ['IMN001', 'Hepatitis B (HB-0)', 'Bio Farma', '0.5 ml', '0-7 hari', 'Wajib'],
        ['IMN002', 'BCG', 'Bio Farma', '0.05 ml', '1 bulan', 'Wajib'],
        ['IMN003', 'Polio Tetes 1', 'Bio Farma', '2 tetes', '1 bulan', 'Wajib'],
        ['IMN004', 'DPT-HB-Hib 1', 'Bio Farma', '0.5 ml', '2 bulan', 'Wajib'],
        ['IMN005', 'Polio Tetes 2', 'Bio Farma', '2 tetes', '2 bulan', 'Wajib'],
        ['IMN006', 'DPT-HB-Hib 2', 'Bio Farma', '0.5 ml', '3 bulan', 'Wajib'],
        ['IMN007', 'Polio Tetes 3', 'Bio Farma', '2 tetes', '3 bulan', 'Wajib'],
        ['IMN008', 'DPT-HB-Hib 3', 'Bio Farma', '0.5 ml', '4 bulan', 'Wajib'],
        ['IMN009', 'Polio Tetes 4', 'Bio Farma', '2 tetes', '4 bulan', 'Wajib'],
        ['IMN010', 'Campak', 'Bio Farma', '0.5 ml', '9 bulan', 'Wajib'],
        ['IMN011', 'DPT-HB-Hib Lanjutan', 'Bio Farma', '0.5 ml', '18 bulan', 'Lanjutan'],
        ['IMN012', 'Campak Lanjutan', 'Bio Farma', '0.5 ml', '24 bulan', 'Lanjutan'],
        ['IMN013', 'DT', 'Bio Farma', '0.5 ml', '5-7 tahun', 'Lanjutan'],
        ['IMN014', 'PCV', 'Pfizer', '0.5 ml', '2, 4, 6 bulan', 'Pilihan'],
        ['IMN015', 'Rotavirus', 'GSK', '1.5 ml', '2, 4 bulan', 'Pilihan'],
        ['IMN016', 'Influenza', 'Sanofi', '0.25 ml', '6 bulan+', 'Pilihan'],
        ['IMN017', 'Hepatitis A', 'GSK', '0.5 ml', '12 bulan', 'Pilihan'],
        ['IMN018', 'Varicella (Cacar Air)', 'MSD', '0.5 ml', '12 bulan', 'Pilihan'],
        ['IMN019', 'MMR', 'GSK', '0.5 ml', '15 bulan', 'Pilihan'],
        ['IMN020', 'Tifoid', 'Bio Farma', '0.5 ml', '2 tahun+', 'Pilihan'],
      ];
      final batch = db.batch();
      for (final d in data) {
        batch.insert('imunisasi', {
          'id_imunisasi': d[0],
          'nama_imunisasi': d[1],
          'merk_produsen': d[2],
          'dosis': d[3],
          'usia_pemberian': d[4],
          'kategori': d[5],
        });
      }
      await batch.commit(noResult: true);
    }

    if (await _hitung(db, 'orang_tua') == 0) {
      const ortu = <List<String>>[
        ['ORT001', 'Budi Santoso', 'Dewi Lestari', 'Wiraswasta', '081234567890', 'Jl. Beringin No. 5 RT 03/02'],
        ['ORT002', 'Agus Wijaya', 'Siti Rahayu', 'PNS', '081234567891', 'Jl. Beringin No. 12 RT 03/02'],
        ['ORT003', 'Hendra Gunawan', 'Maya Putri', 'Karyawan Swasta', '081234567892', 'Jl. Beringin No. 20 RT 04/02'],
        ['ORT004', 'Dedi Kurniawan', 'Rina Marlina', 'Pedagang', '081234567893', 'Jl. Flamboyan No. 8 RT 04/03'],
        ['ORT005', 'Yusuf Maulana', 'Fitri Handayani', 'Guru', '081234567894', 'Jl. Flamboyan No. 15 RT 05/03'],
        ['ORT006', 'Eko Purnomo', 'Sri Wahyuni', 'Buruh Pabrik', '081234567895', 'Jl. Beringin No. 27 RT 03/02'],
        ['ORT007', 'Rahmat Hidayat', 'Nur Aini', 'Ojek Online', '081234567896', 'Jl. Kenanga No. 3 RT 06/03'],
        ['ORT008', 'Slamet Riyadi', 'Endang Susanti', 'Pensiunan', '081234567897', 'Jl. Beringin No. 31 RT 04/02'],
        ['ORT009', 'Fajar Ramadhan', 'Intan Permata', 'Karyawan Swasta', '081234567898', 'Jl. Flamboyan No. 22 RT 05/03'],
        ['ORT010', 'Tono Wibowo', 'Ratna Dewi', 'Wiraswasta', '081234567899', 'Jl. Kenanga No. 17 RT 06/03'],
        ['ORT011', 'Joko Susilo', 'Wulan Dari', 'Satpam', '081234567900', 'Jl. Beringin No. 8 RT 03/02'],
        ['ORT012', 'Andi Firmansyah', 'Mega Utami', 'Teknisi', '081234567901', 'Jl. Flamboyan No. 30 RT 05/03'],
      ];
      final batch = db.batch();
      for (final o in ortu) {
        batch.insert('orang_tua', {
          'id_ortu': o[0],
          'nama_ayah': o[1],
          'nama_ibu': o[2],
          'pekerjaan': o[3],
          'no_hp': o[4],
          'alamat': o[5],
        });
      }
      await batch.commit(noResult: true);
    }

    if (await _hitung(db, 'balita') == 0) {
      const blt = <List<Object>>[
        ['BLT001', 'Ahmad Fauzi', 'L', '2024-03-15', 3.2, 49.0, 'ORT001', '2024-04-01'],
        ['BLT002', 'Siti Aisyah', 'P', '2024-06-20', 3.0, 48.0, 'ORT002', '2024-07-05'],
        ['BLT003', 'Muhammad Rizki', 'L', '2023-11-10', 3.5, 50.0, 'ORT003', '2023-12-01'],
        ['BLT004', 'Nadia Putri', 'P', '2024-01-25', 2.8, 47.0, 'ORT004', '2024-02-10'],
        ['BLT005', 'Dimas Prasetyo', 'L', '2023-08-05', 3.1, 49.0, 'ORT005', '2023-09-01'],
        ['BLT006', 'Kirana Maheswari', 'P', '2025-08-12', 3.0, 48.0, 'ORT006', '2025-09-02'],
        ['BLT007', 'Raka Aditya', 'L', '2026-07-03', 3.3, 50.0, 'ORT007', '2026-07-20'],
        ['BLT008', 'Azzahra Ramadhani', 'P', '2023-05-19', 2.9, 47.0, 'ORT008', '2023-06-10'],
        ['BLT009', 'Fatih Alfarizi', 'L', '2026-01-28', 3.4, 51.0, 'ORT009', '2026-02-15'],
        ['BLT010', 'Galih Permana', 'L', '2023-02-14', 2.7, 46.0, 'ORT010', '2023-03-05'],
        ['BLT011', 'Nayla Zahira', 'P', '2024-09-30', 3.1, 49.0, 'ORT011', '2024-10-12'],
        ['BLT012', 'Bagas Nugroho', 'L', '2022-12-08', 3.2, 50.0, 'ORT012', '2023-01-15'],
      ];
      final batch = db.batch();
      for (final b in blt) {
        batch.insert('balita', {
          'id_balita': b[0],
          'nama_balita': b[1],
          'jenis_kelamin': b[2],
          'tgl_lahir': b[3],
          'berat_lahir': b[4],
          'tinggi_lahir': b[5],
          'id_ortu': b[6],
          'tgl_daftar': b[7],
        });
      }
      await batch.commit(noResult: true);
    }

    if (await _hitung(db, 'pemeriksaan') == 0) {
      const priksa = <List<Object>>[
        ['PRK001', 'BLT001', '2026-10-01', 8.5, 72.0, 44.0, 'Berdiri', -0.5, -0.3, 0.1, 'Normal', 'Balita sehat, lanjutkan ASI + MPASI'],
        ['PRK002', 'BLT002', '2026-10-01', 7.8, 70.0, 43.0, 'Berdiri', -0.8, -0.5, -0.2, 'Normal', 'Berat badan naik 300gr'],
        ['PRK003', 'BLT003', '2026-10-01', 12.5, 88.0, 47.0, 'Berdiri', 0.2, 0.1, 0.3, 'Normal', 'Tumbuh kembang baik'],
        ['PRK004', 'BLT004', '2026-10-01', 9.2, 74.0, 44.0, 'Berdiri', -0.3, -0.1, 0.0, 'Normal', 'Perlu tambah protein hewani'],
        ['PRK005', 'BLT005', '2026-10-01', 13.8, 92.0, 48.0, 'Berdiri', 0.5, 0.4, 0.2, 'Normal', 'Aktif, nafsu makan baik'],
      ];
      final batch = db.batch();
      for (final pr in priksa) {
        batch.insert('pemeriksaan', {
          'id_periksa': pr[0],
          'id_balita': pr[1],
          'tanggal': pr[2],
          'berat_badan': pr[3],
          'tinggi_badan': pr[4],
          'lingkar_kepala': pr[5],
          'posisi_ukur': pr[6],
          'z_bbu': pr[7],
          'z_tbu': pr[8],
          'z_bbtb': pr[9],
          'status_gizi': pr[10],
          'catatan_bidan': pr[11],
        });
      }
      await batch.commit(noResult: true);
    }

    // Data contoh tambahan dengan tanggal relatif terhadap hari ini, supaya
    // dashboard (periksa bulan ini, jadwal mendatang, perhatian khusus)
    // langsung hidup pada pemasangan baru.
    String tglRel(int hariLalu) {
      final d = DateTime.now().subtract(Duration(days: hariLalu));
      final m = d.month.toString().padLeft(2, '0');
      final h = d.day.toString().padLeft(2, '0');
      return '${d.year}-$m-$h';
    }

    final cekContoh = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM pemeriksaan WHERE id_periksa = 'PRK101'");
    if (((cekContoh.first['c'] as num?) ?? 0) == 0) {
      final tambahan = <List<Object>>[
        ['PRK101', 'BLT006', tglRel(2), 9.6, 78.5, 46.0, 'Berdiri', -0.2, -0.4, 0.1, 'Normal', 'Tumbuh baik, MPASI lahap'],
        ['PRK102', 'BLT007', tglRel(2), 6.9, 66.0, 42.5, 'Telentang', 0.1, 0.0, 0.2, 'Normal', 'ASI eksklusif, kenaikan sesuai kurva'],
        ['PRK103', 'BLT009', tglRel(9), 8.1, 71.5, 44.5, 'Telentang', -0.6, -0.5, -0.3, 'Normal', 'Siap imunisasi campak bulan ini'],
        ['PRK104', 'BLT010', tglRel(9), 10.9, 86.0, 46.0, 'Berdiri', -2.05, -2.61, -2.24, 'Stunting + Gizi Kurang', 'Dirujuk ke Puskesmas, diberi PMT pemulihan dan jadwal kontrol 2 minggu'],
        ['PRK105', 'BLT001', tglRel(16), 9.0, 74.5, 45.0, 'Berdiri', -0.4, -0.3, 0.0, 'Normal', 'Berat badan naik 500gr dari bulan lalu'],
        ['PRK106', 'BLT003', tglRel(16), 13.1, 90.0, 47.5, 'Berdiri', 0.2, 0.1, 0.3, 'Normal', 'Aktif dan ceria, lanjutkan menu keluarga'],
        ['PRK107', 'BLT011', tglRel(35), 10.4, 84.0, 46.5, 'Berdiri', -2.31, -0.9, -1.8, 'Underweight (BB Kurang)', 'Nafsu makan menurun, disarankan tambah protein hewani dan kontrol bulan depan'],
        ['PRK108', 'BLT012', tglRel(63), 14.6, 98.5, 48.5, 'Berdiri', 0.3, 0.5, 0.0, 'Normal', 'Perkembangan sesuai usia'],
        ['PRK109', 'BLT008', tglRel(35), 13.9, 95.0, 47.0, 'Berdiri', 0.0, 0.2, -0.1, 'Normal', 'Sudah bisa berlari, bicara lancar'],
      ];
      final batch = db.batch();
      for (final pr in tambahan) {
        batch.insert('pemeriksaan', {
          'id_periksa': pr[0],
          'id_balita': pr[1],
          'tanggal': pr[2],
          'berat_badan': pr[3],
          'tinggi_badan': pr[4],
          'lingkar_kepala': pr[5],
          'posisi_ukur': pr[6],
          'z_bbu': pr[7],
          'z_tbu': pr[8],
          'z_bbtb': pr[9],
          'status_gizi': pr[10],
          'catatan_bidan': pr[11],
        });
      }
      await batch.commit(noResult: true);
    }

    if (await _hitung(db, 'jadwal_imunisasi') == 0) {
      final jadwal = <List<Object?>>[
        ['JDW001', 'BLT007', 'IMN001', tglRel(118), '', 'Selesai'],
        ['JDW002', 'BLT007', 'IMN002', tglRel(88), '', 'Selesai'],
        ['JDW003', 'BLT007', 'IMN004', '', tglRel(-3), 'Belum'],
        ['JDW004', 'BLT009', 'IMN010', '', tglRel(-6), 'Belum'],
        ['JDW005', 'BLT006', 'IMN009', '', tglRel(-12), 'Belum'],
        ['JDW006', 'BLT002', 'IMN011', '', tglRel(-20), 'Belum'],
        ['JDW007', 'BLT010', 'IMN012', '', tglRel(5), 'Belum'],
        ['JDW008', 'BLT001', 'IMN008', tglRel(120), '', 'Selesai'],
        ['JDW009', 'BLT003', 'IMN011', tglRel(45), '', 'Selesai'],
      ];
      final batch = db.batch();
      for (final j in jadwal) {
        batch.insert('jadwal_imunisasi', {
          'id_jadwal': j[0],
          'id_balita': j[1],
          'id_imunisasi': j[2],
          'tgl_diberikan': j[3],
          'tgl_berikutnya': j[4],
          'status': j[5],
        });
      }
      await batch.commit(noResult: true);
    }

    if (await _hitung(db, 'konsumsi') == 0) {
      final konsumsi = <List<Object>>[
        ['KNS001', tglRel(2), 'Posyandu Rutin Bulanan', 'Bubur kacang hijau + telur rebus', '03/02', 'Sari Wulandari', 12, 185000, 'PMT rutin untuk seluruh balita hadir'],
        ['KNS002', tglRel(9), 'Pemberian PMT Balita', 'Susu + biskuit PMT', '04/02', 'Sari Wulandari', 10, 150000, 'PMT penyuluhan gizi'],
        ['KNS003', tglRel(16), 'Posyandu Rutin Bulanan', 'Nasi tim + ayam suwir', '05/03', 'Dewi Anggraini', 12, 210000, 'Menu PMT bergizi seimbang'],
        ['KNS004', tglRel(40), 'PMT Pemulihan Gizi', 'Susu formula + telur + pisang', '03/02', 'Sari Wulandari', 3, 275000, 'Paket pemulihan untuk balita gizi kurang'],
      ];
      final batch = db.batch();
      for (final k in konsumsi) {
        batch.insert('konsumsi', {
          'id_konsumsi': k[0],
          'tanggal': k[1],
          'nama_kegiatan': k[2],
          'pemberian_mt': k[3],
          'rt': k[4],
          'penanggung_jawab': k[5],
          'jumlah_balita': k[6],
          'total_biaya': k[7],
          'keterangan': k[8],
        });
      }
      await batch.commit(noResult: true);
    }
  }

  // -------------------------------------------------------------------------
  // Pembuatan ID otomatis: awalan + nomor 3 digit (terbesar + 1)
  // -------------------------------------------------------------------------

  static Future<String> buatId(
      String tabel, String kolom, String awalan) async {
    final db = await database;
    final rows = await db.query(tabel, columns: [kolom]);
    var maks = 0;
    for (final r in rows) {
      final v = r[kolom]?.toString() ?? '';
      final angka = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (angka > maks) maks = angka;
    }
    return '$awalan${(maks + 1).toString().padLeft(3, '0')}';
  }

  // -------------------------------------------------------------------------
  // Login (port proses/ProsesLogin.java)
  // -------------------------------------------------------------------------

  /// Mengembalikan pesan kesalahan, atau null bila login berhasil.
  /// [rolePilihan] adalah peran yang dipilih pada form ("Masuk Sebagai").
  static Future<String?> validasiLogin(
      String username, String passwordInput, String rolePilihan) async {
    final db = await database;
    final rows = await db.query('users',
        where: 'username = ?', whereArgs: [username], limit: 1);
    if (rows.isEmpty) return 'Login Gagal! Username atau Password salah.';

    final user = UserAkun.fromMap(rows.first);
    if (!KeamananPassword.verify(passwordInput, user.salt, user.passwordHash)) {
      return 'Login Gagal! Username atau Password salah.';
    }
    if (user.role.toLowerCase() != rolePilihan.toLowerCase()) {
      return 'Akses Ditolak! Akun Anda bukan $rolePilihan';
    }

    SesiUser.isi(
      id: user.idUser,
      user: user.username,
      nama: user.namaLengkap,
      peran: user.role,
    );

    // Upgrade otomatis: akun lama tanpa salt -> buatkan salt baru
    if (user.salt.isEmpty) {
      final saltBaru = KeamananPassword.generateSalt();
      await db.update(
        'users',
        {
          'password_hash': KeamananPassword.hash(passwordInput, saltBaru),
          'salt': saltBaru,
        },
        where: 'id_user = ?',
        whereArgs: [user.idUser],
      );
    }
    await simpanSesiLogin();
    return null;
  }

  /// Simpan sesi login saat ini ke tabel sesi agar tetap masuk
  /// walaupun aplikasi ditutup dan dibuka lagi.
  static Future<void> simpanSesiLogin() async {
    final db = await database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO sesi (id, username, nama_lengkap, role) '
      'VALUES (1, ?, ?, ?)',
      [SesiUser.username, SesiUser.namaLengkap, SesiUser.role],
    );
  }

  /// Pulihkan sesi tersimpan saat aplikasi dibuka. Mengembalikan true bila
  /// ada sesi dan akunnya masih terdaftar; SesiUser diisi dari data akun
  /// terbaru. Sesi yang akunnya sudah dihapus dibersihkan.
  static Future<bool> pulihkanSesi() async {
    final db = await database;
    final rows =
        await db.query('sesi', where: 'id = ?', whereArgs: [1], limit: 1);
    if (rows.isEmpty) return false;
    final uname = rows.first['username']?.toString() ?? '';
    if (uname.isEmpty) return false;
    final u = await db.query('users',
        where: 'username = ?', whereArgs: [uname], limit: 1);
    if (u.isEmpty) {
      await hapusSesiLogin();
      return false;
    }
    final user = UserAkun.fromMap(u.first);
    SesiUser.isi(
      id: user.idUser,
      user: user.username,
      nama: user.namaLengkap,
      peran: user.role,
    );
    return true;
  }

  /// Hapus sesi tersimpan (saat logout atau sesudah restore database).
  static Future<void> hapusSesiLogin() async {
    final db = await database;
    await db.delete('sesi');
  }

  // -------------------------------------------------------------------------
  // Pengaturan
  // -------------------------------------------------------------------------

  static Future<Pengaturan> ambilPengaturan() async {
    final db = await database;
    final rows =
        await db.query('pengaturan', where: 'id = ?', whereArgs: [1], limit: 1);
    if (rows.isEmpty) return Pengaturan(namaPosyandu: 'Posyandu Beringin DDN');
    return Pengaturan.fromMap(rows.first);
  }

  static Future<void> simpanPengaturan(Pengaturan pg) async {
    final db = await database;
    await db.update(
      'pengaturan',
      {
        // Desktop menyimpan nama posyandu dalam huruf besar
        'nama_posyandu': pg.namaPosyandu?.toUpperCase(),
        'logo_path': pg.logoPath,
        'alamat': pg.alamat,
        'no_telepon': pg.noTelepon,
        'nama_ketua': pg.namaKetua,
        'kota': pg.kota,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  // -------------------------------------------------------------------------
  // Orang Tua
  // -------------------------------------------------------------------------

  static Future<List<OrangTua>> ambilOrangTua({String cari = ''}) async {
    final db = await database;
    final rows = await db.query(
      'orang_tua',
      where: cari.isEmpty
          ? null
          : 'nama_ibu LIKE ? OR nama_ayah LIKE ? OR no_hp LIKE ?',
      whereArgs: cari.isEmpty ? null : ['%$cari%', '%$cari%', '%$cari%'],
      orderBy: 'id_ortu DESC',
    );
    return rows.map(OrangTua.fromMap).toList();
  }

  static Future<void> simpanOrangTua(OrangTua o, {required bool baru}) async {
    final db = await database;
    if (baru) {
      await db.insert('orang_tua', o.toMap());
    } else {
      await db.update('orang_tua', o.toMap(),
          where: 'id_ortu = ?', whereArgs: [o.idOrtu]);
    }
  }

  static Future<int> hitungBalitaDariOrtu(String idOrtu) async {
    final db = await database;
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM balita WHERE id_ortu = ?', [idOrtu]);
    return (r.first['c'] as num?)?.toInt() ?? 0;
  }

  static Future<void> hapusOrangTua(String idOrtu) async {
    final db = await database;
    await db.delete('orang_tua', where: 'id_ortu = ?', whereArgs: [idOrtu]);
  }

  // -------------------------------------------------------------------------
  // Balita
  // -------------------------------------------------------------------------

  static Future<List<Balita>> ambilBalita({String cari = ''}) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT b.*, o.nama_ibu AS nama_ibu, o.nama_ayah AS nama_ayah '
      'FROM balita b LEFT JOIN orang_tua o ON b.id_ortu = o.id_ortu '
      '${cari.isEmpty ? '' : 'WHERE b.nama_balita LIKE ? OR b.id_balita LIKE ? '}'
      'ORDER BY b.id_balita DESC',
      cari.isEmpty ? null : ['%$cari%', '%$cari%'],
    );
    return rows.map(Balita.fromMap).toList();
  }

  static Future<Balita?> ambilBalitaById(String id) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT b.*, o.nama_ibu AS nama_ibu, o.nama_ayah AS nama_ayah '
      'FROM balita b LEFT JOIN orang_tua o ON b.id_ortu = o.id_ortu '
      'WHERE b.id_balita = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return Balita.fromMap(rows.first);
  }

  static Future<void> simpanBalita(Balita b, {required bool baru}) async {
    final db = await database;
    if (baru) {
      await db.insert('balita', b.toMap());
    } else {
      // Desktop tidak mengubah tgl_daftar saat ubah data
      final map = b.toMap()..remove('tgl_daftar');
      await db.update('balita', map,
          where: 'id_balita = ?', whereArgs: [b.idBalita]);
    }
  }

  /// Hapus balita beserta riwayat pemeriksaan & jadwalnya (P-8 desktop).
  static Future<void> hapusBalitaCascade(String idBalita) async {
    final db = await database;
    await db.delete('pemeriksaan',
        where: 'id_balita = ?', whereArgs: [idBalita]);
    await db.delete('jadwal_imunisasi',
        where: 'id_balita = ?', whereArgs: [idBalita]);
    await db.delete('balita', where: 'id_balita = ?', whereArgs: [idBalita]);
  }

  static Future<Map<String, int>> hitungTerkaitBalita(String idBalita) async {
    final db = await database;
    final r1 = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM pemeriksaan WHERE id_balita = ?', [idBalita]);
    final r2 = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM jadwal_imunisasi WHERE id_balita = ?',
        [idBalita]);
    return {
      'pemeriksaan': (r1.first['c'] as num?)?.toInt() ?? 0,
      'jadwal': (r2.first['c'] as num?)?.toInt() ?? 0,
    };
  }

  /// B-07 desktop: buat jadwal imunisasi otomatis untuk balita baru
  /// berdasarkan kolom usia_pemberian pada master imunisasi.
  static Future<void> buatJadwalImunisasiOtomatis(
      String idBalita, DateTime tglLahir) async {
    final db = await database;
    final vaksin = await ambilVaksin();
    for (final v in vaksin) {
      final usiaBulan = parseUsiaBulan(v.usiaPemberian);
      if (usiaBulan < 0) continue;
      final tglJadwal = tambahBulan(tglLahir, usiaBulan);
      final idJadwal = await buatId('jadwal_imunisasi', 'id_jadwal', 'JDW-');
      await db.insert('jadwal_imunisasi', {
        'id_jadwal': idJadwal,
        'id_balita': idBalita,
        'id_imunisasi': v.idImunisasi,
        'tgl_diberikan': null,
        'tgl_berikutnya': _fmtTgl(tglJadwal),
        'status': 'Belum',
      });
    }
  }

  /// Mengurai teks usia_pemberian ("1 Bulan", "0-7 hari", "2 Tahun") ke bulan.
  /// -1 bila tidak dikenali (port FormBalita.parseUsiaBulan).
  static int parseUsiaBulan(String? usia) {
    if (usia == null) return -1;
    final s = usia.toLowerCase().trim();
    try {
      final angkaStr =
          s.replaceAll(RegExp(r'[^0-9]'), ' ').trim().split(RegExp(r'\s+')).first;
      if (angkaStr.isEmpty) return -1;
      final n = int.parse(angkaStr);
      if (s.contains('tahun')) return n * 12;
      if (s.contains('hari') || s.contains('minggu')) return 0;
      return n;
    } catch (_) {
      return -1;
    }
  }

  /// Tambah bulan ala java.util.Calendar.add(MONTH): hari dijepit ke akhir bulan.
  static DateTime tambahBulan(DateTime awal, int bulan) {
    final total = (awal.year * 12 + (awal.month - 1)) + bulan;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final hariAkhir = DateTime(y, m + 1, 0).day;
    final d = awal.day > hariAkhir ? hariAkhir : awal.day;
    return DateTime(y, m, d);
  }

  static String _fmtTgl(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // -------------------------------------------------------------------------
  // Vaksin (master imunisasi)
  // -------------------------------------------------------------------------

  static Future<List<ImunisasiVaksin>> ambilVaksin() async {
    final db = await database;
    final rows = await db.query('imunisasi', orderBy: 'id_imunisasi ASC');
    return rows.map(ImunisasiVaksin.fromMap).toList();
  }

  static Future<void> simpanVaksin(ImunisasiVaksin v,
      {required bool baru}) async {
    final db = await database;
    if (baru) {
      await db.insert('imunisasi', v.toMap());
    } else {
      await db.update('imunisasi', v.toMap(),
          where: 'id_imunisasi = ?', whereArgs: [v.idImunisasi]);
    }
  }

  static Future<void> hapusVaksin(String idImunisasi) async {
    final db = await database;
    await db.delete('imunisasi',
        where: 'id_imunisasi = ?', whereArgs: [idImunisasi]);
  }

  // -------------------------------------------------------------------------
  // Jadwal Imunisasi
  // -------------------------------------------------------------------------

  static Future<List<JadwalImunisasi>> ambilJadwal(
      {String cari = '', String? idBalita}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (idBalita != null) {
      where.add('j.id_balita = ?');
      args.add(idBalita);
    }
    if (cari.isNotEmpty) {
      where.add('(b.nama_balita LIKE ? OR i.nama_imunisasi LIKE ?)');
      args.add('%$cari%');
      args.add('%$cari%');
    }
    final rows = await db.rawQuery(
      'SELECT j.*, b.nama_balita AS nama_balita, i.nama_imunisasi AS nama_imunisasi '
      'FROM jadwal_imunisasi j '
      'JOIN balita b ON j.id_balita = b.id_balita '
      'JOIN imunisasi i ON j.id_imunisasi = i.id_imunisasi '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')} '}'
      'ORDER BY j.tgl_berikutnya ASC',
      args,
    );
    return rows.map(JadwalImunisasi.fromMap).toList();
  }

  static Future<void> simpanJadwal(JadwalImunisasi j,
      {required bool baru}) async {
    final db = await database;
    if (baru) {
      await db.insert('jadwal_imunisasi', j.toMap());
    } else {
      await db.update('jadwal_imunisasi', j.toMap(),
          where: 'id_jadwal = ?', whereArgs: [j.idJadwal]);
    }
  }

  static Future<void> hapusJadwal(String idJadwal) async {
    final db = await database;
    await db.delete('jadwal_imunisasi',
        where: 'id_jadwal = ?', whereArgs: [idJadwal]);
  }

  /// P-5 desktop: catat imunisasi yang diberikan saat pemeriksaan.
  /// Jadwal 'Belum' untuk vaksin tsb ditandai 'Selesai'; bila tidak ada,
  /// dibuat baris baru berstatus 'Selesai'.
  static Future<void> sinkronJadwalImunisasi(
      String idBalita, String idImunisasi, String tglPeriksa) async {
    final db = await database;
    final updated = await db.update(
      'jadwal_imunisasi',
      {'status': 'Selesai', 'tgl_diberikan': tglPeriksa},
      where: "id_balita = ? AND id_imunisasi = ? AND status = 'Belum'",
      whereArgs: [idBalita, idImunisasi],
    );
    if (updated == 0) {
      final idJadwal = await buatId('jadwal_imunisasi', 'id_jadwal', 'JDW-');
      await db.insert('jadwal_imunisasi', {
        'id_jadwal': idJadwal,
        'id_balita': idBalita,
        'id_imunisasi': idImunisasi,
        'tgl_diberikan': tglPeriksa,
        'tgl_berikutnya': tglPeriksa,
        'status': 'Selesai',
      });
    }
  }

  // -------------------------------------------------------------------------
  // Pemeriksaan
  // -------------------------------------------------------------------------

  static Future<List<Pemeriksaan>> ambilPemeriksaan(
      {String cari = '', String? idBalita}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (idBalita != null) {
      where.add('p.id_balita = ?');
      args.add(idBalita);
    }
    if (cari.isNotEmpty) {
      where.add('(b.nama_balita LIKE ? OR p.id_periksa LIKE ?)');
      args.add('%$cari%');
      args.add('%$cari%');
    }
    final rows = await db.rawQuery(
      'SELECT p.*, b.nama_balita AS nama_balita, b.jenis_kelamin AS jenis_kelamin, b.tgl_lahir AS tgl_lahir FROM pemeriksaan p '
      'JOIN balita b ON p.id_balita = b.id_balita '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')} '}'
      'ORDER BY p.tanggal DESC, p.id_periksa DESC',
      args,
    );
    return rows.map(Pemeriksaan.fromMap).toList();
  }

  static Future<void> simpanPemeriksaan(Pemeriksaan pr,
      {required bool baru}) async {
    final db = await database;
    if (baru) {
      await db.insert('pemeriksaan', pr.toMap());
    } else {
      await db.update('pemeriksaan', pr.toMap(),
          where: 'id_periksa = ?', whereArgs: [pr.idPeriksa]);
    }
  }

  static Future<void> hapusPemeriksaan(String idPeriksa) async {
    final db = await database;
    await db.delete('pemeriksaan',
        where: 'id_periksa = ?', whereArgs: [idPeriksa]);
  }

  // -------------------------------------------------------------------------
  // Konsumsi / PMT
  // -------------------------------------------------------------------------

  static Future<List<Konsumsi>> ambilKonsumsi({String cari = ''}) async {
    final db = await database;
    final rows = await db.query(
      'konsumsi',
      where: cari.isEmpty
          ? null
          : 'nama_kegiatan LIKE ? OR keterangan LIKE ?',
      whereArgs: cari.isEmpty ? null : ['%$cari%', '%$cari%'],
      orderBy: 'tanggal DESC, id_konsumsi DESC',
    );
    return rows.map(Konsumsi.fromMap).toList();
  }

  static Future<void> simpanKonsumsi(Konsumsi k, {required bool baru}) async {
    final db = await database;
    if (baru) {
      await db.insert('konsumsi', k.toMap());
    } else {
      await db.update('konsumsi', k.toMap(),
          where: 'id_konsumsi = ?', whereArgs: [k.idKonsumsi]);
    }
  }

  static Future<void> hapusKonsumsi(String idKonsumsi) async {
    final db = await database;
    await db.delete('konsumsi',
        where: 'id_konsumsi = ?', whereArgs: [idKonsumsi]);
  }

  /// Daftar RT unik untuk filter laporan PMT (persis DialogLaporan).
  static Future<List<Map<String, String>>> ambilDaftarRt() async {
    final db = await database;
    final rows = await db.rawQuery(
        "SELECT DISTINCT rt, penanggung_jawab FROM konsumsi "
        "WHERE rt IS NOT NULL AND rt != ''");
    return rows
        .map((r) => {
              'rt': r['rt']?.toString() ?? '',
              'penanggung_jawab': r['penanggung_jawab']?.toString() ?? '',
            })
        .toList();
  }

  // -------------------------------------------------------------------------
  // Statistik Beranda (MenuDashboard.refreshDataStatistikRealtime)
  // -------------------------------------------------------------------------

  static Future<Map<String, num>> ambilStatistik() async {
    final db = await database;
    final r1 = await db.rawQuery('SELECT COUNT(*) AS c FROM balita');
    final r2 = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM pemeriksaan "
        "WHERE strftime('%Y-%m', tanggal) = strftime('%Y-%m', 'now', 'localtime')");
    final r3 = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM jadwal_imunisasi "
        "WHERE tgl_berikutnya >= date('now', 'localtime') AND status = 'Belum'");
    final r4 = await db.rawQuery(
        "SELECT COALESCE(SUM(total_biaya), 0) AS s FROM konsumsi "
        "WHERE strftime('%Y-%m', tanggal) = strftime('%Y-%m', 'now', 'localtime')");
    return {
      'totalBalita': (r1.first['c'] as num?) ?? 0,
      'periksaBulanIni': (r2.first['c'] as num?) ?? 0,
      'vaksinMendatang': (r3.first['c'] as num?) ?? 0,
      'biayaPmt': (r4.first['s'] as num?) ?? 0,
    };
  }

  static Future<List<Map<String, Object?>>> jadwalMendatang() async {
    final db = await database;
    return db.rawQuery(
      "SELECT b.nama_balita AS nama_balita, b.jenis_kelamin AS jenis_kelamin, "
      "b.tgl_lahir AS tgl_lahir, i.nama_imunisasi AS nama_imunisasi, "
      "j.tgl_berikutnya AS tgl_berikutnya "
      "FROM jadwal_imunisasi j "
      "JOIN balita b ON j.id_balita = b.id_balita "
      "JOIN imunisasi i ON j.id_imunisasi = i.id_imunisasi "
      "WHERE j.tgl_berikutnya >= date('now', 'localtime') AND j.status = 'Belum' "
      "ORDER BY j.tgl_berikutnya ASC LIMIT 10",
    );
  }

  static Future<List<Map<String, Object?>>> perhatianKhusus() async {
    final db = await database;
    return db.rawQuery(
      "SELECT b.nama_balita AS nama_balita, b.jenis_kelamin AS jenis_kelamin, "
      "b.tgl_lahir AS tgl_lahir, p.status_gizi AS status_gizi, "
      "p.tanggal AS tanggal "
      "FROM pemeriksaan p JOIN balita b ON p.id_balita = b.id_balita "
      "WHERE p.status_gizi LIKE '%Kurang%' OR p.status_gizi LIKE '%Buruk%' "
      "OR p.status_gizi LIKE '%Stunting%' OR p.status_gizi LIKE '%Obesitas%' "
      "OR p.status_gizi LIKE '%Gizi Lebih%' "
      "ORDER BY p.tanggal DESC LIMIT 10",
    );
  }

  // -------------------------------------------------------------------------
  // Pengguna (FormPengaturan - Manajemen Akun Pengguna)
  // -------------------------------------------------------------------------

  static Future<List<UserAkun>> ambilUsers({String cari = ''}) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: cari.isEmpty ? null : 'nama_lengkap LIKE ?',
      whereArgs: cari.isEmpty ? null : ['%$cari%'],
      orderBy: 'id_user ASC',
    );
    return rows.map(UserAkun.fromMap).toList();
  }

  static Future<void> tambahUser({
    required String username,
    required String password,
    required String namaLengkap,
    required String role,
  }) async {
    final db = await database;
    final salt = KeamananPassword.generateSalt();
    await db.insert('users', {
      'username': username,
      'password_hash': KeamananPassword.hash(password, salt),
      'salt': salt,
      'nama_lengkap': namaLengkap,
      'role': role,
    });
  }

  static Future<void> ubahUser({
    required int idUser,
    required String username,
    required String namaLengkap,
    required String role,
    String? passwordBaru,
  }) async {
    final db = await database;
    final nilai = <String, Object?>{
      'username': username,
      'nama_lengkap': namaLengkap,
      'role': role,
    };
    if (passwordBaru != null && passwordBaru.isNotEmpty) {
      final salt = KeamananPassword.generateSalt();
      nilai['password_hash'] = KeamananPassword.hash(passwordBaru, salt);
      nilai['salt'] = salt;
    }
    await db.update('users', nilai,
        where: 'id_user = ?', whereArgs: [idUser]);
  }

  static Future<void> hapusUser(int idUser) async {
    final db = await database;
    await db.delete('users', where: 'id_user = ?', whereArgs: [idUser]);
  }

  // -------------------------------------------------------------------------
  // Kelola Database (FormKelolaDatabase)
  // -------------------------------------------------------------------------

  /// 8 tabel aplikasi (urut abjad seperti desktop, tanpa tabel sqlite_*).
  static const List<String> daftarTabel = [
    'balita',
    'imunisasi',
    'jadwal_imunisasi',
    'konsumsi',
    'orang_tua',
    'pemeriksaan',
    'pengaturan',
    'users',
  ];

  /// Info kolom tabel: nama kolom + kolom primary key (null bila tidak ada).
  static Future<({List<String> kolom, String? pk})> infoTabel(
      String tabel) async {
    final db = await database;
    final rows = await db.rawQuery('PRAGMA table_info("$tabel")');
    final kolom = <String>[];
    String? pk;
    for (final r in rows) {
      kolom.add(r['name']?.toString() ?? '');
      if (((r['pk'] as num?) ?? 0) > 0) pk = r['name']?.toString();
    }
    return (kolom: kolom, pk: pk);
  }

  static Future<List<Map<String, Object?>>> ambilIsiTabel(String tabel) async {
    final db = await database;
    return db.rawQuery('SELECT * FROM "$tabel" LIMIT 1000');
  }

  static Future<void> ubahSelTabel(
      String tabel, String kolom, Object? nilaiBaru, String pk, Object? nilaiPk) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE "$tabel" SET "$kolom" = ? WHERE "$pk" = ?', [nilaiBaru, nilaiPk]);
  }

  static Future<void> hapusBarisTabel(
      String tabel, String pk, Object? nilaiPk) async {
    final db = await database;
    await db.rawDelete('DELETE FROM "$tabel" WHERE "$pk" = ?', [nilaiPk]);
  }

  // -------------------------------------------------------------------------
  // Backup & Restore (FormKelolaDatabase)
  // -------------------------------------------------------------------------

  /// Menyalin berkas database ke folder sementara dengan nama backup
  /// db_growtrack-backup-yyyyMMdd-HHmmss.db untuk dibagikan.
  static Future<File> siapkanBerkasBackup() async {
    final jalur = await jalurDb();
    await tutup();
    final now = DateTime.now();
    String dua(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${dua(now.month)}${dua(now.day)}-${dua(now.hour)}${dua(now.minute)}${dua(now.second)}';
    final tujuan =
        File(p.join(Directory.systemTemp.path, 'db_growtrack-backup-$stamp.db'));
    await File(jalur).copy(tujuan.path);
    // Buka kembali database agar aplikasi tetap berjalan
    await database;
    return tujuan;
  }

  /// Mengganti seluruh database dengan berkas backup terpilih.
  static Future<void> restoreDariBerkas(String jalurSumber) async {
    final jalur = await jalurDb();
    await tutup();
    await File(jalurSumber).copy(jalur);
    // Hapus jurnal pendamping agar tidak menimpa hasil restore
    for (final akhiran in ['-journal', '-wal', '-shm']) {
      final f = File('$jalur$akhiran');
      if (await f.exists()) await f.delete();
    }
    await database; // buka lagi (skema + data awal dipastikan ada)
  }
}
