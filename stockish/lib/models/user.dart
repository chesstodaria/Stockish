class User {
  final String userId; // = NIK — backend tidak punya id terpisah, NIK adalah PK
  final String nik;
  final String userName;
  final List<String> roles; // BARU (29 Juli 2026) — multi-select, label informatif saja
  final bool accessAdmin;
  final bool accessMobileOperator;
  final bool accessMobileSupervisor;
  final String warehouseCode;
  final String warehouseName; // sementara selalu '' — backend belum kirim field ini, lihat Known Issues
  final String token;

  User({
    required this.userId,
    required this.nik,
    required this.userName,
    required this.roles,
    required this.accessAdmin,
    required this.accessMobileOperator,
    required this.accessMobileSupervisor,
    required this.warehouseCode,
    this.warehouseName = '',
    required this.token,
  });

  // Dipakai SessionStorageService buat roundtrip ke/dari secure storage (Remember Login).
  // TIDAK dipakai buat parsing response backend langsung — lihat fromLoginResponse di bawah.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      nik: json['nik'],
      userName: json['user_name'],
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      accessAdmin: json['access_admin'] as bool? ?? false,
      accessMobileOperator: json['access_mobile_operator'] as bool? ?? false,
      accessMobileSupervisor: json['access_mobile_supervisor'] as bool? ?? false,
      warehouseCode: json['warehouse_code'] ?? '',
      warehouseName: json['warehouse_name'] ?? '',
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'nik': nik,
      'user_name': userName,
      'roles': roles,
      'access_admin': accessAdmin,
      'access_mobile_operator': accessMobileOperator,
      'access_mobile_supervisor': accessMobileSupervisor,
      'warehouse_code': warehouseCode,
      'warehouse_name': warehouseName,
      'token': token,
    };
  }

  // Parsing khusus field `data` dari response asli stockflow-backend
  // (envelope {success,message,data}), format camelCase, BEDA dari fromJson/toJson di atas.
  // 29 Juli 2026 — diupdate ikut rombakan access model 27 Juli (role tunggal →
  // roles multi + 3 flag akses eksplisit). Field lama `role` DIHAPUS, ganti `roles`.
  factory User.fromLoginResponse(Map<String, dynamic> json) {
    return User(
      userId: json['nik'] as String,
      nik: json['nik'] as String,
      userName: json['userName'] as String,
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      accessAdmin: json['accessAdmin'] as bool? ?? false,
      accessMobileOperator: json['accessMobileOperator'] as bool? ?? false,
      accessMobileSupervisor: json['accessMobileSupervisor'] as bool? ?? false,
      warehouseCode: json['warehouseCode'] as String? ?? '',
      warehouseName: json['warehouseName'] as String? ?? '',
      token: json['token'] as String,
    );
  }
}