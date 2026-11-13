import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The sign-in token a v2 school server gives at login (see ApiVersion for what v2 is).
///
/// Kept in the phone's secure storage (Android Keystore), not in the ordinary preferences, and
/// sent with every v2 request except the ones that must work before signing in. A v1 server has no
/// token and this stays empty.
class AuthToken {
  AuthToken._();

  static const _key = 'mobile_v2_token';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String? _token;
  static bool _loaded = false;

  /// Called (once per sign-out) when a server says the token is no longer good: expired, the
  /// password was changed, or the account was removed. The app uses it to show the sign-in screen.
  static Future<void> Function()? onRejected;
  static bool _rejecting = false;

  /// The token held in memory; null until [ensureLoaded] ran or when signed out.
  static String? get current => _token;

  /// Reads the stored token once. Safe to call from a background isolate too.
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      _token = await _storage.read(key: _key);
    } catch (e) {
      // A secure storage that can't be read (a restored backup, a changed lock screen) is the
      // same as no token: the person signs in again.
      if (kDebugMode) debugPrint('AuthToken: could not read the stored token: $e');
      _token = null;
    }
    _loaded = true;
  }

  static Future<void> save(String token) async {
    _token = token;
    _loaded = true;
    _rejecting = false;
    try {
      await _storage.write(key: _key, value: token);
    } catch (e) {
      if (kDebugMode) debugPrint('AuthToken: could not store the token: $e');
    }
  }

  static Future<void> clear() async {
    _token = null;
    _loaded = true;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }

  /// A request that carried the token was answered 401: forget it and let the app ask again.
  static Future<void> reject() async {
    await clear();
    if (_rejecting) return;
    _rejecting = true;
    final callback = onRejected;
    if (callback != null) await callback();
  }

  /// The headers a request to [url] needs. Empty for v1 addresses and for the v2 ones that work
  /// without signing in.
  static Map<String, String> headersFor(Uri url) {
    final token = _token;
    if (token == null || !needsToken(url)) return const {};
    return {'Authorization': 'Bearer $token', 'X-Mobile-Token': token};
  }

  static bool needsToken(Uri url) {
    final path = url.path;
    if (!path.contains('/api/mobile/v2/')) return false;
    final endpoint = path.substring(path.indexOf('/api/mobile/v2/') + '/api/mobile/v2/'.length);
    return endpoint != 'ping' && endpoint != 'login' && endpoint != 'schoolinfo';
  }
}
