import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import 'supabase_config.dart';

/// Hasil satu putaran sinkronisasi.
class HasilSinkron {
  final bool sukses;
  final String pesan;
  final int ditarik;
  final int dikirim;

  const HasilSinkron({
    required this.sukses,
    required this.pesan,
    this.ditarik = 0,
    this.dikirim = 0,
  });
}

/// Mesin sinkronisasi offline-first GrowTrack.
///
/// Semua baca-tulis harian tetap ke SQLite lokal. Sinkronisasi berjalan
/// dua arah ke Supabase (PostgREST) mengikuti pola ini:
/// 1. Tarik: ambil baris server yang updated_at-nya melewati watermark
///    per tabel, terapkan ke lokal dengan saklar tangkap trigger mati.
/// 2. Kirim: unggah baris lokal yang ditandai outbox (upsert), lalu
///    tandai baris tombstone sebagai deleted_at di server.
/// Konflik diselesaikan last-write-wins: tarikan selalu mendahului
/// kiriman, jadi perubahan lokal terbaru menimpa hasil tarikan.
class LayananSinkron {
  static bool _berjalan = false;

  /// Urutan proses mengikuti relasi antar tabel (induk sebelum anak).
  static const List<String> urutanTabel = [
    'pengaturan',
    'konten',
    'imunisasi',
    'orang_tua',
    'balita',
    'pemeriksaan',
    'jadwal_imunisasi',
    'konsumsi',
  ];

  /// Kolom lokal tiap tabel (tanpa updated_at/deleted_at milik server).
  static const Map<String, List<String>> kolomTabel = {
    'orang_tua': [
      'id_ortu', 'nama_ayah', 'nama_ibu', 'pekerjaan', 'no_hp', 'alamat',
    ],
    'balita': [
      'id_balita', 'nama_balita', 'jenis_kelamin', 'tgl_lahir',
      'berat_lahir', 'tinggi_lahir', 'id_ortu', 'tgl_daftar',
    ],
    'pemeriksaan': [
      'id_periksa', 'id_balita', 'tanggal', 'berat_badan', 'tinggi_badan',
      'lingkar_kepala', 'posisi_ukur', 'z_bbu', 'z_tbu', 'z_bbtb',
      'status_gizi', 'catatan_bidan',
    ],
    'imunisasi': [
      'id_imunisasi', 'nama_imunisasi', 'merk_produsen', 'dosis',
      'usia_pemberian', 'kategori',
    ],
    'jadwal_imunisasi': [
      'id_jadwal', 'id_balita', 'id_imunisasi', 'tgl_diberikan',
      'tgl_berikutnya', 'status',
    ],
    'konsumsi': [
      'id_konsumsi', 'tanggal', 'nama_kegiatan', 'pemberian_mt', 'rt',
      'penanggung_jawab', 'jumlah_balita', 'total_biaya', 'keterangan',
    ],
    'pengaturan': [
      'id', 'nama_posyandu', 'logo_path', 'alamat', 'no_telepon',
      'nama_ketua', 'kota',
    ],
    'konten': [
      'id_konten', 'jenis', 'judul', 'ringkasan', 'isi', 'penulis',
      'tanggal',
    ],
  };

  static Map<String, String> get _tajuk => {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        'Content-Type': 'application/json',
      };

  /// Satu panggilan REST ke PostgREST. Melempar [Exception] pada
  /// status non-2xx atau kegagalan jaringan.
  static Future<dynamic> _minta(
    String metode,
    String jalur, {
    Object? isi,
    Map<String, String>? tajukTambahan,
  }) async {
    final klien = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.parse('${SupabaseConfig.url}$jalur');
      final HttpClientRequest req;
      switch (metode) {
        case 'POST':
          req = await klien.postUrl(uri);
          break;
        case 'PATCH':
          req = await klien.patchUrl(uri);
          break;
        default:
          req = await klien.getUrl(uri);
      }
      _tajuk.forEach((k, v) => req.headers.set(k, v));
      tajukTambahan?.forEach((k, v) => req.headers.set(k, v));
      if (isi != null) req.write(jsonEncode(isi));
      final resp = await req.close().timeout(const Duration(seconds: 30));
      final teks = await resp.transform(utf8.decoder).join();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Server membalas ${resp.statusCode}: $teks');
      }
      return teks.isEmpty ? null : jsonDecode(teks);
    } finally {
      klien.close(force: true);
    }
  }

  static Future<String?> _meta(Database db, String kunci) async {
    final r = await db.query('sinkron_meta',
        where: 'kunci = ?', whereArgs: [kunci], limit: 1);
    return r.isEmpty ? null : r.first['nilai']?.toString();
  }

  static Future<void> _aturMeta(Database db, String kunci, String nilai) {
    return db.execute(
      'INSERT INTO sinkron_meta (kunci, nilai) VALUES (?, ?) '
      'ON CONFLICT(kunci) DO UPDATE SET nilai = excluded.nilai',
      [kunci, nilai],
    );
  }

  /// Waktu sinkronisasi terakhir yang berhasil (untuk tampilan status).
  static Future<String?> waktuSinkronTerakhir() async {
    final db = await GrowTrackDB.database;
    return _meta(db, 'sinkron_terakhir');
  }

  /// Jalankan satu putaran sinkronisasi penuh. Aman dipanggil berulang;
  /// panggilan yang tumpang tindih dilewati.
  static Future<HasilSinkron> sinkronkan() async {
    if (_berjalan) {
      return const HasilSinkron(
          sukses: false, pesan: 'Sinkronisasi sedang berjalan.');
    }
    _berjalan = true;
    var ditarik = 0;
    var dikirim = 0;
    try {
      final db = await GrowTrackDB.database;

      // Samakan dulu Z-Score dan status tersimpan dengan hitungan WHO
      // aplikasi ini, supaya daftar, form, laporan, dan pantauan risiko
      // konsisten; hasil perbaikan ikut terkirim pada putaran ini.
      try {
        await GrowTrackDB.hitungUlangSemuaStatus();
      } catch (_) {
        // Gagal hitung ulang tidak boleh menggagalkan sinkronisasi.
      }

      // --- Tarik perubahan dari server ---
      for (final t in urutanTabel) {
       try {
        final wm = await _meta(db, 'wm_$t') ?? '1970-01-01T00:00:00+00:00';
        final hasil = await _minta('GET',
            '/rest/v1/$t?select=*&updated_at=gt.${Uri.encodeComponent(wm)}&order=updated_at.asc');
        if (hasil is List && hasil.isNotEmpty) {
          await _aturMeta(db, 'tangkap', 'off');
          try {
            for (final mentah in hasil) {
              await _terapkanBaris(db, t, mentah as Map<String, dynamic>);
              ditarik++;
            }
          } finally {
            await _aturMeta(db, 'tangkap', 'on');
          }
          final wmBaru = hasil.last['updated_at']?.toString();
          if (wmBaru != null) await _aturMeta(db, 'wm_$t', wmBaru);
        }
       } catch (_) {
        // Tabel ini dilewati putaran ini (mis. belum ada di server);
        // tabel lain tetap diproses.
       }
      }

      // --- Kirim penghapusan (tombstone) ---
      final kuburan = await db.query('tombstone', orderBy: 'id ASC');
      for (final tb in kuburan) {
       try {
        final t = tb['tabel'] as String;
        final id = tb['id_baris'] as String;
        final pk = GrowTrackDB.tabelSinkron[t]!;
        await _minta(
          'PATCH',
          '/rest/v1/$t?$pk=eq.${Uri.encodeComponent(id)}',
          isi: {'deleted_at': DateTime.now().toUtc().toIso8601String()},
        );
        await db.delete('tombstone', where: 'id = ?', whereArgs: [tb['id']]);
        dikirim++;
       } catch (_) {
        // Penghapusan tabel ini ditunda ke putaran berikutnya.
       }
      }

      // --- Kirim baris kotor (outbox) sebagai upsert ---
      for (final t in urutanTabel) {
       try {
        final pk = GrowTrackDB.tabelSinkron[t]!;
        final kotor = await db.query('outbox',
            where: 'tabel = ?', whereArgs: [t]);
        final ids = kotor.map((e) => e['id_baris'] as String).toSet();
        for (final id in ids) {
          final kunci = t == 'pengaturan' ? int.tryParse(id) ?? 1 : id;
          final baris =
              await db.query(t, where: '$pk = ?', whereArgs: [kunci]);
          if (baris.isEmpty) {
            // Baris sudah terhapus lokal; tombstone yang mengurusnya.
            await db.delete('outbox',
                where: 'tabel = ? AND id_baris = ?', whereArgs: [t, id]);
            continue;
          }
          final muatan = <String, dynamic>{
            for (final k in kolomTabel[t]!) k: baris.first[k],
          };
          await _minta('POST', '/rest/v1/$t',
              isi: [muatan],
              tajukTambahan: {'Prefer': 'resolution=merge-duplicates'});
          await db.delete('outbox',
              where: 'tabel = ? AND id_baris = ?', whereArgs: [t, id]);
          dikirim++;
        }
       } catch (_) {
        // Tabel ini dilewati putaran ini; antreannya dicoba lagi nanti.
       }
      }

      await _aturMeta(
          db, 'sinkron_terakhir', DateTime.now().toIso8601String());
      return HasilSinkron(
        sukses: true,
        pesan: 'Sinkronisasi selesai: $ditarik ditarik, $dikirim dikirim.',
        ditarik: ditarik,
        dikirim: dikirim,
      );
    } catch (e) {
      return HasilSinkron(
          sukses: false, pesan: 'Sinkronisasi gagal: $e');
    } finally {
      _berjalan = false;
    }
  }

  /// Terapkan satu baris hasil tarikan ke database lokal.
  static Future<void> _terapkanBaris(
      Database db, String tabel, Map<String, dynamic> baris) async {
    final pk = GrowTrackDB.tabelSinkron[tabel]!;
    if (baris['deleted_at'] != null) {
      await db.delete(tabel, where: '$pk = ?', whereArgs: [baris[pk]]);
      return;
    }
    final lokal = <String, Object?>{
      for (final k in kolomTabel[tabel]!) k: baris[k],
    };
    await db.insert(tabel, lokal,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
