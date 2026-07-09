/// Data identitas user dari endpoint `GET /me`.
///
/// Response BE:
/// { success, data: { id, branch_id, name, email, role, status, created_at } }
class MeModel {
  final int? id;
  final int? branchId;
  final String? name;
  final String? email;
  final String? role;
  final String? status;

  const MeModel({
    this.id,
    this.branchId,
    this.name,
    this.email,
    this.role,
    this.status,
  });

  factory MeModel.fromJson(Map<String, dynamic> json) {
    return MeModel(
      id: _toInt(json['id']),
      branchId: _toInt(json['branch_id'] ?? json['branchId']),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString().toLowerCase(),
      status: json['status']?.toString(),
    );
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
