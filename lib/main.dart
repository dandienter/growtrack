import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'db/database.dart';
import 'screens/login.dart';
import 'screens/utama.dart';
import 'widgets.dart';

/// Gaya bilah sistem global: status bar teal dengan ikon terang,
/// bilah navigasi sistem putih dengan ikon gelap. Disamakan dengan
/// AppBarTheme agar warna status bar tidak nabrak di semua layar.
const SystemUiOverlayStyle kGayaBilahSistem = SystemUiOverlayStyle(
  statusBarColor: kTeal,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.white,
  systemNavigationBarIconBrightness: Brightness.dark,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(kGayaBilahSistem);
  await initializeDateFormatting('id_ID', null);
  var sudahLogin = false;
  try {
    sudahLogin = await GrowTrackDB.pulihkanSesi();
  } catch (_) {}
  runApp(GrowTrackApp(sudahLogin: sudahLogin));
}

class GrowTrackApp extends StatelessWidget {
  final bool sudahLogin;

  const GrowTrackApp({super.key, this.sudahLogin = false});

  @override
  Widget build(BuildContext context) {
    final skema = ColorScheme.fromSeed(
      seedColor: kTeal,
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'GrowTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: skema,
        scaffoldBackgroundColor: kLatar,
        appBarTheme: const AppBarTheme(
          backgroundColor: kTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: kGayaBilahSistem,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE0F2F1),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => TextStyle(
              fontSize: 11,
              fontWeight:
                  s.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: kTeal,
          foregroundColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: sudahLogin ? const UtamaScreen() : const LoginScreen(),
    );
  }
}
