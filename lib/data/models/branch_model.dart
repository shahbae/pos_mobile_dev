class BranchModel {
  final int id;
  final String name;
  final String? address;
  final String? footerNote;

  /// Uang laci awal yang dipakai otomatis saat buka shift di cabang ini.
  /// Diambil dari master cabang (BE). Default 0.
  final num defaultOpeningCash;

  const BranchModel({
    required this.id,
    required this.name,
    this.address,
    this.footerNote,
    this.defaultOpeningCash = 0,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String?,
      footerNote: json['footer_note'] as String?,
      defaultOpeningCash: (json['default_opening_cash'] as num?) ?? 0,
    );
  }
}
