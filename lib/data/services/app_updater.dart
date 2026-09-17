import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:pos_mobile/data/models/app_release_model.dart';

/// Mengunduh APK rilis aktif lalu menyerahkannya ke pemasang bawaan Android.
///
/// Aplikasi ini dibagikan di luar Play Store, jadi tidak ada mekanisme update
/// dari sistem. Yang bisa dilakukan aplikasi hanyalah menyiapkan berkasnya dan
/// membuka layar pemasangan; menekan "Pasang" tetap urusan penggunanya.
class AppUpdater {
  final Dio _dio;

  AppUpdater({Dio? client})
      : _dio = client ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                // Dio menghitung receiveTimeout sebagai jeda antar potongan
                // data, bukan lama unduhan keseluruhan. Dua menit memberi
                // ruang untuk jaringan outlet yang tersendat tanpa membuat
                // koneksi yang benar-benar mati menggantung selamanya.
                receiveTimeout: const Duration(minutes: 2),
              ),
            );

  /// Mengunduh [release] ke penyimpanan sementara dan mengembalikan berkasnya.
  ///
  /// Kalau berkas dari percobaan sebelumnya masih ada dan checksum-nya cocok,
  /// unduhan dilewati. Orang yang gagal memasang karena izinnya belum
  /// diberikan tidak perlu menunggu 60 MB untuk kedua kalinya.
  Future<File> download(
    AppReleaseInfo release, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/update');
    await dir.create(recursive: true);
    final target = File('${dir.path}/${release.fileName}');

    if (await target.exists() &&
        await _checksumOf(target) == release.checksumSha256) {
      onProgress?.call(release.fileSize, release.fileSize);
      return target;
    }

    // Ditulis ke nama sementara supaya berkas yang setengah jadi tidak pernah
    // menempati nama yang dianggap "sudah siap pasang" oleh percobaan berikutnya.
    final partial = File('${target.path}.part');
    try {
      await _dio.download(
        release.downloadUrl,
        partial.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) => onProgress?.call(
          received,
          total > 0 ? total : release.fileSize,
        ),
      );
    } on DioException catch (e) {
      await _deleteQuietly(partial);
      if (CancelToken.isCancel(e)) rethrow;
      throw 'Unduhan gagal. Periksa koneksi lalu coba lagi.';
    } catch (_) {
      await _deleteQuietly(partial);
      rethrow;
    }

    // Checksum bukan formalitas. Unduhan sebesar ini lewat jaringan seluler
    // cukup sering terpotong dan tetap meninggalkan berkas yang "ada". Kalau
    // yang rusak diteruskan ke pemasang, Android hanya menjawab "App not
    // installed" tanpa menyebut sebabnya, dan orang di outlet tidak punya cara
    // menebaknya.
    if (release.checksumSha256.isNotEmpty &&
        await _checksumOf(partial) != release.checksumSha256) {
      await _deleteQuietly(partial);
      throw 'Berkas yang diunduh tidak utuh. Coba ulangi pembaruan.';
    }

    await _deleteQuietly(target);
    await partial.rename(target.path);
    return target;
  }

  /// Membuka layar pemasangan Android untuk [apk].
  ///
  /// Sejak Android 8 izin "Instal aplikasi tidak dikenal" diberikan per
  /// aplikasi lewat Setelan, bukan lewat dialog biasa. `request()` mengantar
  /// pengguna ke halaman itu; kalau ia kembali tanpa mengaktifkannya, hasilnya
  /// tetap ditolak dan kita berhenti di situ dengan pesan yang jelas.
  Future<void> install(File apk) async {
    final status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) {
      throw 'Izin memasang aplikasi belum diberikan. Aktifkan "Instal aplikasi '
          'tidak dikenal" untuk aplikasi ini di Setelan, lalu ulangi.';
    }

    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw 'Pemasang aplikasi tidak bisa dibuka (${result.message}).';
    }
  }

  /// Membuang APK yang sudah tidak dipakai supaya cache tidak menyimpan
  /// beberapa rilis sekaligus.
  Future<void> clearCache() async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/update');
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Sisa berkas di cache bukan kesalahan yang perlu ditunjukkan; sistem
      // akan membersihkannya sendiri saat penyimpanan menipis.
    }
  }

  Future<String> _checksumOf(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
