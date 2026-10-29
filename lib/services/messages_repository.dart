import 'dart:convert';

import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/api/api_version.dart';
import 'package:pushtrial/models/school_message.dart';

/// Loads what the Notifications page and the Home bell show, from whichever server the school has.
///
/// A school whose server has the app's messages endpoint (`api_get_messages`) gets the full list:
/// SMS, tap texts, text blasts and announcements, with ages measured on the school's clock. A server
/// that hasn't been updated yet (it answers 404/405) is read the way earlier versions of the app did,
/// through `api_get_smsbunker`, so nothing breaks there. Read state is kept on the phone either way
/// (see MessageReadStore); nothing is ever written to the school's server.
class MessagesRepository {
  MessagesRepository._();

  /// The messages, or null when they could not be loaded (no connection, a server error).
  static Future<List<SchoolMessage>?> load(int studid, int type) async {
    try {
      // Which API the school's server has decides the source: v2 has the messages endpoint, v1
      // only the older SMS one. (Not yet known, e.g. offline: nothing to show yet.)
      final version = await ApiVersion.forSavedSchool();
      if (version == null) return null;
      if (version != 2) return await _loadFromOlderServer(studid, type);

      final response = await CallApi().getMessages(studid, type);
      if (response.statusCode == 404 || response.statusCode == 405) {
        return await _loadFromOlderServer(studid, type); // v2 ping answered but this didn't: be safe
      }
      if (response.statusCode != 200 || response.body.isEmpty) return null;
      final data = jsonDecode(response.body);
      if (data is! Map || data['messages'] is! List) return null;
      return (data['messages'] as List)
          .whereType<Map>()
          .map((m) => SchoolMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// The older endpoint, as earlier app versions used it: for a student their own number's
  /// messages, for a parent the father/mother/guardian numbers' messages and tap texts. As before,
  /// only messages the school's push job flagged (1 or 2) are listed, and anything that looks like
  /// portal credentials is left out.
  static Future<List<SchoolMessage>?> _loadFromOlderServer(int studid, int type) async {
    final response = await CallApi().getSmsBunker(studid);
    if (response.statusCode != 200 || response.body.isEmpty) return null;
    final data = jsonDecode(response.body);
    if (data is! Map) return null;

    final groups = type == 9
        ? {
            'sms': 'smsbunkerparents',
            'tap': 'tapbunkerparents',
            'blast': 'smsbunkertextblastsparents',
          }
        : {
            'sms': 'smsbunkerstudent',
            'blast': 'smsbunkertextblaststudent',
          };

    int asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
    final credential = RegExp('password|pword|username|credential', caseSensitive: false);
    final out = <SchoolMessage>[];
    groups.forEach((source, key) {
      final rows = data[key] is List ? data[key] as List : const [];
      for (final row in rows.whereType<Map>()) {
        final pushstatus = asInt(row['pushstatus']);
        final text = '${row['message'] ?? ''}'.trim();
        if ((pushstatus != 1 && pushstatus != 2) || text.isEmpty || credential.hasMatch(text)) {
          continue;
        }
        out.add(SchoolMessage(
          source: source,
          id: asInt(row['id']),
          message: text,
          createdAt: DateTime.tryParse('${row['createddatetime'] ?? ''}'),
        ));
      }
    });
    return out;
  }
}
