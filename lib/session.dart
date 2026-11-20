/// Port fungsi/SesiUser.java: sesi pengguna yang sedang login,
/// disimpan sebagai objek global sederhana.
class SesiUser {
  static int idUser = 0;
  static String? username;
  static String? namaLengkap;
  static String? role;
  static String? idOrtu;

  static bool get isAdmin => role != null && role!.toLowerCase() == 'admin';

  static bool get isOrangTua =>
      role != null && role!.toLowerCase() == 'orang tua';

  static void isi({
    required int id,
    required String user,
    required String nama,
    required String peran,
    String? idOrtu,
  }) {
    idUser = id;
    username = user;
    namaLengkap = nama;
    role = peran;
    SesiUser.idOrtu = idOrtu;
  }

  static void logout() {
    idUser = 0;
    username = null;
    namaLengkap = null;
    role = null;
    idOrtu = null;
  }
}
