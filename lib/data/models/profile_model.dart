/// Profil sendiri dari `GET /me/profile` (Tahap 1 SDM).
///
/// Yang boleh diubah orangnya sendiri hanya [phone], [address], dan kontak
/// darurat. Sisanya (NIK, rekening, tanggal kerja) diubah owner atau SPV.
class ProfileModel {
  final int id;
  final String name;
  final String email;
  final String? role;
  final List<String> roles;
  final String? photoUrl;
  final String? phone;
  final String? address;
  final String? birthDate;
  final String? nik;
  final String? joinedAt;
  /// Hanya leader: cabang yang dipimpin. Selain leader, cabang kerja
  /// mengikuti jadwal dan tidak ada di profil.
  final String? leadBranchName;
  final String? bankName;
  final String? bankAccount;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  const ProfileModel({
    required this.id,
    required this.name,
    this.email = '',
    this.role,
    this.roles = const [],
    this.photoUrl,
    this.phone,
    this.address,
    this.birthDate,
    this.nik,
    this.joinedAt,
    this.leadBranchName,
    this.bankName,
    this.bankAccount,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final lead = json['lead_branch'];
    return ProfileModel(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString(),
      roles: json['roles'] is List
          ? [for (final r in json['roles']) if (r != null) r.toString()]
          : const [],
      photoUrl: _str(json['photo_url']),
      phone: _str(json['phone']),
      address: _str(json['address']),
      birthDate: _str(json['birth_date']),
      nik: _str(json['nik']),
      joinedAt: _str(json['joined_at']),
      leadBranchName: lead is Map ? _str(lead['name']) : null,
      bankName: _str(json['bank_name']),
      bankAccount: _str(json['bank_account']),
      emergencyContactName: _str(json['emergency_contact_name']),
      emergencyContactPhone: _str(json['emergency_contact_phone']),
    );
  }

  static String? _str(dynamic v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
