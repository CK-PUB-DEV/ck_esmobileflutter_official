import 'dart:convert';

import 'package:pushtrial/api/api.dart';

/// One grading period of a school: "1st quarter", "Second Term", "Prelim"...
class GradingPeriod {
  const GradingPeriod(this.no, this.code, this.label);

  final int no;
  final String code;
  final String label;
}

/// How a school grades one grade level, as reported by the v2 server (`grading_setup`).
/// [mode] is 'quarter', 'term' or 'college'. When the school's server is still on v1 there is
/// no answer, and the app keeps showing the standard four quarters.
class GradingSetup {
  const GradingSetup(this.mode, this.periods);

  final String mode;
  final List<GradingPeriod> periods;

  /// The default every school used before this existed.
  static const quarters = GradingSetup('quarter', [
    GradingPeriod(1, '1Q', 'Q1'),
    GradingPeriod(2, '2Q', 'Q2'),
    GradingPeriod(3, '3Q', 'Q3'),
    GradingPeriod(4, '4Q', 'Q4'),
  ]);

  /// Null when the server is v1, offline or answers anything unexpected.
  static Future<GradingSetup?> load(int syid, int levelid) async {
    try {
      final response = await CallApi().getGradingSetup(syid, levelid);
      if (response == null || response.statusCode != 200) return null;
      final body = json.decode(response.body);
      if (body is! Map || body['success'] != true) return null;
      final periods = <GradingPeriod>[
        for (final p in (body['periods'] as List? ?? const []))
          GradingPeriod(
            int.tryParse('${p['no']}') ?? 0,
            '${p['code'] ?? ''}',
            '${p['label'] ?? ''}',
          ),
      ]..removeWhere((p) => p.no < 1 || p.no > 4);
      if (periods.isEmpty) return null;
      return GradingSetup('${body['mode']}', periods);
    } catch (_) {
      return null;
    }
  }
}
