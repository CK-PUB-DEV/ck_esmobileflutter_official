import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Which version of the mobile API a school's server speaks.
///
/// v1 (`/api/mobile/*`) is what every server has had. v2 (`/api/mobile/v2/*`) adds the app's own
/// alerts, a safer login and the messages list. A server that has been updated answers
/// `/api/mobile/v2/ping`; one that hasn't answers 404, and the app keeps using v1 there, exactly as
/// earlier app versions did. Both versions run side by side on an updated server, so older apps
/// keep working too.
///
/// Asked once per school per run. If the server can't be reached the answer from last time is used,
/// and if there is none the result is unknown (null) and nothing is switched on or off.
class ApiVersion {
  ApiVersion._();

  static final Map<String, Future<int?>> _asked = {};

  /// 2 when the school's server has the v2 API, 1 when it doesn't, null when that can't be
  /// determined yet (offline, and never answered before).
  static Future<int?> of(String domain) {
    return _asked.putIfAbsent(domain, () => _detect(domain));
  }

  /// The same for the school this phone has chosen (null when none is chosen yet).
  static Future<int?> forSavedSchool() async {
    final prefs = await SharedPreferences.getInstance();
    final domain = prefs.getString('selectedSchool');
    if (domain == null || domain.isEmpty) return null;
    return of(domain);
  }

  /// The version learned for [domain] earlier (this run or an earlier one), without any request.
  static Future<int?> lastKnown(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_hintKey(domain));
  }

  static String _hintKey(String domain) => 'api_version_$domain';
  static String _ledgerKey(String domain) => 'ledger_layout_$domain';

  /// Which billing screen to open: 'v2' (fees by category + monthly) or 'v1' (flat ledger).
  /// A v2 server says which layout its data really is in; otherwise the school list's flag decides.
  static Future<String> billingVersion() async {
    await forSavedSchool();
    final prefs = await SharedPreferences.getInstance();
    final domain = prefs.getString('selectedSchool');
    final layout = domain == null ? null : prefs.getString(_ledgerKey(domain));
    return layout ?? prefs.getString('schoolVersion') ?? 'v1';
  }

  static Future<int?> _detect(String domain) async {
    final prefs = await SharedPreferences.getInstance();
    final base = domain.endsWith('/') ? domain : '$domain/';
    try {
      final response = await http
          .get(Uri.parse('${base}api/mobile/v2/ping'))
          .timeout(const Duration(seconds: 8));
      var version = 1;
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['api'] == 2) {
            version = 2;
            final layout = data['ledger'];
            if (layout == 'v1' || layout == 'v2') {
              await prefs.setString(_ledgerKey(domain), layout as String);
            }
          }
        } catch (_) {
          // A 200 that isn't our ping (an unrelated page): not v2.
        }
      }
      await prefs.setInt(_hintKey(domain), version);
      return version;
    } catch (_) {
      // No connection. Ask again next time rather than remembering a guess.
      _asked.remove(domain);
      return prefs.getInt(_hintKey(domain));
    }
  }
}
