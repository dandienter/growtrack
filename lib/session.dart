/// Port fungsi/SesiUser.java: sesi pengguna yang sedang login,
/// disimpan sebagai objek global sederhana.
class SesiUser {
  static int idUser = 0;
  static String? username;
  static String? namaLengkap;
  static String? role;

  static bool get isAdmin =>
      role != null && role!.toLowerCase() == 'admin';

  static void isi({
    required int id,
    required String user,
    required String nama,
    required String peran,
  }) {
    idUser = id;
    username = user;
    namaLengkap = nama;
    role = peran;
  }

  static void logout() {
    idUser = 0;
    username = null;
    namaLengkap = null;
    role = null;
  }
}
