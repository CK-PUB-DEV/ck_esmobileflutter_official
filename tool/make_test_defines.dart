// Builds tool/test_schools.define.json from tool/test_schools.json, for test runs:
//
//   dart run tool/make_test_defines.dart
//   flutter run --dart-define-from-file=tool/test_schools.define.json
//
// The school list reaches the app as a compile-time value, not as a bundled asset, so a release
// build (which never gets this file) can't contain it. Edit tool/test_schools.json to point a
// school at a local backend, then run this again.
import 'dart:convert';
import 'dart:io';

void main() {
  final source = File('tool/test_schools.json');
  if (!source.existsSync()) {
    stderr.writeln('tool/test_schools.json not found. Run this from the project root.');
    exit(1);
  }
  final schools = jsonDecode(source.readAsStringSync()); // fails early on invalid JSON
  final out = File('tool/test_schools.define.json');
  out.writeAsStringSync(jsonEncode({'TEST_SCHOOLS_JSON': jsonEncode(schools)}));
  stdout.writeln('Wrote ${out.path} (${(schools as List).length} schools).');
}
