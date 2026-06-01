class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final int? branchId;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.branchId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['nama'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['peran'] ?? json['role'] ?? '',
      branchId: json['id_cabang'] ?? json['branch_id'],
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isCashier => role == 'kasir';
}
