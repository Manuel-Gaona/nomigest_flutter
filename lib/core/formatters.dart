import 'package:intl/intl.dart';

final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);
final _numero = NumberFormat.decimalPatternDigits(locale: 'es_MX', decimalDigits: 2);

/// $12,450.00
String moneda(num? valor) => _moneda.format(valor ?? 0);

/// 12,450.5 → "12,450.50"
String numero(num? valor) => _numero.format(valor ?? 0);

/// Fecha ISO (AAAA-MM-DD...) → 15/10/2026
String fecha(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? '' : DateFormat('dd/MM/yyyy').format(d);
}

/// Fecha ISO → 15 oct 2026
String fechaCorta(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? '' : DateFormat('d MMM yyyy', 'es_MX').format(d);
}

/// Fecha y hora UTC ISO → hora local 15/10/2026 14:30
String fechaHora(String? iso) {
  var d = DateTime.tryParse(iso ?? '');
  if (d == null) return '';
  if (!d.isUtc && !(iso ?? '').contains('+')) {
    d = DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
  }
  return DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
}

/// DateTime → AAAA-MM-DD (formato de la API)
String isoFecha(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String capitalizar(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1).replaceAll('_', ' ');
