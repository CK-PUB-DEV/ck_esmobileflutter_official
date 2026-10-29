import 'package:http/http.dart' as raw;
import 'package:pushtrial/api/auth_token.dart';

export 'package:http/http.dart' show Response, StreamedResponse, MultipartFile;

/// A drop-in for `package:http` that adds the v2 sign-in token to the requests that need it, so
/// the many call sites don't each have to. Anything addressed to a v1 server (or to the v2
/// endpoints that work before signing in) goes out exactly as before.
///
/// An answer of 401 to a request that carried the token means it is no longer good (expired, the
/// password was changed): the token is forgotten and the app is told to show the sign-in screen.

Future<raw.Response> get(Uri url, {Map<String, String>? headers}) async {
  await AuthToken.ensureLoaded();
  final response = await raw.get(url, headers: _merge(url, headers));
  await _checkRejected(url, response.statusCode);
  return response;
}

Future<raw.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
  await AuthToken.ensureLoaded();
  final response = await raw.post(url, headers: _merge(url, headers), body: body);
  await _checkRejected(url, response.statusCode);
  return response;
}

/// A multipart upload; the token is added when it is created, so call
/// `AuthToken.ensureLoaded()` before (every API call already does).
class MultipartRequest extends raw.MultipartRequest {
  MultipartRequest(super.method, super.url) {
    headers.addAll(AuthToken.headersFor(url));
  }

  @override
  Future<raw.StreamedResponse> send() async {
    final response = await super.send();
    await _checkRejected(url, response.statusCode);
    return response;
  }
}

Map<String, String> _merge(Uri url, Map<String, String>? headers) =>
    {...AuthToken.headersFor(url), ...?headers};

Future<void> _checkRejected(Uri url, int status) async {
  // Also when there was no token to send: a phone that was signed in before the app learned to
  // keep one has to sign in again.
  if (status == 401 && AuthToken.needsToken(url)) {
    await AuthToken.reject();
  }
}
