import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' show max;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pushtrial/api/authed_http.dart' as http;
import 'package:pushtrial/api/api_version.dart';
import 'package:pushtrial/models/login.dart';
import 'package:intl/intl.dart';
import 'package:pushtrial/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// School alerts (student taps IN/OUT and announcements) that reach the phone while the app is
/// closed, without a push service such as Firebase.
///
/// Android cannot wake a closed app from a server without a push service, so the phone asks:
/// - every 30 seconds, a foreground service (on by default; "Real-time tap alerts" in Profile
///   turns it off). Android requires it to show a permanent notification while it runs;
/// - every 15 minutes, a WorkManager job, as a fallback for when the service is off or was
///   stopped (Android may delay it further while the phone is idle);
/// - once whenever the dashboard opens.
///
/// All three run [SchoolAlerts.checkOnce], which asks the school's api_get_alerts for anything
/// newer than what this phone has seen. Android only; iOS would need Apple's push service.
class SchoolAlerts {
  SchoolAlerts._();

  static const String _workName = 'school-alerts-check';
  static const int _serviceId = 4501;
  static const String _realtimeKey = 'alerts_realtime';
  static const Duration realtimeInterval = Duration(seconds: 30);

  /// A phone that was off all day gets a short catch-up, not dozens of notifications.
  static const int _maxPerCheck = 5;

  // Notification ids: one fixed block per kind, so an alert is never shown twice and a message
  // id can't replace a tap or announcement with the same number. (Android ids are 32-bit.)
  static const int _idRange = 400000000;
  static const int _idTap = 0;
  static const int _idAnnouncement = 400000000;
  static const int _idSms = 800000000;
  static const int _idBlast = 1200000000;

  /// Taps and announcements older than this are not popped up as alerts (see [checkOnce]).
  static const Duration maxAlertAge = Duration(hours: 24);

  /// Back-off when the school's server doesn't have the alerts endpoint yet.
  static const Duration _unsupportedBackoff = Duration(hours: 6);

  static bool get supported => !kIsWeb && Platform.isAndroid;

  // ---------------------------------------------------------------------------------------------
  // Scheduling (main isolate)
  // ---------------------------------------------------------------------------------------------

  /// Call once from main(), before runApp.
  static Future<void> initialize() async {
    if (!supported) return;
    await Workmanager().initialize(schoolAlertsWorkDispatcher);
    _initForegroundTask();
  }

  /// Someone is logged in (the dashboard is showing): keep the 15-minute job scheduled, start the
  /// 30-second service unless the parent turned it off, and check straight away.
  static Future<void> onLoggedIn() async {
    if (!supported) return;
    // Each start of the app probes the school's server afresh, so a "no alerts endpoint" flag from
    // an earlier session (e.g. before the school's server was upgraded) never lingers.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('alerts_off_until_${prefs.getInt('selectedSchoolId') ?? 0}');
    await Workmanager().registerPeriodicTask(
      _workName,
      _workName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    // A school whose server has no app alerts yet gets no background service or job: they could
    // only fail, and the permanent "alerts are on" notification would be a lie. (Its parents keep
    // Firebase push instead; see FirebasePush.) The first check below finds out.
    if (await serverHasAlerts() && await isRealtimeOn()) await _startService();
    final result = await checkOnce();
    if (result == unsupported) {
      await Workmanager().cancelByUniqueName(_workName);
      await _stopService();
    } else if (await serverHasAlerts() && await isRealtimeOn()) {
      // The check may have just learned that this school's server now has alerts (it was updated
      // since last time), so the service wasn't started above: start it now.
      await _startService();
    }
  }

  /// Returned by [checkOnce] when the school's server doesn't have the app's alerts endpoint.
  static const int unsupported = -2;

  static String _supportedKey(int school) => 'alerts_supported_$school';

  /// Whether this school's server has app alerts, as last learned. True while still unknown, so a
  /// first sign-in doesn't hold anything back. Firebase push is the other side of this answer.
  static Future<bool> serverHasAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_supportedKey(prefs.getInt('selectedSchoolId') ?? 0)) != false;
  }

  /// Logout: stop all background checking. Remembered positions are per school and student,
  /// so logging back in later never replays old alerts.
  static Future<void> onLoggedOut() async {
    if (!supported) return;
    await Workmanager().cancelByUniqueName(_workName);
    await _stopService();
  }

  /// The parent's choice: on unless they turned it off.
  static Future<bool> isRealtimeOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_realtimeKey) ?? true;
  }

  /// Whether the 30-second service is actually running (it isn't if notifications were refused).
  static Future<bool> isRealtimeRunning() async =>
      supported && await FlutterForegroundTask.isRunningService;

  /// Turns the real-time service on or off. Returns whether it is now running (false if Android
  /// refused to start it, e.g. notifications not allowed).
  static Future<bool> setRealtime(bool on) async {
    if (!supported) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_realtimeKey, on);
    if (!on) {
      await _stopService();
      return false;
    }
    return _startService();
  }

  static void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'school_alerts_service',
        channelName: 'Real-time tap alerts',
        channelDescription:
            'Shown while the app checks for new taps and announcements in the background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(realtimeInterval.inMilliseconds),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> _startService() async {
    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    // A service still running from before an app update keeps its old notification; refresh it.
    final result = await FlutterForegroundTask.isRunningService
        ? await FlutterForegroundTask.updateService(
            notificationTitle: _serviceTitle,
            notificationText: _serviceText,
            notificationIcon: _serviceIcon,
          )
        : await FlutterForegroundTask.startService(
            serviceId: _serviceId,
            notificationTitle: _serviceTitle,
            notificationText: _serviceText,
            notificationIcon: _serviceIcon,
            callback: schoolAlertsServiceCallback,
          );
    return result is ServiceRequestSuccess;
  }

  static const String _serviceTitle = 'Real-time tap alerts are on';
  static const String _serviceText = 'Checking for new taps and announcements';

  /// Same small icon as the other notifications (meta-data in AndroidManifest.xml).
  static const NotificationIcon _serviceIcon = NotificationIcon(
    metaDataName: 'com.ckessentiel.pushtrial.SCHOOL_ALERTS_ICON',
  );

  static Future<void> _stopService() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  // ---------------------------------------------------------------------------------------------
  // The check (runs in the app, the 15-minute job and the real-time service)
  // ---------------------------------------------------------------------------------------------

  static bool _checking = false;

  /// Fetches anything newer than this phone has seen, shows it, and remembers it.
  ///
  /// Returns the number of alerts shown, or -1 if nobody is logged in.
  ///
  /// [initNotifications] must be true in a background isolate; the app's own isolate already
  /// initialises the notifications plugin in main().
  ///
  /// Safe if two isolates check at once: each alert has a fixed notification id (a race shows
  /// it once), and the remembered position only ever moves forward.
  static Future<int> checkOnce({bool initNotifications = false}) async {
    if (_checking) return 0;
    _checking = true;
    try {
      return await _check(initNotifications);
    } catch (e) {
      if (kDebugMode) debugPrint('SchoolAlerts check failed: $e'); // network hiccup: next check retries
      return 0;
    } finally {
      _checking = false;
    }
  }

  static Future<int> _check(bool initNotifications) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // other isolates write the same keys

    final userJson = prefs.getString('user');
    final domain = prefs.getString('selectedSchool');
    if (userJson == null || domain == null || domain.isEmpty) return -1;
    final user = User.fromJson(jsonDecode(userJson));
    final studid = user.id;
    if (studid == 0) return -1;

    final school = prefs.getInt('selectedSchoolId') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final offKey = 'alerts_off_until_$school';
    if ((prefs.getInt(offKey) ?? 0) > now) return unsupported;

    Future<void> recordSupport(bool has) async {
      if (prefs.getBool(_supportedKey(school)) != has) {
        await prefs.setBool(_supportedKey(school), has);
      }
    }

    // The server answered "no such endpoint": remember it, and don't ask again for a while.
    Future<int> markUnsupported() async {
      await recordSupport(false);
      await prefs.setInt(offKey, now + _unsupportedBackoff.inMilliseconds);
      return unsupported;
    }

    // Alerts are part of API v2. A school whose server hasn't been updated speaks only v1, so there
    // is nothing to ask it (and Firebase push stays on for it, see FirebasePush). If the version
    // can't be learned yet (offline, never answered) nothing changes: try again next time.
    final version = await ApiVersion.of(domain);
    if (version == null) return 0;
    await recordSupport(version == 2);
    if (version != 2) return unsupported;

    // 9 = parent login (messages sent to father/mother/guardian numbers), else the student's own.
    final loginJson = prefs.getString('userlogin');
    final loginType = loginJson == null ? 7 : Login.fromJson(jsonDecode(loginJson)).type;

    final tapKey = 'alerts_tap_${school}_$studid';
    // Announcements are followed by their row in the server's notifications table (a short range
    // read for the server), not by announcement id (which made it scan every notification).
    final notifKey = 'alerts_notif_${school}_$studid';
    final smsKey = 'alerts_sms_${school}_$studid';
    final blastKey = 'alerts_blast_${school}_$studid';
    final base = '${domain.endsWith('/') ? domain : '$domain/'}api/mobile/v2/alerts'
        '?studid=$studid&type=$loginType';

    final tapSeen = prefs.getInt(tapKey);
    final notifSeen = prefs.getInt(notifKey);
    final smsSeen = prefs.getInt(smsKey);
    final blastSeen = prefs.getInt(blastKey);

    if (tapSeen == null || notifSeen == null || smsSeen == null || blastSeen == null) {
      // First time for this student on this phone (or a position added by an app update):
      // remember where things are, announce nothing. A school server that doesn't know about
      // messages yet leaves their positions unset, so it is asked again after it is upgraded.
      final body = await _get('$base&latest=1');
      if (body == null) return 0;
      if (body['success'] == false) return markUnsupported();
      if (body['success'] != true) return 0;
      await recordSupport(true);
      final starts = {
        tapKey: body['latest_tap_id'],
        notifKey: body['latest_notification_id'],
        smsKey: body['latest_sms_id'],
        blastKey: body['latest_blast_id'],
      };
      for (final entry in starts.entries) {
        if (entry.value != null && prefs.getInt(entry.key) == null) {
          await prefs.setInt(entry.key, _int(entry.value));
        }
      }
      return 0;
    }

    final body = await _get('$base&after_tap=$tapSeen&after_notification=$notifSeen'
        '&after_sms=$smsSeen&after_blast=$blastSeen');
    if (body == null) return 0;
    if (body['success'] == false) return markUnsupported();
    if (body['success'] != true || body['taps'] is! List || body['announcements'] is! List) {
      return 0; // a reply we can't use: try again next time, don't switch anything off
    }
    await recordSupport(true);

    // Never announce something already seen, whatever the server sent back.
    final taps = (body['taps'] as List)
        .whereType<Map>()
        .where((t) => _int(t['id']) > tapSeen)
        .toList();
    // Announcements are already only the ones after our position in the server's notifications.
    final announcements = (body['announcements'] as List).whereType<Map>().toList();
    // SMS and text blasts sent to this person's number (older servers send no messages).
    final smsMessages = <Map>[];
    final blastMessages = <Map>[];
    if (body['messages'] is List) {
      for (final m in (body['messages'] as List).whereType<Map>()) {
        final isBlast = m['source'] == 'blast';
        if (_int(m['id']) > (isBlast ? blastSeen : smsSeen)) {
          (isBlast ? blastMessages : smsMessages).add(m);
        }
      }
    }
    final messages = [...smsMessages, ...blastMessages];

    // How far the server looked, even when nothing matched this person, so the next check
    // doesn't re-read other people's messages. Only ever moves forward.
    Future<void> moveMessageCursors() async {
      await prefs.reload();
      final reported = body['message_cursors'];
      int reportedFor(String name) => reported is Map ? _int(reported[name]) : 0;
      final newest = {
        smsKey: max(smsMessages.isEmpty ? 0 : _int(smsMessages.last['id']), reportedFor('sms')),
        blastKey:
            max(blastMessages.isEmpty ? 0 : _int(blastMessages.last['id']), reportedFor('blast')),
        notifKey: reportedFor('notification'),
      };
      for (final entry in newest.entries) {
        if (entry.value > (prefs.getInt(entry.key) ?? 0)) {
          await prefs.setInt(entry.key, entry.value);
        }
      }
    }

    if (taps.isEmpty && announcements.isEmpty && messages.isEmpty) {
      await moveMessageCursors();
      return 0;
    }

    // Anything older than a day is marked as seen below but never popped up: a tap from last week
    // arriving as an alert today (e.g. the parent's phone was off) would read as "just now".
    // It still appears in the app's history (Tap history, Notifications).
    // The server says how old each item is on its own clock (age_seconds), so the phone's clock and
    // timezone don't matter. Only a server that doesn't send it falls back to the phone's clock.
    final cutoff = DateTime.now().subtract(maxAlertAge);
    bool fresh(Map item, Object? date, Object? time) {
      final age = item['age_seconds'];
      return age is num ? age < maxAlertAge.inSeconds : _isFresh(date, time, cutoff);
    }

    final freshTaps = taps.where((t) => fresh(t, t['tdate'], t['ttime'])).toList();
    final freshAnnouncements =
        announcements.where((a) => fresh(a, a['created_at'], null)).toList();
    final freshMessages = messages.where((m) => fresh(m, m['created_at'], null)).toList();

    final plugin = await _notifications(initNotifications);
    final firstName = (user.firstname ?? '').trim();
    var shown = 0;

    for (final tap in _lastFew(freshTaps)) {
      final id = _int(tap['id']);
      await plugin.show(
        _idTap + id % _idRange,
        'School tap',
        describeTap(tap, firstName),
        _details(null),
        payload: jsonEncode({'type': 'tap', 'id': id}),
      );
      shown++;
    }
    for (final announcement in _lastFew(freshAnnouncements)) {
      final id = _int(announcement['id']);
      final title = (announcement['title'] ?? '').toString().trim();
      final message = (announcement['message'] ?? '').toString().trim();
      await plugin.show(
        _idAnnouncement + id % _idRange,
        title.isEmpty ? 'School announcement' : title,
        message,
        _details(message),
        payload: jsonEncode({'type': 'announcement', 'id': id}),
      );
      shown++;
    }
    for (final m in _lastFew(freshMessages)) {
      final id = _int(m['id']);
      final isBlast = m['source'] == 'blast';
      final message = (m['message'] ?? '').toString().trim();
      await plugin.show(
        (isBlast ? _idBlast : _idSms) + id % _idRange,
        'School message',
        message,
        _details(message),
        payload: jsonEncode({'type': 'message', 'id': id}),
      );
      shown++;
    }

    // Move forward only: another isolate may already have moved further.
    await moveMessageCursors();
    if (taps.isNotEmpty) {
      await prefs.setInt(tapKey, max(prefs.getInt(tapKey) ?? 0, _int(taps.last['id'])));
    }
    return shown;
  }

  /// "JENNYBABE entered the school at 7:45 AM" (or "... at 4:30 PM on Oct 27" for an older tap).
  @visibleForTesting
  static String describeTap(Map tap, String firstName) {
    final name = firstName.isEmpty ? 'Your child' : firstName;
    final out = (tap['tapstate'] ?? '').toString().toUpperCase() == 'OUT';
    final action = out ? 'left the school' : 'entered the school';
    var when = (tap['ttime'] ?? '').toString();
    try {
      when = DateFormat('h:mm a').format(DateFormat('HH:mm:ss').parse(when));
    } catch (_) {}
    final date = DateTime.tryParse((tap['tdate'] ?? '').toString());
    final today = DateTime.now();
    final isToday = date != null &&
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final onDay = (date == null || isToday) ? '' : ' on ${DateFormat('MMM d').format(date)}';
    return '$name $action at $when$onDay';
  }

  /// True when the date (and optional time) is newer than [cutoff]. A value that can't be read is
  /// treated as fresh, so a format surprise never silently drops an alert.
  static bool _isFresh(Object? date, Object? time, DateTime cutoff) {
    final text = '${date ?? ''} ${time ?? ''}'.trim();
    final when = DateTime.tryParse(text);
    return when == null || when.isAfter(cutoff);
  }

  static List<Map> _lastFew(List<Map> items) =>
      items.length > _maxPerCheck ? items.sublist(items.length - _maxPerCheck) : items;

  static int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

  /// Returns the decoded JSON object; {'success': false} only when the school's server has no such
  /// endpoint (404/405: an older server); and null for everything else that goes wrong (no
  /// connection, a server error, a reply that isn't JSON), so the next check simply tries again.
  ///
  /// Only "the endpoint isn't there" may switch alerts off for hours. A one-off server error must
  /// never silence a phone.
  static Future<Map<String, dynamic>?> _get(String url) async {
    final http.Response response;
    try {
      response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    }
    if (response.statusCode == 404 || response.statusCode == 405) return {'success': false};
    if (response.statusCode != 200) return null;
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _pluginReady = false;

  static Future<FlutterLocalNotificationsPlugin> _notifications(bool init) async {
    if (init && !_pluginReady) {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/app_icon'),
        ),
      );
    }
    _pluginReady = true;
    return _plugin;
  }

  static NotificationDetails _details(String? bigText) => NotificationDetails(
        android: AndroidNotificationDetails(
          'school_alerts',
          'School alerts',
          channelDescription: 'Student taps and school announcements',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: bigText == null ? null : BigTextStyleInformation(bigText),
        ),
      );
}

/// WorkManager entry point (the 15-minute check), run in a background isolate.
@pragma('vm:entry-point')
void schoolAlertsWorkDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    await SchoolAlerts.checkOnce(initNotifications: true);
    return true; // never ask WorkManager to retry; the next period checks again
  });
}

/// Foreground-service entry point (real-time mode), run in the service's isolate.
@pragma('vm:entry-point')
void schoolAlertsServiceCallback() {
  FlutterForegroundTask.setTaskHandler(_RealtimeAlertsHandler());
}

class _RealtimeAlertsHandler extends TaskHandler {
  Future<void> _run() async {
    final shown = await SchoolAlerts.checkOnce(initNotifications: true);
    if (shown < 0) {
      // Logged out (e.g. the service was restarted after a reboot): nothing to watch.
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    DartPluginRegistrant.ensureInitialized();
    await _run();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _run();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
