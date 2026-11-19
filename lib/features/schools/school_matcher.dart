import 'package:pushtrial/features/schools/models/schools.dart';

/// What the school finder shows for what the person has typed.
enum SchoolMatchKind {
  /// Too little typed to search. Nothing is listed.
  idle,

  /// The text is exactly one school's code. [SchoolMatches.schools] holds that one school.
  exactCode,

  /// Schools whose code starts with, or whose name contains, the text.
  results,

  /// Nothing matches.
  none,
}

class SchoolMatches {
  const SchoolMatches(this.kind, [this.schools = const []]);

  final SchoolMatchKind kind;
  final List<School> schools;
}

/// Finds schools by code or name without ever returning the whole list.
///
/// - Case, spaces and punctuation are ignored, so `cmlc bc` finds `CMLC - BC`.
/// - An exact code wins and is returned alone, so `HCB` does not also list `HCHS`.
/// - A code needs [minCodeLength] characters, a name [minNameLength], and at most
///   [maxResults] schools come back.
class SchoolMatcher {
  const SchoolMatcher._();

  static const int minCodeLength = 2;
  static const int minNameLength = 3;
  static const int maxResults = 5;

  static String normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static SchoolMatches find(List<School> schools, String query) {
    final q = normalize(query);
    if (q.length < minCodeLength) return const SchoolMatches(SchoolMatchKind.idle);

    final exact = schools.where((s) => normalize(s.schoolabrv) == q).toList();
    if (exact.isNotEmpty) {
      return SchoolMatches(SchoolMatchKind.exactCode, [exact.first]);
    }

    final byCode = schools
        .where((s) => normalize(s.schoolabrv).startsWith(q))
        .toList()
      ..sort((a, b) => a.schoolname.compareTo(b.schoolname));
    final byName = q.length < minNameLength
        ? <School>[]
        : (schools
              .where((s) => !byCode.contains(s) && normalize(s.schoolname).contains(q))
              .toList()
            ..sort((a, b) => a.schoolname.compareTo(b.schoolname)));

    final found = [...byCode, ...byName].take(maxResults).toList();
    return found.isEmpty
        ? const SchoolMatches(SchoolMatchKind.none)
        : SchoolMatches(SchoolMatchKind.results, found);
  }
}
