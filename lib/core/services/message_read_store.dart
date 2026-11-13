import 'package:pushtrial/models/school_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which school messages this phone has read.
///
/// Read state lives only on the phone, per school and student, and never touches the school's
/// database (the SMS tables' own `pushstatus` belongs to the school's push job and is ignored).
/// Logging out and in again keeps it; reinstalling the app clears it.
class MessageReadStore {
  MessageReadStore._();

  /// Keeps the newest this many entries so the stored list can't grow forever. Messages are only
  /// listed for 30 days, so older entries are never needed.
  static const int _maxEntries = 500;

  static Future<String> _key(SharedPreferences prefs, int studid) async {
    final school = prefs.getInt('selectedSchoolId') ?? 0;
    return 'msg_read_${school}_$studid';
  }

  /// Marks [messages] that this phone has already read, in place.
  static Future<void> apply(List<SchoolMessage> messages, int studid) async {
    final prefs = await SharedPreferences.getInstance();
    final read = (prefs.getStringList(await _key(prefs, studid)) ?? const <String>[]).toSet();
    for (final m in messages) {
      m.read = read.contains(m.key);
    }
  }

  /// Remembers that these messages were read.
  static Future<void> markRead(Iterable<SchoolMessage> messages, int studid) async {
    final keys = messages.where((m) => !m.read).map((m) => m.key).toList();
    for (final m in messages) {
      m.read = true;
    }
    if (keys.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = await _key(prefs, studid);
    final stored = prefs.getStringList(key) ?? <String>[];
    stored.addAll(keys.where((k) => !stored.contains(k)));
    final trimmed =
        stored.length > _maxEntries ? stored.sublist(stored.length - _maxEntries) : stored;
    await prefs.setStringList(key, trimmed);
  }
}
