import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/database.dart';
import '../widgets.dart';

/// Kode versi aplikasi ini. WAJIB disamakan dengan angka sesudah tanda +
/// pada version di pubspec.yaml setiap rilis (1.6.1+10 -> 10).
const int kKodeVersiIni = 16;
const String kNamaVersiIni = '1.9.2';

const String _urlVersi =
    'https://demo.43-130-228-96.sslip.io/growtrack-version.json';

class InfoUpdate {
  final int kode;
  final String nama;
  final String urlApk;
  final String catatan;

  const InfoUpdate({
    required this.kode,
    required this.nama,
    required this.urlApk,
    required this.catatan,
  });
}

/// Cek pembaruan dari berkas versi di server demo. Bila ada versi lebih
/// baru, tampilkan dialog dengan tombol unduh; APK di server ditandatangani
/// kunci rilis permanen sehingga bisa langsung menimpa versi terpasang.
class LayananUpdate {
  static Future<InfoUpdate?> _ambilInfo() async {
    final klien = HttpClient();
    try {
      klien.connectionTimeout = const Duration(seconds: 8);
      final req = await klien.getUrl(Uri.parse(_urlVersi));
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      final teks = await resp.transform(utf8.decoder).join();
      final j = jsonDecode(teks) as Map<String, dynamic>;
      return InfoUpdate(
        kode: (j['versionCode'] as num?)?.toInt() ?? 0,
        nama: j['versionName']?.toString() ?? '',
        urlApk: j['url']?.toString() ?? '',
        catatan: j['catatan']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    } finally {
      klien.close(force: true);
    }
  }

  static Future<bool> _sudahWaktunya() async {
    try {
      final db = await GrowTrackDB.database;
      final rows = await db.query('sinkron_meta',
          where: 'kunci = ?',
          whereArgs: ['cek_update_terakhir'],
          limit: 1);
      if (rows.isEmpty) return true;
      final terakhir =
          int.tryParse(rows.first['nilai']?.toString() ?? '') ?? 0;
      final kini = DateTime.now().millisecondsSinceEpoch;
      return kini - terakhir > 12 * 60 * 60 * 1000;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _catatCek() async {
    try {
      final db = await GrowTrackDB.database;
      await db.execute(
        'INSERT OR REPLACE INTO sinkron_meta (kunci, nilai) VALUES (?, ?)',
        ['cek_update_terakhir', '${DateTime.now().millisecondsSinceEpoch}'],
      );
    } catch (_) {}
  }

  /// Cek otomatis saat aplikasi dibuka (maksimal sekali per 12 jam).
  static Future<void> cekOtomatis(BuildContext context) async {
    if (!await _sudahWaktunya()) return;
    await _catatCek();
    final info = await _ambilInfo();
    if (info == null || info.kode <= kKodeVersiIni) return;
    if (!context.mounted) return;
    _tampilkanDialog(context, info);
  }

  /// Cek manual dari menu Pengaturan.
  static Future<void> cekManual(BuildContext context) async {
    final info = await _ambilInfo();
    if (!context.mounted) return;
    if (info == null) {
      tampilSnack(context, 'Tidak bisa memeriksa pembaruan saat ini.');
      return;
    }
    if (info.kode <= kKodeVersiIni) {
      tampilSnack(context, 'GrowTrack sudah versi terbaru ($kNamaVersiIni).');
      return;
    }
    _tampilkanDialog(context, info);
  }

  static void _tampilkanDialog(BuildContext context, InfoUpdate info) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ada Versi Baru'),
        content: Text(
          'GrowTrack ${info.nama} sudah tersedia.'
          '${info.catatan.isEmpty ? '' : '\n\n${info.catatan}'}'
          '\n\nKetuk Perbarui untuk mengunduh langsung di dalam aplikasi, '
          'lalu pasang menimpa versi ini (data tidak hilang).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _unduhDanPasang(context, info);
            },
            child: const Text('Perbarui'),
          ),
        ],
      ),
    );
  }

  /// Unduh APK versi baru di dalam aplikasi (dengan indikator progres),
  /// lalu buka pemasang sistem. Bila unduhan gagal, jatuhkan ke peramban.
  static Future<void> _unduhDanPasang(
      BuildContext context, InfoUpdate info) async {
    final progres = ValueNotifier<double?>(null);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Mengunduh Pembaruan'),
        content: ValueListenableBuilder<double?>(
          valueListenable: progres,
          builder: (_, v, __) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: v),
              const SizedBox(height: 12),
              Text(v == null
                  ? 'Menyiapkan unduhan...'
                  : 'Terunduh ${(v * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    );
    File? berkas;
    try {
      final dir = await getTemporaryDirectory();
      berkas = File('${dir.path}/growtrack-update.apk');
      final klien = HttpClient();
      try {
        final req = await klien.getUrl(Uri.parse(info.urlApk));
        final resp = await req.close();
        if (resp.statusCode != 200) {
          throw Exception('status ${resp.statusCode}');
        }
        final total = resp.contentLength;
        var diterima = 0;
        final penampung = berkas.openWrite();
        await for (final potong in resp) {
          penampung.add(potong);
          diterima += potong.length;
          if (total > 0) progres.value = diterima / total;
        }
        await penampung.flush();
        await penampung.close();
      } finally {
        klien.close(force: true);
      }
    } catch (_) {
      berkas = null;
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (berkas == null) {
      await launchUrl(Uri.parse(info.urlApk),
          mode: LaunchMode.externalApplication);
      return;
    }
    final hasil = await OpenFilex.open(
      berkas.path,
      type: 'application/vnd.android.package-archive',
    );
    if (hasil.type != ResultType.done && context.mounted) {
      await launchUrl(Uri.parse(info.urlApk),
          mode: LaunchMode.externalApplication);
    }
  }
}
