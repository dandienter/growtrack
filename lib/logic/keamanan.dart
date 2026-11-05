import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Port proses/KeamananPassword.java.
/// Algoritma: SHA-256(salt + password), hex huruf kecil.
/// Akun lama tanpa salt diverifikasi dengan SHA-256(password) saja.
class KeamananPassword {
  static final Random _acak = Random.secure();

  /// Salt baru: 16 byte acak dalam hex (32 karakter).
  static String generateSalt() {
    final bytes = List<int>.generate(16, (_) => _acak.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String hash(String password, String salt) {
    final digest = sha256.convert(utf8.encode(salt + password));
    return digest.toString(); // hex huruf kecil
  }

  /// Hash gaya lama (tanpa salt).
  static String hashLegacy(String password) => hash(password, '');

  static bool verify(String passwordInput, String? salt, String? dbHash) {
    if (dbHash == null) return false;
    if (salt == null || salt.isEmpty) {
      return dbHash.toLowerCase() == hashLegacy(passwordInput);
    }
    return dbHash.toLowerCase() == hash(passwordInput, salt);
  }
}
