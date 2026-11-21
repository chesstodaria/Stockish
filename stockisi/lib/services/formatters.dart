import 'package:intl/intl.dart';

/// Format tanggal dan angka gaya Indonesia. Tanggal ditulis manual supaya
/// tidak perlu `initializeDateFormatting` (dan tetap jalan di test).
abstract final class Fmt {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static final _number = NumberFormat.decimalPattern('id');

  /// `21 Nov 2026`
  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// `21 Nov 2026, 14.05`
  static String dateTime(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date(d)}, ${two(d.hour)}.${two(d.minute)}';
  }

  /// `2.000`
  static String qty(int value) => _number.format(value);
}
