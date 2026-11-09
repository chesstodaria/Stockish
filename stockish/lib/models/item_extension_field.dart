// lib/models/item_extension_field.dart (BARU, 12 Agustus 2026)
// Dipindah dari transaction_item.dart supaya dipakai bersama Transaction
// Detail ("Show More") dan Digital Stock Card ("Show More") — keduanya
// genuinely konsumsi field yang sama (Item Master extensionFields, dari
// GET /items), bukan 2 konsep beda yang kebetulan mirip.

/// 1 baris Extension Field ("Show More"). Read-only snapshot dari yang
/// sudah dipetakan Admin lewat ERP Admin Configurator (persisted di
/// backend ItemExtensionValue).
class ItemExtensionField {
  final String label;
  final String? description;
  final String value;

  const ItemExtensionField({
    required this.label,
    this.description,
    required this.value,
  });

  factory ItemExtensionField.fromJson(Map<String, dynamic> json) {
    return ItemExtensionField(
      label: json['label'] as String,
      description: json['description'] as String?,
      value: json['value'] as String,
    );
  }
}