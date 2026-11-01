import 'dart:convert';

import 'package:pushtrial/api/api.dart';

/// Whether one student service (teacher evaluation, clearance, scholarship) can be used at the
/// selected school, as its v2 server reports it.
enum ServiceState {
  /// The school uses it and the app supports it.
  available,

  /// The school doesn't use it.
  notUsed,

  /// The school uses it on the web portal, but the app can't show it yet.
  comingSoon,

  /// The school's server can't say (not updated yet, or offline).
  unknown,
}

class StudentServices {
  StudentServices._(this._states);

  final Map<String, ServiceState> _states;

  ServiceState operator [](String key) => _states[key] ?? ServiceState.unknown;

  static final StudentServices _unknown = StudentServices._(const {});

  /// Asks the school's server. Never throws: anything unexpected is [ServiceState.unknown].
  static Future<StudentServices> load() async {
    try {
      final response = await CallApi().getStudentServices();
      if (response == null || response.statusCode != 200) return _unknown;
      final body = json.decode(response.body);
      if (body is! Map) return _unknown;
      final states = <String, ServiceState>{};
      body.forEach((key, value) {
        if (value is! Map) return;
        states['$key'] = value['available'] == true
            ? ServiceState.available
            : value['reason'] == 'coming_soon'
                ? ServiceState.comingSoon
                : ServiceState.notUsed;
      });
      return StudentServices._(states);
    } catch (_) {
      return _unknown;
    }
  }
}
