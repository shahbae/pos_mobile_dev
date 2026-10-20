/// Data identitas user dari endpoint `GET /me`.
///
/// Response BE:
/// { success, data: { id, branch_id, name, email, role, roles, status, created_at } }
///
/// `role` = role utama; `roles` = seluruh role yang dipegang (multi-role).
class MeModel {
  final int? id;
  final int? branchId;
  final String? name;
  final String? email;
  final String? role;
  final List<String> roles;
  final String? status;

  const MeModel({
    this.id,
    this.branchId,
    this.name,
    this.email,
    this.role,
    this.roles = const [],
    this.status,
  });

  factory MeModel.fromJson(Map<String, dynamic> json) {
    return MeModel(
      id: _toInt(json['id']),
      branchId: _toInt(json['branch_id'] ?? json['branchId']),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString().toLowerCase(),
      roles: _toRoles(json['roles']),
      status: json['status']?.toString(),
    );
  }

  static List<String> _toRoles(dynamic v) {
    if (v is! List) return const [];
    return [
      for (final r in v)
        if (r != null && r.toString().trim().isNotEmpty)
          r.toString().trim().toLowerCase(),
    ];
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
