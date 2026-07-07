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

  const BranchModel({
    required this.id,
    required this.name,
    this.address,
    this.footerNote,
    this.complaintNote,
    this.defaultOpeningCash = 0,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String?,
      footerNote: json['footer_note'] as String?,
      complaintNote: json['complaint_note'] as String?,
      defaultOpeningCash: (json['default_opening_cash'] as num?) ?? 0,
    );
  }
}
