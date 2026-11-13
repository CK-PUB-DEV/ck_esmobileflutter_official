import 'package:intl/intl.dart';

/// One place for how money, dates and times look, so every screen matches.
abstract final class Fmt {
  static final NumberFormat _money = NumberFormat('#,##0.00');

  /// `Php 1,234.50`. Null, empty or unparsable input shows `Php 0.00`. Uses "Php" rather than
  /// the ₱ sign because the app font has no ₱ glyph and it renders as a broken box.
  static String money(Object? value) {
    final n = value is num ? value : num.tryParse('${value ?? ''}'.replaceAll(',', ''));
    final v = n ?? 0;
    return v < 0 ? '-Php ${_money.format(-v)}' : 'Php ${_money.format(v)}';
  }

  /// `Oct 28, 2026`. Returns [fallback] when the value can't be read as a date.
  static String date(Object? value, {String fallback = '—'}) {
    final d = _toDate(value);
    return d == null ? fallback : DateFormat('MMM d, y').format(d);
  }

  /// `Oct 28`.
  static String dayMonth(Object? value, {String fallback = '—'}) {
    final d = _toDate(value);
    return d == null ? fallback : DateFormat('MMM d').format(d);
  }

  /// `7:42 AM` from `07:42:10`, `7:42 AM` or a DateTime.
  static String time(Object? value, {String fallback = '—'}) {
    if (value is DateTime) return DateFormat('h:mm a').format(value);
    final s = '${value ?? ''}'.trim();
    if (s.isEmpty) return fallback;
    for (final pattern in const ['HH:mm:ss', 'HH:mm', 'h:mm a']) {
      try {
        return DateFormat('h:mm a').format(DateFormat(pattern).parseStrict(s));
      } catch (_) {}
    }
    return s;
  }

  static DateTime? _toDate(Object? value) {
    if (value is DateTime) return value;
    final s = '${value ?? ''}'.trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}
