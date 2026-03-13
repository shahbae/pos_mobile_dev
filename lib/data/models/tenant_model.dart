class TenantModel {
  final int id;
  final String name;
  final String businessType;
  final String status;
  final DateTime createdAt;

  TenantModel({
    required this.id,
    required this.name,
    required this.businessType,
    required this.status,
    required this.createdAt,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as int,
      name: json['name'] as String,
      businessType: json['business_type'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
