import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/splash.dart';
import 'widgets.dart';

/// Gaya bilah sistem global: status bar warna kertas dengan ikon gelap,
/// bilah navigasi sistem putih dengan ikon gelap. Disamakan dengan
/// AppBarTheme agar warna status bar tidak nabrak di semua layar.
const SystemUiOverlayStyle kGayaBilahSistem = SystemUiOverlayStyle(
  statusBarColor: kLatar,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.white,
  systemNavigationBarIconBrightness: Brightness.dark,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(kGayaBilahSistem);
  await initializeDateFormatting('id_ID', null);
  runApp(const GrowTrackApp());
}

class GrowTrackApp extends StatelessWidget {
  const GrowTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    final skema = ColorScheme.fromSeed(
      seedColor: kTeal,
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'GrowTrack',
      debugShowCheckedModeBanner: false,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'PlusJakartaSans',
        colorScheme: skema,
        scaffoldBackgroundColor: kLatar,
        appBarTheme: const AppBarTheme(
          backgroundColor: kLatar,
          foregroundColor: kTinta,
          elevation: 0,
          systemOverlayStyle: kGayaBilahSistem,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFDFF2E4),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => TextStyle(
              fontSize: 11,
              fontWeight:
                  s.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {TargetPlatform.android: PembuatTransisiHalus()},
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        dialogTheme: DialogThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
      home: const SplashScreen(),
    );
  }
}
