class BranchModel {
  final int id;
  final String name;
  final String? address;
  final String? footerNote;

  /// Catatan komplain (revisi BE 2026-07-07). Opsional, omitempty → bisa null.
  final String? complaintNote;

  /// Uang laci awal yang dipakai otomatis saat buka shift di cabang ini.
  /// Diambil dari master cabang (BE). Default 0.
  final num defaultOpeningCash;

  /// Koordinat & radius absensi cabang. Dipakai sidak (Tahap 6) untuk
  /// memeriksa jarak di HP sebelum checklist diisi; server tetap penentunya.
  /// Null = koordinat belum diatur di master cabang.
  final double? latitude;
  final double? longitude;
  final int attendanceRadius;

  /// `active` / `disabled`. Kosong bila server tidak mengirim.
  final String status;

  const BranchModel({
    required this.id,
    required this.name,
    this.address,
    this.footerNote,
    this.complaintNote,
    this.defaultOpeningCash = 0,
    this.latitude,
    this.longitude,
    this.attendanceRadius = 100,
    this.status = '',
  });

  bool get hasGeo => latitude != null && longitude != null;

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String?,
      footerNote: json['footer_note'] as String?,
      complaintNote: json['complaint_note'] as String?,
      defaultOpeningCash: (json['default_opening_cash'] as num?) ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      attendanceRadius: (json['attendance_radius'] as num?)?.toInt() ?? 100,
      status: json['status'] as String? ?? '',
    );
  }
}
