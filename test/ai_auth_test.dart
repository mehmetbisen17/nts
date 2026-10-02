import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/auth/jwt.dart';
import 'package:nts/data/ai/auth/loopback_server.dart';
import 'package:nts/data/ai/auth/oauth_tokens.dart';
import 'package:nts/data/ai/auth/pkce.dart';

Matcher throwsAiError(String code) =>
    throwsA(isA<AiError>().having((e) => e.code, 'code', code));

void main() {
  group('PKCE', () {
    test('S256 challenge matches RFC 7636 appendix B', () {
      expect(
        Pkce.challengeOf('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('verifiers are random, long enough and URL-safe', () {
      final a = Pkce.generate(), b = Pkce.generate();
      expect(a.verifier, isNot(b.verifier));
      expect(a.verifier, matches(RegExp(r'^[A-Za-z0-9\-_]{43,128}$')));
      expect(a.challenge, Pkce.challengeOf(a.verifier));
      expect(randomUrlSafe(), matches(RegExp(r'^[A-Za-z0-9\-_]{43}$')));
    });
  });

  group('JWT claims', () {
    String jwt(Object payload) =>
        'eyJhbGciOiJub25lIn0.'
        '${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}'
        '.sig';

    test('reads the payload without padding', () {
      final claims = jwtClaims(
        jwt({
          'email': 'me@example.com',
          'https://api.openai.com/auth': {'chatgpt_account_id': 'acc_1'},
        }),
      )!;
      expect(claims['email'], 'me@example.com');
      expect(
        (claims['https://api.openai.com/auth']! as Map)['chatgpt_account_id'],
        'acc_1',
      );
    });

    test('is null for anything else', () {
      expect(jwtClaims(null), isNull);
      expect(jwtClaims('not a jwt'), isNull);
      expect(jwtClaims('a.%%%.c'), isNull);
      expect(jwtClaims(jwt([1, 2])), isNull);
    });
  });

  group('LoopbackServer', () {
    /// A port that was free a moment ago.
    Future<int> freePort() async {
      final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = s.port;
      await s.close();
      return port;
    }

    Future<HttpClientResponse> get(String host, int port, String query) async {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://$host:$port/auth/callback?$query'),
      );
      request.followRedirects = false;
      final response = await request.close();
      await response.drain<void>();
      client.close();
      return response;
    }

    test('returns the code once and closes', () async {
      final server = await LoopbackServer.start(
        state: 's1',
        ports: [await freePort()],
      );
      expect(
        server.redirectUri,
        'http://localhost:${server.port}/auth/callback',
      );

      final response = await get('127.0.0.1', server.port, 'code=c1&state=s1');
      expect(response.statusCode, HttpStatus.ok);
      expect(await server.result, {'code': 'c1', 'state': 's1'});

      // Single use
      await expectLater(
        get('127.0.0.1', server.port, 'code=c2&state=s1'),
        throwsA(isA<SocketException>()),
      );
    });

    test('listens on ::1 too and can redirect to the app', () async {
      final server = await LoopbackServer.start(
        state: 's',
        ports: [await freePort()],
        doneRedirect: Uri.parse('nts-auth://done'),
      );
      final response = await get('[::1]', server.port, 'code=c&state=s');
      expect(response.statusCode, HttpStatus.found);
      expect(response.headers.value('location'), 'nts-auth://done');
      expect((await server.result)['code'], 'c');
    });

    test('ignores other paths and wrong states until the real one', () async {
      final server = await LoopbackServer.start(
        state: 'right',
        ports: [await freePort()],
      );
      final client = HttpClient();
      final favicon = await (await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}/favicon.ico'),
      )).close();
      expect(favicon.statusCode, HttpStatus.notFound);
      client.close();

      // e.g. a page or an old tab loading the callback: not the sign-in
      for (final query in ['code=c&state=wrong', '', 'error=access_denied']) {
        final response = await get('127.0.0.1', server.port, query);
        expect(response.statusCode, HttpStatus.badRequest);
      }
      await get('127.0.0.1', server.port, 'code=c&state=right');
      expect(await server.result, {'code': 'c', 'state': 'right'});
    });

    test('a declined sign-in is DENIED', () async {
      final server = await LoopbackServer.start(
        state: 's',
        ports: [await freePort()],
      );
      await get('127.0.0.1', server.port, 'error=access_denied&state=s');
      await expectLater(server.result, throwsAiError(AiError.denied));
    });

    test('uses the next port if one is taken', () async {
      final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final free = await freePort();
      final server = await LoopbackServer.start(
        state: 's',
        ports: [taken.port, free],
      );
      expect(server.port, free);
      await server.close();
      await taken.close();
      await expectLater(server.result, throwsAiError(AiError.cancelled));
    });

    test('gives up after the timeout', () async {
      final server = await LoopbackServer.start(
        state: 's',
        ports: [await freePort()],
        timeout: const Duration(milliseconds: 50),
      );
      await expectLater(server.result, throwsAiError(AiError.cancelled));
    });
  });

  group('requestTokens', () {
    final endpoint = Uri.parse('https://auth.example.com/oauth/token');

    test('posts the form and keeps the old refresh token', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({'access_token': 'a2', 'expires_in': 3600}),
          200,
        );
      });
      final previous = OAuthTokens(
        accessToken: 'a1',
        expiresAt: DateTime.now(),
        refreshToken: 'r1',
        idToken: 'i1',
      );
      final tokens = await requestTokens(
        endpoint,
        {'grant_type': 'refresh_token', 'refresh_token': 'r1'},
        previous: previous,
        client: client,
      );
      expect(sent.bodyFields, {
        'grant_type': 'refresh_token',
        'refresh_token': 'r1',
      });
      expect(tokens.accessToken, 'a2');
      expect(tokens.refreshToken, 'r1');
      expect(tokens.idToken, 'i1');
      expect(
        tokens.expiresAt.difference(DateTime.now()).inMinutes,
        inInclusiveRange(59, 60),
      );
    });

    Future<void> expectError(http.Response response, String code) =>
        expectLater(
          requestTokens(
            endpoint,
            const {},
            client: MockClient((_) async => response),
          ),
          throwsAiError(code),
        );

    test('a spent grant means signed out, other errors don\'t', () async {
      await expectError(
        http.Response('{"error":"invalid_grant"}', 400),
        AiError.signedOut,
      );
      await expectError(
        http.Response('{"error":{"code":"refresh_token_reused"}}', 401),
        AiError.signedOut,
      );
      await expectError(
        http.Response('{"error":"invalid_request"}', 400),
        AiError.failed,
      );
      await expectError(http.Response('oops', 500), AiError.failed);
      await expectLater(
        requestTokens(
          endpoint,
          const {},
          client: MockClient((_) => throw const SocketException('offline')),
        ),
        throwsAiError(AiError.failed),
      );
    });
  });

  group('TokenStore', () {
    OAuthTokens tokens(String access, Duration expiresIn, [String? refresh]) =>
        OAuthTokens(
          accessToken: access,
          expiresAt: DateTime.now().add(expiresIn),
          refreshToken: refresh,
        );

    test('refreshes early, once at a time, and saves the rotation', () async {
      var refreshes = 0;
      final gate = Completer<void>();
      final store = TokenStore(
        KeychainStow('test.tokens'),
        refresh: (current) async {
          refreshes++;
          expect(current.refreshToken, 'r1');
          await gate.future;
          return tokens('a2', const Duration(hours: 1), 'r2');
        },
      );
      expect(store.accessToken(), throwsAiError(AiError.signedOut));

      // Still valid for 4 minutes: less than the 5 minute margin
      await store.save(tokens('a1', const Duration(minutes: 4), 'r1'));
      final calls = [for (var i = 0; i < 3; i++) store.accessToken()];
      gate.complete();
      expect(await Future.wait(calls), ['a2', 'a2', 'a2']);
      expect(refreshes, 1);
      expect(store.tokens!.refreshToken, 'r2');

      // Valid: no refresh
      expect(await store.accessToken(), 'a2');
      expect(refreshes, 1);
    });

    test('a rejected token is refreshed once for all callers', () async {
      var refreshes = 0;
      final store = TokenStore(
        KeychainStow('test.tokens2'),
        refresh: (_) async {
          refreshes++;
          return tokens('a${refreshes + 1}', const Duration(hours: 1), 'r');
        },
      );
      await store.save(tokens('a1', const Duration(hours: 1), 'r'));
      expect(await store.accessToken(rejected: 'a1'), 'a2');
      // Another request that was rejected with a1 gets a2 without a refresh
      expect(await store.accessToken(rejected: 'a1'), 'a2');
      expect(refreshes, 1);
    });

    test('a spent refresh token signs out, being offline doesn\'t', () async {
      var error = const AiError(AiError.failed, 'offline');
      final store = TokenStore(
        KeychainStow('test.tokens3'),
        refresh: (_) async => throw error,
      );
      await store.save(tokens('a1', Duration.zero, 'r1'));

      await expectLater(store.accessToken(), throwsAiError(AiError.failed));
      expect(store.tokens, isNotNull);

      error = const AiError(AiError.signedOut, 'gone');
      await expectLater(store.accessToken(), throwsAiError(AiError.signedOut));
      expect(store.tokens, isNull);
    });

    test('signing out during a refresh stays signed out', () async {
      final gate = Completer<void>();
      final store = TokenStore(
        KeychainStow('test.tokens4'),
        refresh: (_) async {
          await gate.future;
          return tokens('a2', const Duration(hours: 1), 'r2');
        },
      );
      await store.save(tokens('a1', Duration.zero, 'r1'));
      final request = store.accessToken();
      await store.clear(); // Sign out, while the refresh is out
      gate.complete();
      await expectLater(request, throwsAiError(AiError.signedOut));
      expect(store.tokens, isNull, reason: 'not written back');

      // Signed in again meanwhile: the new sign-in's tokens are used
      final gate2 = Completer<void>();
      final store2 = TokenStore(
        KeychainStow('test.tokens5'),
        refresh: (_) async {
          await gate2.future;
          throw const AiError(AiError.signedOut, 'old grant gone');
        },
      );
      await store2.save(tokens('a1', Duration.zero, 'r1'));
      final request2 = store2.accessToken();
      await store2.save(tokens('b1', const Duration(hours: 1), 'rb'));
      gate2.complete();
      expect(await request2, 'b1');
      expect(store2.tokens!.refreshToken, 'rb');
    });

    test('tokens round-trip through JSON', () {
      final t = OAuthTokens(
        accessToken: 'secret-a',
        expiresAt: DateTime.fromMillisecondsSinceEpoch(1000),
        refreshToken: 'secret-r',
      );
      final back = OAuthTokens.fromJson(
        (jsonDecode(jsonEncode(t.toJson())) as Map).cast(),
      );
      expect(back.accessToken, 'secret-a');
      expect(back.refreshToken, 'secret-r');
      expect(back.idToken, isNull);
      expect(back.expiresAt, t.expiresAt);
      expect('$t', isNot(contains('secret'))); // safe to log
    });
  });

  test('the Keychain works in the ad-hoc signed Mac build', () {
    // The data protection keychain fails there with -34018
    final options = KeychainStow('x').storage.mOptions.toMap();
    expect(options['usesDataProtectionKeychain'], 'false');
  });
}
