class Employee {
  final int id;
  final int tenantId;
  final String name;
  final String email;
  final String role;
  final String status;
  final String createdAt;

  Employee({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] ?? 0,
      tenantId: json['tenant_id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'email': email,
      'role': role,
      'status': status,
      'created_at': createdAt,
    };
  }
}

class EmployeeRequest {
  final String name;
  final String email;
  final String? password;
  final String status;

  EmployeeRequest({
    required this.name,
    required this.email,
    this.password,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      if (password != null) 'password': password,
      'status': status,
    };
  }
}
