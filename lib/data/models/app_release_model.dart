/// Rilis aktif yang dilaporkan `GET /app-version` di be-pos
/// (`internal/handlers/app_release_handler.go` → `PublicVersion`).
///
/// [versionCode] adalah satu-satunya angka yang boleh dipakai membandingkan
/// versi. [version] hanya nama untuk dibaca manusia, dan sebagai string
/// "1.10.0" berada sebelum "1.9.0".
class AppReleaseInfo {
  final String version;
  final int versionCode;
  final String fileName;
  final int fileSize;
  final String checksumSha256;
  final String releaseNotes;
  final String downloadUrl;
  final String pageUrl;

  const AppReleaseInfo({
    required this.version,
    required this.versionCode,
    required this.fileName,
    required this.fileSize,
    required this.checksumSha256,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.pageUrl,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    return AppReleaseInfo(
      version: (json['version'] ?? '-').toString(),
      versionCode: _asInt(json['version_code']),
      fileName: (json['file_name'] ?? 'update.apk').toString(),
      fileSize: _asInt(json['file_size']),
      // BE mengirimnya huruf kecil, tapi perbandingannya harus tetap aman
      // kalau suatu saat berubah.
      checksumSha256: (json['checksum_sha256'] ?? '').toString().toLowerCase(),
      releaseNotes: (json['release_notes'] ?? '').toString().trim(),
      downloadUrl: (json['download_url'] ?? '').toString(),
      pageUrl: (json['page_url'] ?? '').toString(),
    );
  }

  /// Ukuran berkas untuk ditampilkan sebelum orang menekan "Perbarui" — di
  /// jaringan outlet, 60 MB adalah informasi yang layak diketahui lebih dulu.
  String get fileSizeLabel {
    const mb = 1024 * 1024;
    if (fileSize >= mb) return '${(fileSize / mb).toStringAsFixed(1)} MB';
    return '${(fileSize / 1024).toStringAsFixed(0)} KB';
  }

  String get label => '$version ($versionCode)';

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
