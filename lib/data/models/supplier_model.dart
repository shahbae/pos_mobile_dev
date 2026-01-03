class Supplier {
  final String id;
  final String name;
  final String? pic;
  final String? email;
  final String? address;
  final String? phone;

  Supplier({
    required this.id,
    required this.name,
    this.pic,
    this.email,
    this.address,
    this.phone,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'],
      name: json['name'],
      pic: json['pic'],
      email: json['email'],
      address: json['address'],
      phone: json['phone'],
    );
  }
}
