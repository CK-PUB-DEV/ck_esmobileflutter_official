import 'package:flutter_test/flutter_test.dart';
import 'package:pushtrial/features/schools/models/schools.dart';
import 'package:pushtrial/features/schools/school_matcher.dart';

School _school(int id, String abrv, String name) => School(
  id: id,
  eslink: 'https://example.test/$id',
  schoolabrv: abrv,
  schoolname: name,
  schoollogo: '',
  anydesk: '',
);

void main() {
  final schools = [
    _school(1, 'HCB', 'Holy Child Bohol'),
    _school(2, 'HCHS', 'Holy Cross High School'),
    _school(3, 'MSL', 'Mother Seton Laboratory'),
    _school(4, 'CMLC - BC', 'CMLC Bacolod'),
    _school(5, 'ACFI', 'Asia Christian Foundation'),
    _school(6, 'XY', 'Holy Spirit Academy'),
  ];

  test('nothing is listed until two characters are typed', () {
    expect(SchoolMatcher.find(schools, '').kind, SchoolMatchKind.idle);
    expect(SchoolMatcher.find(schools, ' h ').kind, SchoolMatchKind.idle);
  });

  test('an exact code is returned alone, ignoring case', () {
    final r = SchoolMatcher.find(schools, 'hcb');
    expect(r.kind, SchoolMatchKind.exactCode);
    expect(r.schools.map((s) => s.id), [1]);
  });

  test('a code with spaces and a hyphen matches however it is typed', () {
    for (final q in ['cmlc bc', 'CMLC-BC', 'cmlcbc']) {
      expect(SchoolMatcher.find(schools, q).schools.map((s) => s.id), [4], reason: q);
    }
  });

  test('a code prefix ranks above a name match', () {
    final r = SchoolMatcher.find(schools, 'hc');
    expect(r.kind, SchoolMatchKind.results);
    expect(r.schools.map((s) => s.id), [1, 2]);
  });

  test('a name needs three characters and may be typed with spaces', () {
    expect(SchoolMatcher.find(schools, 'ho').kind, SchoolMatchKind.none);
    expect(
      SchoolMatcher.find(schools, 'holy child').schools.map((s) => s.id),
      [1],
    );
  });

  test('a two-character code still matches exactly', () {
    expect(SchoolMatcher.find(schools, 'xy').schools.map((s) => s.id), [6]);
  });

  test('no match is reported, and results never exceed the cap', () {
    expect(SchoolMatcher.find(schools, 'zzzz').kind, SchoolMatchKind.none);
    final many = List.generate(12, (i) => _school(i, 'AB$i', 'Alpha $i'));
    expect(SchoolMatcher.find(many, 'alpha').schools.length, SchoolMatcher.maxResults);
  });
}
