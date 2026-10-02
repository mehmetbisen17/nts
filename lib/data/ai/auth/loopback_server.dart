import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:nts/data/ai/ai_provider.dart';

/// A one-time HTTP server on 127.0.0.1 and ::1 that waits for an OAuth
/// redirect (RFC 8252 loopback redirect), checks its `state`, answers the
/// browser and closes. Also closes after [start]'s timeout or [close].
class LoopbackServer {
  new _(this._servers, this.port, this.path, this._state, this._doneRedirect) {
    // A cancelled sign-in nobody awaits isn't an uncaught error
    _result.future.ignore();
  }

  static final log = Logger('LoopbackServer');

  final List<HttpServer> _servers;
  final int port;
  final String path;
  final String _state;
  final Uri? _doneRedirect;
  final _result = Completer<Map<String, String>>();
  Timer? _timeout;

  /// The `redirect_uri` to send with the authorization request.
  String get redirectUri => 'http://localhost:$port$path';

  /// The callback's query parameters (e.g. `code`), once it arrives with the
  /// right [state]. Throws [AiError]: DENIED if the user declined, CANCELLED
  /// on timeout or [close], FAILED on another OAuth error. A callback with
  /// the wrong state (not this sign-in's, e.g. a web page loading the URL)
  /// is refused and the real one still awaited.
  Future<Map<String, String>> get result => _result.future;

  static const _addressInUse = {48, 98, 10048}; // macOS/iOS, Linux, Windows

  static const _interrupted = AiError(
    AiError.failed,
    'Sign-in was interrupted. Try again, or use a code instead.',
  );

  /// Listens on the first free port of [ports], on both loopback addresses
  /// (browsers may resolve "localhost" to either).
  ///
  /// With [doneRedirect] (e.g. `nts-auth://done`) the browser is sent there
  /// afterwards, which closes a flutter_web_auth_2 sheet listening for that
  /// scheme; otherwise it shows a "You can close this window" page.
  static Future<LoopbackServer> start({
    required String state,
    List<int> ports = const [1455, 1457],
    String path = '/auth/callback',
    Uri? doneRedirect,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    for (final port in ports) {
      final HttpServer v4;
      try {
        v4 = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      } on SocketException {
        continue;
      }
      final servers = [v4];
      try {
        servers.add(
          await HttpServer.bind(
            InternetAddress.loopbackIPv6,
            port,
            v6Only: true,
          ),
        );
      } on SocketException catch (e) {
        if (_addressInUse.contains(e.osError?.errorCode)) {
          // Someone else would get the browser's ::1 requests
          await v4.close(force: true);
          continue;
        }
        // No IPv6 here, so "localhost" is 127.0.0.1
      }
      final server = LoopbackServer._(servers, port, path, state, doneRedirect);
      for (final s in servers) {
        // e.g. iOS took the socket back while nts was in the background:
        // the browser can't reach us any more, so don't wait 5 minutes
        s.listen(
          server._handle,
          onError: (Object e) {
            log.warning('$e');
            server._complete(null, _interrupted);
          },
          onDone: () => server._complete(null, _interrupted),
        );
      }
      server._timeout = Timer(timeout, () {
        server._complete(
          null,
          const AiError(AiError.cancelled, 'Sign-in took too long. Try again.'),
        );
        unawaited(server._closeServers());
      });
      return server;
    }
    throw const AiError(
      AiError.failed,
      'Couldn\'t start sign-in: another app is using its ports. '
      'Close other sign-in windows (e.g. Codex) and try again.',
    );
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    // Checked and completed without awaiting in between: single use
    if (_result.isCompleted || request.uri.path != path) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    final query = request.uri.queryParameters;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    if (query['state'] != _state) {
      response.statusCode = HttpStatus.badRequest;
      response.headers.contentType = ContentType.html;
      response.write(
        _page(
          title: 'This sign-in link doesn\'t match',
          body: 'Go back to nts and sign in from there.',
        ),
      );
      await response.close();
      return;
    }
    final AiError? error;
    if (query['error'] case final code?) {
      error = code == 'access_denied'
          ? const AiError(AiError.denied, 'Sign-in was cancelled.')
          : AiError(
              AiError.failed,
              'Sign-in failed (${query['error_description'] ?? code}).',
            );
    } else if (query['code'] == null) {
      error = const AiError(AiError.failed, 'Sign-in failed. Try again.');
    } else {
      error = null;
    }
    _complete(query, error);

    if (_doneRedirect case final done?) {
      response.statusCode = HttpStatus.found;
      response.headers.set(HttpHeaders.locationHeader, done.toString());
    }
    response.headers.contentType = ContentType.html;
    response.write(
      error == null
          ? _page(
              title: 'You\'re signed in',
              body: 'You can close this window and go back to nts.',
              success: true,
            )
          : _page(
              title: 'Sign-in didn\'t finish',
              body: 'You can close this window and try again in nts.',
            ),
    );
    await response.close();
    await _closeServers();
  }

  /// Stops waiting; [result] throws [error] (CANCELLED by default) if
  /// nothing arrived yet.
  Future<void> close([
    AiError error = const AiError(AiError.cancelled, 'Sign-in was cancelled.'),
  ]) {
    _complete(null, error);
    return _closeServers();
  }

  void _complete(Map<String, String>? query, AiError? error) {
    _timeout?.cancel();
    if (_result.isCompleted) return;
    if (error != null) {
      _result.completeError(error);
    } else {
      _result.complete(query!);
    }
  }

  Future<void> _closeServers() =>
      Future.wait([for (final s in _servers) s.close(force: true)]);

  static String _page({
    required String title,
    required String body,
    bool success = false,
  }) {
    return '''
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>nts</title>
<style>
:root { color-scheme: dark light; --bg: #0A0A0B; --card: #111113;
  --line: rgba(255,255,255,.07); --text: #ECEAE5; --muted: #8B8883; }
@media (prefers-color-scheme: light) { :root { --bg: #F1EFEA;
  --card: #F8F7F3; --line: rgba(20,18,16,.08); --text: #151413;
  --muted: #6E6A65; } }
body { margin: 0; min-height: 100vh; display: grid; place-items: center;
  background: var(--bg); color: var(--text);
  font: 15px/1.5 Geist, -apple-system, system-ui, sans-serif; }
main { margin: 16px; padding: 28px 32px; max-width: 360px;
  background: var(--card); border: 1px solid var(--line);
  border-radius: 14px; }
.mark { width: 10px; height: 10px; border-radius: 50%;
  background: ${success ? '#D0283A' : '#8B8883'}; }
h1 { font-size: 18px; font-weight: 600; margin: 14px 0 4px; }
p { margin: 0; color: var(--muted); }
</style></head>
<body><main><div class="mark"></div><h1>$title</h1><p>$body</p></main></body>
</html>''';
  }
}
