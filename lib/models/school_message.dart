import 'package:pushtrial/services/school_alerts.dart';

/// One message for the Notifications page: an SMS, tap SMS or text blast the school sent to this
/// person's phone number (from `api_get_messages`).
class SchoolMessage {
  SchoolMessage({
    required this.source,
    required this.id,
    required this.message,
    required this.createdAt,
    this.title = '',
    this.ageSeconds,
  }) : fetchedAt = DateTime.now();

  /// `sms`, `tap`, `blast` or `announcement`. Ids are only unique within a source.
  final String source;
  final int id;
  final String message;

  /// Announcements have a title; SMS don't.
  final String title;

  /// How old the server says this was when it was fetched, measured on the school's own clock so
  /// the phone's clock and timezone don't matter. Null from a server that doesn't send it.
  final int? ageSeconds;
  final DateTime fetchedAt;
  final DateTime? createdAt;

  /// Read on this phone (see MessageReadStore). The school's own `pushstatus` is not used: it
  /// belongs to the school's push job, and the app never changes it.
  bool read = false;

  /// Stable key for lists and the read store: ids repeat across sources.
  String get key => '$source-$id';

  bool get isRead => read;

  /// Newer than [SchoolAlerts.maxAlertAge]: the same window in which an alert is popped up. Older
  /// messages stay in the list as history but are never counted or shown as unread. Unread also
  /// means not yet read on this phone.
  bool get isNew {
    final age = ageSeconds;
    if (age != null) {
      // Age at fetch time plus the time since, so it keeps ageing while the page stays open.
      final now = age + DateTime.now().difference(fetchedAt).inSeconds;
      return now < SchoolAlerts.maxAlertAge.inSeconds;
    }
    return createdAt != null &&
        createdAt!.isAfter(DateTime.now().subtract(SchoolAlerts.maxAlertAge));
  }

  bool get isUnread => isNew && !isRead;

  factory SchoolMessage.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
    return SchoolMessage(
      source: '${json['source'] ?? 'sms'}',
      id: asInt(json['id']),
      message: '${json['message'] ?? ''}'.trim(),
      title: '${json['title'] ?? ''}'.trim(),
      ageSeconds: json['age_seconds'] is num ? (json['age_seconds'] as num).toInt() : null,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}
