import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/config/app_config.dart';
import 'package:pushtrial/firebase_options.dart';
import 'package:pushtrial/main.dart' show navigatorKey, showNotification;
import 'package:pushtrial/models/login.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/push_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase push, used only where it is still needed.
///
/// The app has its own alerts (SchoolAlerts) that need the school's server to have `api_get_alerts`.
/// Where it does, Firebase push is switched off, because running both shows every event twice:
/// once from the school's push job and once from the app. Where it doesn't (a school that hasn't
/// updated its server), the app keeps working exactly as before, with Firebase push.
///
/// Which one applies is learned from the server (SchoolAlerts records `alerts_supported_<school>`)
/// and reconciled each time someone signs in, so a school that updates its server later is switched
/// over without anyone doing anything, and a school that is rolled back is switched back.
class FirebasePush {
  FirebasePush._();

  /// True while Firebase push is running in this process (so logout knows there is a token).
  static bool get isActive => _active;
  static bool _active = false;
  static bool _listening = false;
  static String? _tokenSavedFor;

  static String _removedKey(int school) => 'firebase_push_removed_$school';
  static const String _legacyNeededKey = 'push_legacy_needed';

  // ---------------------------------------------------------------- start-up

  /// Called once at start-up. Brings Firebase up straight away when this phone's last school needed
  /// it (or the build forces it), so messages that arrive while the app is closed still work.
  static Future<void> startup() async {
    if (kIsWeb || AppConfig.firebasePushMode == 'off') return;
    final prefs = await SharedPreferences.getInstance();
    final needed = AppConfig.firebasePushMode == 'on' || (prefs.getBool(_legacyNeededKey) ?? false);
    if (!needed) return;
    await _activate(askPermission: true, handleLaunchMessage: true);

    // As before, each start refreshes the token on the school's server (tokens change over time),
    // but only for someone who is signed in.
    if (prefs.getString('user') != null) {
      await PushNotifications.getUser();
      await PushNotifications.getLogin();
      unawaited(PushNotifications.getFCMToken());
    }
  }

  // --------------------------------------------------------------- reconcile

  /// Called after sign-in, once SchoolAlerts has learned whether this school's server has alerts.
  static Future<void> reconcile() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final school = prefs.getInt('selectedSchoolId') ?? 0;
      final mode = AppConfig.firebasePushMode;
      final supported = prefs.getBool('alerts_supported_$school'); // null = not known yet

      if (mode == 'on' || (mode == 'auto' && supported == false)) {
        await _useFirebase(prefs, school);
      } else if (mode == 'off' || (mode == 'auto' && supported == true)) {
        await _removeFirebase(prefs, school);
      }
      // Unknown (e.g. offline at sign-in): leave things as they are and decide next time.
    } catch (e) {
      if (kDebugMode) debugPrint('FirebasePush reconcile will retry: $e');
    }
  }

  /// This school's server has no app alerts: Firebase push as before.
  static Future<void> _useFirebase(SharedPreferences prefs, int school) async {
    await prefs.setBool(_legacyNeededKey, true);
    await prefs.remove(_removedKey(school));
    await _activate(askPermission: true, handleLaunchMessage: false);

    final userJson = prefs.getString('user');
    final loginJson = prefs.getString('userlogin');
    if (userJson == null || loginJson == null) return;
    final key = '$school|${User.fromJson(jsonDecode(userJson)).id}';
    if (_tokenSavedFor == key) return; // already registered in this session
    await PushNotifications.getUser();
    await PushNotifications.getLogin();
    await PushNotifications.getFCMToken(); // gets the token and saves it on the school's server
    _tokenSavedFor = key;
  }

  /// This school's server has app alerts: Firebase push off, token forgotten on both sides. Done once
  /// per school; if the phone is offline it is simply tried again next time.
  static Future<void> _removeFirebase(SharedPreferences prefs, int school) async {
    await prefs.setBool(_legacyNeededKey, false);
    if (prefs.getBool(_removedKey(school)) == true) return;
    if (!_active && Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();

    // The server's copy first, while there is still a token to name it by.
    final userJson = prefs.getString('user');
    final loginJson = prefs.getString('userlogin');
    if (token != null && userJson != null && loginJson != null) {
      final user = User.fromJson(jsonDecode(userJson));
      final login = Login.fromJson(jsonDecode(loginJson));
      final response = await CallApi().getDeleteToken(user.id, login.type, token);
      if (response.statusCode != 200) return; // try again next time
    }
    await messaging.deleteToken();
    await messaging.setAutoInitEnabled(false);
    _active = false;
    _tokenSavedFor = null;
    await prefs.setBool(_removedKey(school), true);
  }

  // ------------------------------------------------------------------ logout

  /// On sign-out: forget this phone's token on the school's server if Firebase push was in use.
  static Future<void> onLoggedOut(int studid, int type) async {
    if (!_active) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await CallApi().getDeleteToken(studid, type, token);
    } catch (_) {
      // Signing out still goes ahead if the token endpoint is unavailable.
    }
    _tokenSavedFor = null;
  }

  // ---------------------------------------------------------------- internals

  static Future<void> _activate({
    required bool askPermission,
    required bool handleLaunchMessage,
  }) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);
    _active = true;

    if (!_listening) {
      _listening = true;
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (message.notification != null) {
          navigatorKey.currentState?.pushNamed('/notifications', arguments: message);
        }
      });
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification == null) return;
        if (kIsWeb) {
          showNotification(
            title: message.notification!.title!,
            body: message.notification!.body!,
          );
        } else {
          PushNotifications.showSimpleNotification(
            title: message.notification!.title!,
            body: message.notification!.body!,
            payload: jsonEncode(message.data),
          );
        }
      });
    }

    if (askPermission) {
      await messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    }

    if (handleLaunchMessage) {
      final RemoteMessage? launch = await messaging.getInitialMessage();
      if (launch != null) {
        Future.delayed(const Duration(seconds: 1), () {
          navigatorKey.currentState?.pushNamed('/notifications', arguments: launch);
        });
      }
    }
  }
}

/// Runs in its own isolate when a push arrives with the app closed.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.notification != null) {
    await PushNotifications.showSimpleNotification(
      title: message.notification!.title!,
      body: message.notification!.body!,
      payload: jsonEncode(message.data),
    );
  }
}
