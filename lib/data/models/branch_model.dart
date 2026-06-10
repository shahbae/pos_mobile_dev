class BranchModel {
  final int id;
  final String name;
  final String? address;
  final String? footerNote;

  const BranchModel({
    required this.id,
    required this.name,
    this.address,
    this.footerNote,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String?,
      footerNote: json['footer_note'] as String?,
    );
  }
}
