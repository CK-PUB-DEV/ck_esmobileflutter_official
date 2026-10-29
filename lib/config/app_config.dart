import 'package:flutter/foundation.dart';

/// Build-time switches. Nothing here changes behaviour unless a flag is passed explicitly.
class AppConfig {
  AppConfig._();

  /// Testing / debugging mode.
  ///
  /// Off (the default): the school picker loads its list from the school server,
  /// `SchoolApi().getSchoolList()`.
  ///
  /// On: it uses [testSchoolsJson] instead, so a test build can point a school at a local backend
  /// without touching code. The list is passed in at build time and is NOT part of the app's
  /// assets, so it can't end up inside a release bundle (it holds private addresses):
  ///
  ///   dart run tool/make_test_defines.dart
  ///   flutter run --dart-define-from-file=tool/test_schools.define.json
  ///
  /// It is ignored in release builds (`kReleaseMode`) even if passed by mistake.
  static const String testSchoolsJson = String.fromEnvironment('TEST_SCHOOLS_JSON');
  static const bool useTestSchools = !kReleaseMode && testSchoolsJson != '';

  /// Release builds talk to schools over HTTPS only: an `http://` school address is upgraded to
  /// `https://`. (Dart's own network stack ignores Android's cleartext setting, so the app has to
  /// enforce this itself.) Debug and profile builds keep `http://`, so a local test backend works.
  /// A release can opt out with `--dart-define=ALLOW_HTTP=true`.
  static const bool allowHttp = !kReleaseMode || bool.fromEnvironment('ALLOW_HTTP');

  static String secureUrl(String url) => allowHttp
      ? url
      : url.replaceFirst(RegExp(r'^http://', caseSensitive: false), 'https://');

  /// Firebase Cloud Messaging push, per school.
  ///
  /// `auto` (the default): decided by the school's server. A server that has the app's own alerts
  /// (api_get_alerts) gets them, with Firebase off: no push token, no FCM listeners, and any token
  /// an earlier version left is removed, so a parent never gets one event twice. A server that
  /// doesn't have them yet keeps Firebase push exactly as before, so schools that haven't updated
  /// their server lose nothing. When such a server is updated the app switches over by itself.
  /// See FirebasePush.
  ///
  /// `on`: always Firebase, whatever the server supports. `off`: never Firebase. Per build:
  ///
  ///   flutter run --dart-define=FIREBASE_PUSH=on
  static const String firebasePushMode = String.fromEnvironment(
    'FIREBASE_PUSH',
    defaultValue: 'auto',
  );
}
