import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/api/api_version.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A stand-in school server. It answers /api/mobile/v2/ping like an updated server, or with 404 like
/// one that hasn't been updated, answers everything else with an empty list, and records every
/// request so a test can see exactly which addresses the app used.
class _School {
  _School(this.server);

  final HttpServer server;
  final List<String> requests = []; // "GET /api/mobile/v2/..." (double slashes squeezed)
  final List<String> bodies = [];

  String get domain => 'http://127.0.0.1:${server.port}/';

  static Future<_School> start({required bool speaksV2}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final school = _School(server);
    server.listen((request) async {
      // Some of the app's addresses have a double slash (`host//api/...`), which real web servers
      // treat as one slash but Dart's own server reads as a host name: put the path back together.
      final raw = request.uri.host.isNotEmpty ? '/${request.uri.host}${request.uri.path}' : request.uri.path;
      final path = raw.replaceAll(RegExp('/+'), '/');
      final query = request.uri.hasQuery ? '?${request.uri.query}' : '';
      school.requests.add('${request.method} $path$query');
      school.bodies.add(await utf8.decoder.bind(request).join());
      if (path == '/api/mobile/v2/ping') {
        request.response.statusCode = speaksV2 ? 200 : 404;
        if (speaksV2) request.response.write(jsonEncode({'api': 2}));
      } else {
        request.response.write('[]');
      }
      await request.response.close();
    });
    return school;
  }

  Future<void> stop() => server.close(force: true);

  /// Requests other than the version ping, with the method and path only.
  List<String> get apiCalls =>
      requests.where((r) => !r.contains('/v2/ping')).map((r) => r.split('?').first).toList();
}

Future<void> _useCallApi(_School school) async {
  SharedPreferences.setMockInitialValues({'selectedSchool': school.domain});
  final api = CallApi();
  await api.login('P1132000179', 's3cret');
  await api.getTapHistory(179);
  await api.getEnrollmentInfo(179);
  await api.getV2StudLedger(179, 7, 2);
  await api.getV2ClassSchedule(179, 7, 2);
  await api.getV2ReportCard(179, 7, 2);
  await api.getDeleteToken(179, 9, 'tok');
}

void main() {
  setUp(() => HttpOverrides.global = null); // flutter_test blocks real sockets by default

  test('a v2 server: everything goes to /api/mobile/v2, login is a POST, no password in any URL',
      () async {
    final school = await _School.start(speaksV2: true);
    addTearDown(school.stop);
    await _useCallApi(school);

    expect(await ApiVersion.of(school.domain), 2);
    expect(school.apiCalls, containsAll(<String>[
      'POST /api/mobile/v2/login',
      'GET /api/mobile/v2/api_get_taphistory',
      'GET /api/mobile/v2/api_enrollmentinfo',
      'GET /api/mobile/v2/api_student_ledger_v2',
      'GET /api/mobile/v2/api_class_schedule_v2',
      'GET /api/mobile/v2/api_reportcard_v2',
    ]));
    expect(school.apiCalls.any((c) => c.contains('deleteFcmToken') && c.contains('/v2/')), isTrue);

    // Nothing at all went to a v1 address.
    expect(school.apiCalls.where((c) => !c.contains('/api/mobile/v2/')), isEmpty);
    // The password only ever travelled in the POST body.
    expect(school.requests.where((r) => r.contains('s3cret')), isEmpty);
    expect(school.bodies.any((b) => b.contains('s3cret')), isTrue);
  });

  test('a server that has not been updated: only the original v1 addresses are used', () async {
    final school = await _School.start(speaksV2: false);
    addTearDown(school.stop);
    await _useCallApi(school);

    expect(await ApiVersion.of(school.domain), 1);
    expect(school.apiCalls, containsAll(<String>[
      'GET /api/mobile/api_login', // the only login an old server has
      'GET /api/mobile/api_get_taphistory',
      'GET /api/mobile/api_enrollmentinfo',
      'GET /api/mobile/api_student_ledger_v2',
      'GET /api/mobile/api_class_schedule_v2',
      'GET /api/mobile/api_reportcard_v2',
    ]));
    // Nothing went to a v2 address (apart from the one version ping).
    expect(school.requests.where((r) => r.contains('/v2/') && !r.contains('/v2/ping')), isEmpty);
  });

  test('a server that cannot be reached yet: v1 is used, and nothing is remembered as a guess', () async {
    // Nothing listens on this port.
    final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final domain = 'http://127.0.0.1:${closed.port}/';
    await closed.close(force: true);

    SharedPreferences.setMockInitialValues({'selectedSchool': domain});
    expect(await ApiVersion.of(domain), isNull); // unknown, not "1"
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('api_version_$domain'), isNull);
  });
}
