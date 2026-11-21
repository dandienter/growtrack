import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'db/database.dart';
import 'format.dart';
import 'session.dart';

/// Notifikasi lokal (tanpa server dan tanpa Firebase): pengingat
/// imunisasi dan jadwal timbang dihitung dari data di perangkat,
/// lalu dijadwalkan ulang setiap aplikasi dibuka.
class LayananNotifikasi {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _siap = false;

  static const _detail = NotificationDetails(
    android: AndroidNotificationDetails(
      'pengingat_jadwal',
      'Pengingat Jadwal',
      channelDescription:
          'Pengingat imunisasi dan penimbangan dari GrowTrack',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> _siapkan() async {
    if (_siap) return;
    tzdata.initializeTimeZones();
    // Zona waktu dipilih dari offset perangkat (Indonesia: WIB/WITA/WIT).
    final offset = DateTime.now().timeZoneOffset.inHours;
    final namaZona = offset >= 9
        ? 'Asia/Jayapura'
        : offset == 8
            ? 'Asia/Makassar'
            : 'Asia/Jakarta';
    tz.setLocalLocation(tz.getLocation(namaZona));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
    _siap = true;
  }

  /// Batalkan semua pengingat lama lalu jadwalkan ulang dari data
  /// terbaru: imunisasi yang akan jatuh tempo dan anak yang sudah
  /// waktunya ditimbang lagi (30 hari sejak pemeriksaan terakhir).
  static Future<void> jadwalkanUlang() async {
    try {
      await _siapkan();
      if (!_siap) return;
      await _plugin.cancelAll();
      final sekarang = DateTime.now();
      var id = 1000;
      var jumlah = 0;

      final untukOrtu = SesiUser.isOrangTua;
      bool milikSendiri(String? idOrtu) =>
          !untukOrtu || idOrtu == SesiUser.idOrtu;

      // Pengingat imunisasi (jadwal belum selesai).
      final jadwal = await GrowTrackDB.ambilJadwal();
      for (final j in jadwal) {
        if (jumlah >= 12) break;
        if (j.status.toLowerCase() == 'selesai') continue;
        final target =
            parseTanggalDb(j.tglBerikutnya) ?? parseTanggalDb(j.tglDiberikan);
        if (target == null) continue;
        final balita = j.idBalita.isEmpty
            ? null
            : await GrowTrackDB.ambilBalitaById(j.idBalita);
        if (balita != null && !milikSendiri(balita.idOrtu)) continue;
        final waktu = DateTime(target.year, target.month, target.day, 8);
        if (!waktu.isAfter(sekarang)) continue;
        await _plugin.zonedSchedule(
          id++,
          'Pengingat Imunisasi',
          '${j.namaBalita ?? 'Anak'}: imunisasi ${j.namaImunisasi ?? ''} '
              'dijadwalkan ${formatTanggalID(j.tglBerikutnya ?? j.tglDiberikan)}.',
          tz.TZDateTime.from(waktu, tz.local),
          _detail,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        jumlah++;
      }

      // Pengingat timbang ulang (30 hari sejak pemeriksaan terakhir).
      final semuaBalita = await GrowTrackDB.ambilBalita();
      var jumlahTimbang = 0;
      for (final b in semuaBalita) {
        if (jumlahTimbang >= 8) break;
        if (!milikSendiri(b.idOrtu)) continue;
        final periksa =
            await GrowTrackDB.ambilPemeriksaan(idBalita: b.idBalita);
        if (periksa.isEmpty) continue;
        final terakhir = parseTanggalDb(periksa.first.tanggal);
        if (terakhir == null) continue;
        final target = terakhir.add(const Duration(days: 30));
        final waktu = DateTime(target.year, target.month, target.day, 8);
        if (!waktu.isAfter(sekarang)) continue;
        if (waktu.difference(sekarang).inDays > 60) continue;
        await _plugin.zonedSchedule(
          id++,
          'Waktunya Timbang Lagi',
          '${b.namaBalita} terakhir diperiksa '
              '${formatTanggalID(periksa.first.tanggal)}. '
              'Yuk jadwalkan penimbangan berikutnya.',
          tz.TZDateTime.from(waktu, tz.local),
          _detail,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        jumlahTimbang++;
      }
    } catch (_) {
      // Notifikasi bersifat tambahan; kegagalan di sini tidak boleh
      // mengganggu penggunaan aplikasi.
    }
  }
}
