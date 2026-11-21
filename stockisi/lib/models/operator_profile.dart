/// Operator gudang yang login. Mengikuti tabel `profiles` (laporan 2.7),
/// digabung dengan nama gudang dari `warehouses` supaya layar tidak perlu
/// memuat gudang terpisah.
class OperatorProfile {
  final String nik;
  final String name;
  final String warehouseCode;
  final String warehouseName;
  final bool isActive;

  const OperatorProfile({
    required this.nik,
    required this.name,
    required this.warehouseCode,
    required this.warehouseName,
    required this.isActive,
  });
}
