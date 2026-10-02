import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/auth/oauth_tokens.dart';
import 'package:nts/data/ai/auth/pkce.dart';
import 'package:nts/data/ai/providers/chatgpt_provider.dart';
import 'package:nts/data/ai/providers/claude_code_provider.dart';
import 'package:nts/data/ai/providers/common.dart';
import 'package:nts/data/ai/providers/google_provider.dart';
import 'package:nts/data/version.dart';
import 'package:stow_secure/stow_secure.dart';

/// An unsigned JWT with [claims], like the ones token endpoints return.
String jwt(Map<String, Object?> claims) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}

/// A Keychain stow in memory, holding [tokens].
SecureStow<String> tokenStow([OAuthTokens? tokens]) =>
    SecureStow('test.tokens', '', volatile: true)
      ..value = tokens == null ? '' : jsonEncode(tokens.toJson());

OAuthTokens tokens({
  String access = 'access1',
  String? refresh = 'refresh1',
  String? id,
  Duration expiresIn = const Duration(hours: 1),
}) => OAuthTokens(
  accessToken: access,
  expiresAt: DateTime.now().add(expiresIn),
  refreshToken: refresh,
  idToken: id,
);

http.StreamedResponse sse(List<Object> events, {int status = 200}) =>
    http.StreamedResponse(
      Stream.fromIterable([
        for (final event in events)
          utf8.encode('data: ${jsonEncode(event)}\n\n'),
      ]),
      status,
    );

http.StreamedResponse jsonResponse(Object json, {int status = 200}) =>
    http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(json))), status);

Matcher aiError(String code, [Object? message = anything]) => throwsA(
  isA<AiError>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.message, 'message', message),
);

void main() {
  group('common', () {
    test('sseData joins data lines and splits events, across chunks', () async {
      final chunks = [
        'data: {"a":',
        '1}\n\nevent: x\ndata: line1\ndata: line2\n',
        '\n: comment\ndata:no-space\n\n',
      ];
      final data = await sseData(Stream.fromIterable(chunks.map(utf8.encode)))
          .toList();
      expect(data, ['{"a":1}', 'line1\nline2', 'no-space']);
    });

    test('youTubeId reads watch, share, shorts and embed links', () {
      String? id(String url) => youTubeId(Uri.parse(url));
      expect(id('https://www.youtube.com/watch?v=Le7KOX91w7U'), 'Le7KOX91w7U');
      expect(
        id('https://m.youtube.com/watch?v=Le7KOX91w7U&t=3'),
        'Le7KOX91w7U',
      );
      expect(id('https://youtu.be/Le7KOX91w7U'), 'Le7KOX91w7U');
      expect(id('https://youtube.com/shorts/Le7KOX91w7U'), 'Le7KOX91w7U');
      expect(id('https://www.youtube.com/embed/Le7KOX91w7U'), 'Le7KOX91w7U');
      expect(id('https://www.youtube.com/@channel'), isNull);
      expect(id('https://notyoutube.com/watch?v=Le7KOX91w7U'), isNull);
    });

    test(
      'keepLinks dedupes, drops non-web links, and videos not on YouTube',
      () {
        final links = [
          linkFor(
            'A',
            Uri.parse('https://www.youtube.com/watch?v=Le7KOX91w7U'),
          ),
          linkFor('A again', Uri.parse('https://youtu.be/Le7KOX91w7U')),
          linkFor(
            'B',
            Uri.parse('https://en.wikipedia.org/wiki/Photosynthesis'),
          ),
          linkFor('C', Uri.parse('javascript:alert(1)')),
        ];
        expect(keepLinks(links, .video).map((l) => l.title), ['A']);
        expect(keepLinks(links, .source).map((l) => l.title), ['A', 'B']);
        final video = keepLinks(links, .video).single;
        expect(video.source, 'YouTube');
        expect(
          video.thumbnail.toString(),
          'https://i.ytimg.com/vi/Le7KOX91w7U/hqdefault.jpg',
        );
        expect(keepLinks(links, .source).last.source, 'en.wikipedia.org');
      },
    );

    test('linksInText reads markdown links and bare URLs', () {
      final links = linksInText('''
1. [Light reactions](https://www.khanacademy.org/science/photosynthesis).
- Photosynthesis – https://en.wikipedia.org/wiki/Photosynthesis.
No link here.''');
      expect(links.map((l) => (l.title, l.url.toString())), [
        (
          'Light reactions',
          'https://www.khanacademy.org/science/photosynthesis',
        ),
        ('Photosynthesis', 'https://en.wikipedia.org/wiki/Photosynthesis'),
      ]);
    });

    test('cleanSchema drops x- keys everywhere', () {
      expect(
        cleanSchema({
          'type': 'object',
          'x-order': ['a'],
          'properties': {
            'a': {'type': 'string', 'x-hint': 1},
          },
          'anyOf': [
            {'x-order': [], 'type': 'number'},
          ],
        }),
        {
          'type': 'object',
          'properties': {
            'a': {'type': 'string'},
          },
          'anyOf': [
            {'type': 'number'},
          ],
        },
      );
    });

    test('linksFromJson keeps only real URLs', () {
      final links = linksFromJson(
        jsonEncode({
          'links': [
            {'title': 'W', 'url': 'https://en.wikipedia.org/wiki/X'},
            {'title': 'Bad', 'url': 'not a url'},
            {'title': 'No url'},
          ],
        }),
      );
      expect(links.map((l) => l.title), ['W']);
    });
  });

  group('ChatGPT', () {
    final idToken = jwt({
      'email': 'me@example.com',
      'https://api.openai.com/auth': {
        'chatgpt_account_id': 'acct_1',
        'chatgpt_plan_type': 'plus',
      },
    });

    ChatGptProvider provider(
      Future<http.StreamedResponse> Function(http.BaseRequest, String body)
      handler, {
      OAuthTokens? saved,
      WebAuth? webAuth,
    }) => ChatGptProvider(
      tokenStow(saved ?? tokens(id: idToken)),
      client: MockClient.streaming(
        (request, body) async => handler(request, await body.bytesToString()),
      ),
      webAuth: webAuth,
    );

    test('authorizeUrl has the Codex client, PKCE S256 and nts', () {
      final pkce = Pkce.generate();
      final url = ChatGptProvider.authorizeUrl(
        redirectUri: 'http://localhost:1455/auth/callback',
        pkce: pkce,
        state: 'st',
      );
      expect(url.host, 'auth.openai.com');
      expect(url.path, '/oauth/authorize');
      expect(url.queryParameters, {
        'response_type': 'code',
        'client_id': 'app_EMoamEEZ73f0CkXaXp7hrann',
        'redirect_uri': 'http://localhost:1455/auth/callback',
        'scope': 'openid profile email offline_access',
        'code_challenge': Pkce.challengeOf(pkce.verifier),
        'code_challenge_method': 'S256',
        'id_token_add_organizations': 'true',
        'codex_cli_simplified_flow': 'true',
        'state': 'st',
        'originator': 'nts',
      });
    });

    test('reads email, plan and account id from the JWTs', () {
      final t = tokens(id: idToken);
      final status = ChatGptProvider.statusOf(t);
      expect(status.state, AiAuthState.signedIn);
      expect(status.label, 'me@example.com');
      expect(status.plan, 'plus');
      expect(ChatGptProvider.accountId(t), 'acct_1');
      // The access token's claims win: they're renewed on refresh
      final upgraded = tokens(
        id: idToken,
        access: jwt({
          'https://api.openai.com/auth': {
            'chatgpt_account_id': 'acct_1',
            'chatgpt_plan_type': 'pro',
          },
        }),
      );
      expect(ChatGptProvider.statusOf(upgraded).plan, 'pro');
      expect(
        ChatGptProvider.accountId(
          tokens(
            id: jwt({
              'organizations': [
                {'id': 'org_9'},
              ],
            }),
          ),
        ),
        'org_9',
      );
    });

    test('requestBody sends the picture, schema and search tool', () {
      final body = ChatGptProvider.requestBody(
        AiRequest(
          instructions: 'Be brief.',
          prompt: 'typed text',
          imagePng: Uint8List.fromList([1, 2, 3]),
          jsonSchema: '{"type":"object","x-order":["a"]}',
          webSearch: true,
        ),
        'gpt-5.4',
      );
      expect(body['model'], 'gpt-5.4');
      expect(body['instructions'], 'Be brief.');
      expect(body['stream'], true);
      expect(body['store'], false);
      expect(body['tools'], [
        {'type': 'web_search'},
      ]);
      expect((body['input']! as List).single['content'], [
        {'type': 'input_text', 'text': 'typed text'},
        {'type': 'input_image', 'image_url': 'data:image/png;base64,AQID'},
      ]);
      expect((body['text']! as Map)['format'], {
        'type': 'json_schema',
        'name': 'answer',
        'schema': {'type': 'object'},
        'strict': false,
      });
    });

    test('respond streams text with honest nts headers', () async {
      late http.BaseRequest sent;
      late Map<String, Object?> sentBody;
      final chatgpt = provider((request, body) async {
        sent = request;
        sentBody = jsonDecode(body) as Map<String, Object?>;
        return sse([
          {'type': 'response.created'},
          {'type': 'response.output_text.delta', 'delta': 'Hel'},
          {'type': 'response.output_text.delta', 'delta': 'lo'},
          {'type': 'response.completed', 'response': <String, Object?>{}},
        ]);
      });
      await chatgpt.refreshStatus();
      final partials = <String>[];
      final answer = await chatgpt.respond(
        'r1',
        const AiRequest(instructions: 'i', prompt: 'p'),
        model: 'gpt-5.4-mini',
        onPartial: partials.add,
      );
      expect(answer, 'Hello');
      expect(partials, ['Hel', 'Hello']);
      expect(
        sent.url.toString(),
        'https://chatgpt.com/backend-api/codex/responses',
      );
      expect(sent.headers['Authorization'], 'Bearer access1');
      expect(sent.headers['ChatGPT-Account-Id'], 'acct_1');
      expect(sent.headers['originator'], 'nts');
      expect(sent.headers['User-Agent'], 'nts/$buildName');
      expect(sentBody['model'], 'gpt-5.4-mini');
    });

    test('lite models get the plain request, not Codex\'s internal one', () {
      // Codex sends models with use_responses_lite (e.g. gpt-6-astra) its
      // instructions as a developer message under an internal header;
      // plain instructions are followed too
      final body = ChatGptProvider.requestBody(
        const AiRequest(instructions: 'Read it first.', prompt: 'p'),
        'gpt-6-astra',
      );
      expect(body['instructions'], 'Read it first.');
      expect(body.containsKey('tools'), isFalse);
      final input = body['input']! as List;
      expect(input.single, containsPair('role', 'user'));
      expect(jsonEncode(body), isNot(contains('additional_tools')));
    });

    test('only the final answer counts, not commentary', () async {
      final chatgpt = provider(
        (request, body) async => sse([
          {
            'type': 'response.output_item.added',
            'output_index': 0,
            'item': {'type': 'reasoning', 'id': 'rs_1'},
          },
          {
            'type': 'response.output_item.added',
            'output_index': 1,
            'item': {'type': 'message', 'id': 'msg_1', 'phase': 'commentary'},
          },
          {
            'type': 'response.output_text.delta',
            'output_index': 1,
            'item_id': 'msg_1',
            'delta': 'Let me read the handwriting.',
          },
          {
            'type': 'response.output_item.done',
            'output_index': 1,
            'item': {
              'type': 'message',
              'id': 'msg_1',
              'phase': 'commentary',
              'content': [
                {'type': 'output_text', 'text': 'Let me read the handwriting.'},
              ],
            },
          },
          {
            'type': 'response.output_item.added',
            'output_index': 2,
            'item': {'type': 'message', 'id': 'msg_2'},
          },
          {
            'type': 'response.output_text.delta',
            'output_index': 2,
            'item_id': 'msg_2',
            'delta': 'You wrote: 1 + 1 = 2',
          },
          {
            'type': 'response.output_item.done',
            'output_index': 2,
            'item': {
              'type': 'message',
              'id': 'msg_2',
              'phase': 'final_answer',
              'content': [
                {'type': 'output_text', 'text': 'You wrote: 1 + 1 = 2'},
              ],
            },
          },
          // A second answer message: its own paragraph, not glued on
          {
            'type': 'response.output_text.delta',
            'output_index': 3,
            'item_id': 'msg_3',
            'delta': 'Two.',
          },
          {'type': 'response.completed', 'response': <String, Object?>{}},
        ]),
      );
      await chatgpt.refreshStatus();
      final partials = <String>[];
      final answer = await chatgpt.respond(
        'r6',
        const AiRequest(instructions: 'i', prompt: 'p'),
        model: 'gpt-6-astra',
        onPartial: partials.add,
      );
      expect(answer, 'You wrote: 1 + 1 = 2\n\nTwo.');
      expect(partials, [
        'You wrote: 1 + 1 = 2',
        'You wrote: 1 + 1 = 2\n\nTwo.',
      ]);
    });

    test('a 401 refreshes once and retries; a second 401 signs out', () async {
      final auths = <String?>[];
      var refreshes = 0;
      final chatgpt = provider((request, body) async {
        if (request.url.path == '/oauth/token') {
          refreshes++;
          final form = Uri.splitQueryString(body);
          expect(form['grant_type'], 'refresh_token');
          expect(form['refresh_token'], 'refresh1');
          expect(form['client_id'], ChatGptProvider.clientId);
          return jsonResponse({
            'access_token': 'access2',
            'refresh_token': 'refresh2',
            'expires_in': 3600,
          });
        }
        auths.add(request.headers['Authorization']);
        return auths.length == 1
            ? jsonResponse({'detail': 'expired'}, status: 401)
            : sse([
                {'type': 'response.output_text.delta', 'delta': 'ok'},
              ]);
      });
      await chatgpt.refreshStatus();
      final answer = await chatgpt.respond(
        'r2',
        const AiRequest(instructions: 'i', prompt: 'p'),
        model: 'gpt-5.4',
      );
      expect(answer, 'ok');
      expect(auths, ['Bearer access1', 'Bearer access2']);
      expect(refreshes, 1);

      final rejected = provider(
        (request, body) async => request.url.path == '/oauth/token'
            ? jsonResponse({'access_token': 'access2', 'expires_in': 3600})
            : jsonResponse({'detail': 'nope'}, status: 401),
      );
      await rejected.refreshStatus();
      await expectLater(
        rejected.respond(
          'r3',
          const AiRequest(instructions: 'i', prompt: 'p'),
          model: 'gpt-5.4',
        ),
        aiError(AiError.signedOut),
      );
      expect(rejected.status.value.state, AiAuthState.signedOut);
    });

    test('an invalid_grant refresh signs out', () async {
      final chatgpt = provider(
        (request, body) async =>
            jsonResponse({'error': 'invalid_grant'}, status: 400),
        saved: tokens(id: idToken, expiresIn: Duration.zero),
      );
      await chatgpt.refreshStatus();
      await expectLater(
        chatgpt.respond(
          'r4',
          const AiRequest(instructions: 'i', prompt: 'p'),
          model: 'gpt-5.4',
        ),
        aiError(AiError.signedOut),
      );
      expect(chatgpt.status.value.state, AiAuthState.signedOut);
    });

    test('maps usage limits, missing models and stream failures', () {
      final now = DateTime(2026, 9, 27, 12);
      final limit = ChatGptProvider.chatGptError(429, {
        'error': {
          'type': 'usage_limit_reached',
          'message': 'The usage limit has been reached',
          'resets_in_seconds': 3600,
        },
      }, now: now);
      expect(limit.code, AiError.limit);
      expect(
        limit.message,
        startsWith('ChatGPT plan limit reached. Try again after'),
      );
      expect(
        ChatGptProvider.chatGptError(400, {
          'detail': 'The model gpt-9 does not exist or you do not have access.',
        }).code,
        AiError.modelUnavailable,
      );
      expect(
        ChatGptProvider.chatGptError(0, {
          'error': {'code': 'server_error', 'message': 'Oops'},
        }).message,
        'ChatGPT: Oops',
      );
      expect(ChatGptProvider.chatGptError(403, {}).code, AiError.denied);
    });

    test('a response.failed event throws its error', () async {
      final chatgpt = provider(
        (request, body) async => sse([
          {'type': 'response.output_text.delta', 'delta': 'par'},
          {
            'type': 'response.failed',
            'response': {
              'error': {'code': 'rate_limit_exceeded', 'message': 'Slow down'},
            },
          },
        ]),
      );
      await chatgpt.refreshStatus();
      await expectLater(
        chatgpt.respond(
          'r5',
          const AiRequest(instructions: 'i', prompt: 'p'),
          model: 'gpt-5.4',
        ),
        aiError(AiError.limit),
      );
    });

    test('search returns cited links; videos only from YouTube', () async {
      final chatgpt = provider((request, body) async {
        final json = jsonDecode(body) as Map;
        expect(json['tools'], [
          {'type': 'web_search'},
        ]);
        expect(json['instructions'], contains('youtube.com'));
        return sse([
          {'type': 'response.output_text.delta', 'delta': 'Results'},
          {
            'type': 'response.output_item.done',
            'item': {
              'type': 'message',
              'content': [
                {
                  'type': 'output_text',
                  'text': 'Results',
                  'annotations': [
                    {
                      'type': 'url_citation',
                      'url': 'https://www.youtube.com/watch?v=Le7KOX91w7U',
                      'title': 'Light reactions',
                    },
                    {
                      'type': 'url_citation',
                      'url': 'https://example.com/blog',
                      'title': 'Blog',
                    },
                  ],
                },
              ],
            },
          },
        ]);
      });
      await chatgpt.refreshStatus();
      final links = await chatgpt.search(
        's1',
        'photosynthesis',
        kind: .video,
        model: 'gpt-5.4',
      );
      expect(links.map((l) => l.title), ['Light reactions']);
      expect(links.single.thumbnail, isNotNull);
    });

    test('pictures only on paid plans', () async {
      final png = base64Encode([137, 80, 78, 71]);
      final chatgpt = provider((request, body) async {
        expect(request.url.path, '/backend-api/codex/images/generations');
        expect((jsonDecode(body) as Map)['model'], 'gpt-image-2');
        return jsonResponse({
          'data': [
            {'b64_json': png},
          ],
        });
      });
      await chatgpt.refreshStatus();
      expect(
        await chatgpt.generateImage('i1', 'a leaf', model: 'gpt-image-2'),
        [137, 80, 78, 71],
      );

      final free = provider(
        (request, body) async => fail('no request'),
        saved: tokens(
          id: jwt({
            'https://api.openai.com/auth': {'chatgpt_plan_type': 'free'},
          }),
        ),
      );
      await free.refreshStatus();
      expect(free.generateImage('i2', 'a leaf', model: 'gpt-image-2'), isNull);
      expect((await free.models()).where((m) => m.isImageModel), isEmpty);
    });

    test('models: the server list, else the fallback', () async {
      final chatgpt = provider((request, body) async {
        expect(request.url.queryParameters['client_version'], buildName);
        return jsonResponse({
          'models': [
            {'slug': 'gpt-5.4', 'display_name': 'GPT-5.4', 'priority': 2},
            {'slug': 'gpt-6-sol', 'display_name': 'GPT-6 Sol', 'priority': 1},
            {'slug': 'secret', 'visibility': 'hide'},
            {'slug': 'internal', 'supported_in_api': false},
          ],
        });
      });
      await chatgpt.refreshStatus();
      final models = await chatgpt.models();
      expect(models.map((m) => m.id), [
        'gpt-6-sol',
        'gpt-5.4',
        'gpt-image-2',
        'gpt-image-1.5',
      ]);

      final offline = provider(
        (request, body) async => jsonResponse({}, status: 404),
      );
      await offline.refreshStatus();
      expect(
        (await offline.models()).where((m) => !m.isImageModel).map((m) => m.id),
        ChatGptProvider.fallbackModels.map((m) => m.id),
      );
    });

    test(
      'browser sign-in: loopback callback, then PKCE code exchange',
      () async {
        late Uri authorizeUrl;
        final chatgpt = provider(
          (request, body) async {
            expect(
              request.url.toString(),
              'https://auth.openai.com/oauth/token',
            );
            final form = Uri.splitQueryString(body);
            expect(form['grant_type'], 'authorization_code');
            expect(form['code'], 'the-code');
            expect(form['client_id'], ChatGptProvider.clientId);
            expect(
              form['redirect_uri'],
              authorizeUrl.queryParameters['redirect_uri'],
            );
            // The verifier matches the challenge sent to the browser
            expect(
              Pkce.challengeOf(form['code_verifier']!),
              authorizeUrl.queryParameters['code_challenge'],
            );
            return jsonResponse({
              'access_token': 'a',
              'refresh_token': 'r',
              'id_token': idToken,
              'expires_in': 3600,
            });
          },
          saved: null,
          webAuth: ({required url, required callbackUrlScheme}) async {
            expect(callbackUrlScheme, 'nts-auth');
            authorizeUrl = Uri.parse(url);
            // What the browser does after the user signs in
            final redirect =
                Uri.parse(authorizeUrl.queryParameters['redirect_uri']!)
                    .replace(
                      host: '127.0.0.1',
                      queryParameters: {
                        'code': 'the-code',
                        'state': authorizeUrl.queryParameters['state'],
                      },
                    );
            final client = HttpClient();
            try {
              final request = await client.getUrl(redirect)
                ..followRedirects = false;
              final response = await request.close();
              expect(response.statusCode, HttpStatus.found);
              expect(response.headers.value('location'), 'nts-auth://done');
              await response.drain<void>();
            } finally {
              client.close();
            }
            return 'nts-auth://done';
          },
        );
        await chatgpt.signInWithBrowser();
        expect(chatgpt.status.value.state, AiAuthState.signedIn);
        expect(chatgpt.status.value.label, 'me@example.com');
      },
    );

    test('cancelling a browser sign-in frees its port, and nothing more '
        'is sent', () async {
      final opened = Completer<Uri>();
      final chatgpt = provider(
        (request, body) async => fail('no token request after cancelling'),
        saved: null,
        webAuth: ({required url, required callbackUrlScheme}) {
          opened.complete(Uri.parse(url));
          return Completer<String>().future; // the sheet stays open
        },
      );
      final signIn = chatgpt.signInWithBrowser();
      final redirect = Uri.parse(
        (await opened.future).queryParameters['redirect_uri']!,
      );
      expect(chatgpt.status.value.state, AiAuthState.signingIn);

      await chatgpt.signOut(); // Settings' Cancel
      await signIn;
      expect(chatgpt.status.value.state, AiAuthState.signedOut);
      await expectLater(
        Socket.connect(InternetAddress.loopbackIPv4, redirect.port),
        throwsA(isA<SocketException>()),
      );
    });

    test('a sign-in sheet that can\'t open says so', () async {
      final chatgpt = provider(
        (request, body) async => fail('no token request'),
        webAuth: ({required url, required callbackUrlScheme}) async =>
            throw PlatformException(
              code: 'ACQUIRE_ROOT_VIEW_CONTROLLER_FAILED',
            ),
      );
      await expectLater(
        chatgpt.signInWithBrowser(),
        throwsA(
          isA<AiError>()
              .having((e) => e.code, 'code', AiError.failed)
              .having((e) => e.message, 'message', contains('Couldn\'t open')),
        ),
      );
    });

    test('cancel stops later calls', () async {
      final chatgpt = provider((request, body) async => fail('no request'));
      await chatgpt.refreshStatus();
      await chatgpt.cancel('c1');
      await expectLater(
        chatgpt.respond(
          'c1',
          const AiRequest(instructions: 'i', prompt: 'p'),
          model: 'gpt-5.4',
        ),
        aiError(AiError.cancelled),
      );
    });
  });

  group('Claude Code', () {
    test('args: print mode, no personal setup, tools off unless searching', () {
      final args = ClaudeCodeProvider.args(
        model: 'sonnet',
        instructions: 'Be brief.',
      );
      expect(args.first, '-p');
      for (final flag in [
        '--restricted',
        '--strict-mcp-config',
        '--disable-slash-commands',
        '--no-session-persistence',
        '--include-partial-messages',
        '--verbose',
      ]) {
        expect(args, contains(flag));
      }
      String after(List<String> args, String flag) =>
          args[args.indexOf(flag) + 1];
      expect(after(args, '--model'), 'sonnet');
      expect(after(args, '--append-system-prompt'), 'Be brief.');
      expect(after(args, '--input-format'), 'stream-json');
      expect(after(args, '--output-format'), 'stream-json');
      expect(after(args, '--permission-mode'), 'dontAsk');
      expect(after(args, '--max-turns'), '4');
      expect(after(args, '--tools'), '');
      expect(args, isNot(contains('--allowedTools')));
      expect(args, isNot(contains('--json-schema')));
      // These would replace the plan's login with API billing
      expect(args, isNot(contains('--bare')));
      expect(args, isNot(contains('--console')));

      final search = ClaudeCodeProvider.args(
        model: 'haiku',
        instructions: 'i',
        jsonSchema: '{"type":"object"}',
        webSearch: true,
      );
      expect(after(search, '--tools'), 'WebSearch,WebFetch');
      expect(after(search, '--allowedTools'), 'WebSearch,WebFetch');
      expect(after(search, '--json-schema'), '{"type":"object"}');
    });

    test('userMessage sends the picture as a base64 image block', () {
      final message = ClaudeCodeProvider.userMessage(
        AiRequest(
          instructions: 'i',
          prompt: '',
          imagePng: Uint8List.fromList([1, 2, 3]),
        ),
      );
      expect((message['message']! as Map)['content'], [
        {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': 'image/png',
            'data': 'AQID',
          },
        },
      ]);
    });

    test('only a claude.ai login counts as signed in', () {
      final max = ClaudeCodeProvider.parseStatus(
        '{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max",'
        '"email":"me@example.com"}',
      );
      expect(max.state, AiAuthState.signedIn);
      expect(max.label, 'Max plan');
      expect(max.plan, 'max');
      expect(
        ClaudeCodeProvider.parseStatus(
          '{"loggedIn":true,"authMethod":"api_key"}',
        ).state,
        AiAuthState.signedOut,
      );
      expect(
        ClaudeCodeProvider.parseStatus('{"loggedIn":false}').state,
        AiAuthState.signedOut,
      );
      expect(
        ClaudeCodeProvider.parseStatus('Unknown command').state,
        AiAuthState.error,
      );
    });

    test('the environment has no API key or nested-session variables', () {
      expect(
        ClaudeCodeProvider.childEnvironment({
          'HOME': '/Users/me',
          'PATH': '/usr/bin',
          'ANTHROPIC_API_KEY': 'sk-ant-x',
          'ANTHROPIC_BASE_URL': 'https://example.com',
          'CLAUDECODE': '1',
          'CLAUDE_CODE_ENTRYPOINT': 'cli',
          'CLAUDE_CONFIG_DIR': '/Users/me/.claude-work',
        }),
        {
          'HOME': '/Users/me',
          'PATH': '/usr/bin',
          'CLAUDE_CONFIG_DIR': '/Users/me/.claude-work',
          'MAX_THINKING_TOKENS': '1024',
        },
      );
    });

    test('maps limits, sign-out and unknown models', () {
      final limit = claudeCodeError(
        result: {
          'type': 'result',
          'subtype': 'success',
          'is_error': true,
          'result': 'Claude AI usage limit reached',
        },
        rateLimit: {'status': 'rejected', 'resetsAt': 1790544000},
      );
      expect(limit!.code, AiError.limit);
      expect(
        limit.message,
        startsWith('Claude plan limit reached. Try again after'),
      );
      expect(
        claudeCodeError(
          result: {
            'subtype': 'success',
            'is_error': true,
            'api_error_status': 404,
          },
          assistantError: 'model_not_found',
        )!.code,
        AiError.modelUnavailable,
      );
      expect(
        claudeCodeError(
          result: {
            'subtype': 'success',
            'is_error': true,
            'result': 'Not logged in · Please run /login',
          },
        )!.code,
        AiError.signedOut,
      );
      expect(
        claudeCodeError(
          result: null,
          exitCode: 1,
          stderr: 'boom\nmore',
        )!.message,
        'Claude Code: boom',
      );
      expect(
        claudeCodeError(result: {'subtype': 'success', 'is_error': false}),
        isNull,
      );
    });

    test('isn\'t available on iPad', () async {
      final claude = ClaudeCodeProvider(isMac: false);
      expect(claude.status.value.state, AiAuthState.unavailable);
      expect(claude.status.value.detail, ClaudeCodeProvider.notOnThisDevice);
      await expectLater(
        claude.respond(
          'x',
          const AiRequest(instructions: 'i', prompt: 'p'),
          model: 'haiku',
        ),
        aiError(AiError.notAvailable),
      );
    });

    test('cancelling sign-in stops claude auth login, without signing '
        'Claude Code out', () async {
      final runs = <List<String>>[];
      FakeProcess? login;
      final claude = ClaudeCodeProvider(
        isMac: true,
        binary: '/fake/claude',
        start:
            (
              executable,
              arguments, {
              workingDirectory,
              environment,
              includeParentEnvironment = true,
            }) async {
              runs.add(arguments);
              if (arguments case ['auth', 'login']) {
                // Waits for the browser, e.g. a closed tab: forever
                return login = FakeProcess([], const [], hang: true);
              }
              return FakeProcess([], ['{"loggedIn":false}']);
            },
      );
      final signIn = claude.signIn(_FakeContext());
      await pumpEventQueue();
      expect(claude.status.value.state, AiAuthState.signingIn);

      await claude.cancelSignIn(); // Settings' Cancel
      expect(login!.killed, isTrue);
      expect(claude.status.value.state, AiAuthState.signedOut);
      await expectLater(signIn, aiError(AiError.cancelled));
      expect(claude.status.value.state, AiAuthState.signedOut);
      expect(runs, isNot(contains(['auth', 'logout'])));
    });

    group('with a fake claude', () {
      late List<List<String>> runs;
      late List<String> stdin;
      late List<String> Function(List<String> args) output;
      var hang = false;
      FakeProcess? running;

      ClaudeCodeProvider fake() => ClaudeCodeProvider(
        isMac: true,
        binary: '/fake/claude',
        start:
            (
              executable,
              arguments, {
              workingDirectory,
              environment,
              includeParentEnvironment = true,
            }) async {
              expect(executable, '/fake/claude');
              expect(includeParentEnvironment, isFalse);
              expect(environment!.keys, isNot(contains('ANTHROPIC_API_KEY')));
              runs.add(arguments);
              if (arguments.first == 'auth') {
                return FakeProcess(stdin, [
                  '{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max"}',
                ]);
              }
              expect(Directory(workingDirectory!).listSync(), isEmpty);
              return running = FakeProcess(
                stdin,
                output(arguments),
                hang: hang,
              );
            },
      );

      setUp(() {
        runs = [];
        stdin = [];
        hang = false;
        running = null;
      });

      test('respond streams the answer', () async {
        output = (args) => [
          '{"type":"system","subtype":"init","apiKeySource":"none"}',
          '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}}',
          '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"lo"}}}',
          '{"type":"result","subtype":"success","is_error":false,"result":"Hello"}',
        ];
        final claude = fake();
        await claude.refreshStatus();
        expect(claude.status.value.label, 'Max plan');
        final partials = <String>[];
        final answer = await claude.respond(
          'r1',
          const AiRequest(instructions: 'Be brief.', prompt: 'Hi'),
          model: 'haiku',
          onPartial: partials.add,
        );
        expect(answer, 'Hello');
        expect(partials, ['Hel', 'Hello']);
        expect(runs.last, contains('-p'));
        final message = jsonDecode(stdin.single) as Map;
        expect(message['type'], 'user');
        expect((message['message'] as Map)['content'], [
          {'type': 'text', 'text': 'Hi'},
        ]);
      });

      test('JSON answers come from structured_output', () async {
        output = (args) => [
          '{"type":"result","subtype":"success","is_error":false,"result":"{}",'
              '"structured_output":{"title":"y = x^2","expression":"x^2"}}',
        ];
        final claude = fake();
        await claude.refreshStatus();
        final json = await claude.respond(
          'r2',
          const AiRequest(
            instructions: 'i',
            prompt: 'y = x^2',
            jsonSchema: '{"type":"object"}',
          ),
          model: 'haiku',
        );
        expect(jsonDecode(json), {'title': 'y = x^2', 'expression': 'x^2'});
      });

      test('search keeps only links its web search found', () async {
        output = (args) => [
          '{"type":"user","message":{"role":"user","content":[{"type":"tool_result",'
              '"tool_use_id":"t","content":"Links: [{\\"title\\":\\"Real\\",'
              '\\"url\\":\\"https://www.youtube.com/watch?v=Le7KOX91w7U\\"}]"}]}}',
          jsonEncode({
            'type': 'result',
            'subtype': 'success',
            'is_error': false,
            'structured_output': {
              'links': [
                {
                  'title': 'Real',
                  'url': 'https://www.youtube.com/watch?v=Le7KOX91w7U',
                },
                {
                  'title': 'Made up',
                  'url': 'https://www.youtube.com/watch?v=AAAAAAAAAAA',
                },
              ],
            },
          }),
        ];
        final claude = fake();
        await claude.refreshStatus();
        final links = await claude.search(
          's1',
          'photosynthesis',
          kind: .video,
          model: 'haiku',
        );
        expect(links.map((l) => l.title), ['Real']);
        String after(String flag) => runs.last[runs.last.indexOf(flag) + 1];
        expect(after('--allowedTools'), 'WebSearch,WebFetch');
        expect(after('--json-schema'), linksSchema);
      });

      test('an error result throws and signs out when needed', () async {
        output = (args) => [
          '{"type":"result","subtype":"success","is_error":true,"api_error_status":401,'
              '"result":"Invalid API key · Please run /login"}',
        ];
        final claude = fake();
        await claude.refreshStatus();
        await expectLater(
          claude.respond(
            'r3',
            const AiRequest(instructions: 'i', prompt: 'p'),
            model: 'haiku',
          ),
          aiError(AiError.signedOut),
        );
        expect(claude.status.value.state, AiAuthState.signedOut);
      });

      test('cancel kills claude', () async {
        hang = true;
        output = (args) => [
          '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}}',
        ];
        final claude = fake();
        await claude.refreshStatus();
        final answer = claude.respond(
          'c1',
          const AiRequest(instructions: 'i', prompt: 'p'),
          model: 'haiku',
          onPartial: (_) => unawaited(claude.cancel('c1')),
        );
        await expectLater(answer, aiError(AiError.cancelled));
        expect(running!.killed, isTrue);
      });
    });
  });

  group('Google', () {
    const clientId = '123-abc.apps.googleusercontent.com';
    final idToken = jwt({'email': 'me@gmail.com', 'aud': clientId});

    GoogleProvider provider(
      Future<http.StreamedResponse> Function(http.BaseRequest, String body)
      handler, {
      OAuthTokens? saved,
      String client = clientId,
      String project = 'my-project',
      WebAuth? webAuth,
    }) => GoogleProvider(
      tokenStow(saved),
      clientId: ValueNotifier(client),
      projectId: ValueNotifier(project),
      client: MockClient.streaming(
        (request, body) async => handler(request, await body.bytesToString()),
      ),
      webAuth: webAuth,
    );

    test('redirect scheme is the reversed client ID', () {
      expect(
        GoogleProvider.redirectScheme(clientId),
        'com.googleusercontent.apps.123-abc',
      );
      expect(
        GoogleProvider.redirectScheme('123-abc'),
        'com.googleusercontent.apps.123-abc',
      );
      expect(GoogleProvider.redirectScheme(''), isNull);
      expect(GoogleProvider.redirectScheme('bad id/'), isNull);
    });

    test('authorizeUrl asks for Gemini and YouTube, offline, with PKCE', () {
      final pkce = Pkce.generate();
      final url = GoogleProvider.authorizeUrl(
        clientId: clientId,
        pkce: pkce,
        state: 'st',
      );
      expect(url.host, 'accounts.google.com');
      expect(url.queryParameters, {
        'client_id': clientId,
        'redirect_uri': 'com.googleusercontent.apps.123-abc:/oauth2redirect',
        'response_type': 'code',
        'scope':
            'openid email '
            'https://www.googleapis.com/auth/generative-language.retriever '
            'https://www.googleapis.com/auth/youtube.readonly',
        'code_challenge': Pkce.challengeOf(pkce.verifier),
        'code_challenge_method': 'S256',
        'state': 'st',
        'access_type': 'offline',
        'prompt': 'consent',
      });
    });

    test('needs setup before anything else', () async {
      final google = provider(
        (request, body) async => fail('no request'),
        client: '',
        project: '',
      );
      await google.refreshStatus();
      expect(google.status.value.state, AiAuthState.unavailable);
      expect(google.status.value.detail, GoogleProvider.setupNeeded);
      await expectLater(
        google.signInWithBrowser(),
        aiError(AiError.setupNeeded),
      );
    });

    test('sign-in checks state and exchanges the code with PKCE', () async {
      late Uri authorizeUrl;
      final google = provider(
        (request, body) async {
          expect(request.url.toString(), 'https://oauth2.googleapis.com/token');
          final form = Uri.splitQueryString(body);
          expect(form['client_id'], clientId);
          expect(form['grant_type'], 'authorization_code');
          expect(form['code'], 'the-code');
          expect(form.containsKey('client_secret'), isFalse);
          expect(
            form['redirect_uri'],
            'com.googleusercontent.apps.123-abc:/oauth2redirect',
          );
          expect(
            Pkce.challengeOf(form['code_verifier']!),
            authorizeUrl.queryParameters['code_challenge'],
          );
          return jsonResponse({
            'access_token': 'a',
            'refresh_token': 'r',
            'id_token': idToken,
            'expires_in': 3599,
          });
        },
        webAuth: ({required url, required callbackUrlScheme}) async {
          expect(callbackUrlScheme, 'com.googleusercontent.apps.123-abc');
          authorizeUrl = Uri.parse(url);
          return 'com.googleusercontent.apps.123-abc:/oauth2redirect'
              '?state=${authorizeUrl.queryParameters['state']}&code=the-code';
        },
      );
      await google.refreshStatus();
      await google.signInWithBrowser();
      expect(google.status.value.state, AiAuthState.signedIn);
      expect(google.status.value.label, 'me@gmail.com');

      final forged = provider(
        (request, body) async => fail('no token request'),
        webAuth: ({required url, required callbackUrlScheme}) async => 'com.googleusercontent.apps.123-abc:/oauth2redirect?state=evil&code=x',
      );
      await forged.refreshStatus();
      await expectLater(forged.signInWithBrowser(), aiError(AiError.failed));
    });

    test('tokens of another client ID are dropped', () async {
      final google = provider(
        (request, body) async => fail('no request'),
        saved: tokens(id: jwt({'aud': 'other.apps.googleusercontent.com'})),
      );
      await google.refreshStatus();
      expect(google.status.value.state, AiAuthState.signedOut);
    });

    test('respond streams Gemini text billed to the project', () async {
      late http.BaseRequest sent;
      late Map<String, Object?> sentBody;
      final google = provider((request, body) async {
        sent = request;
        sentBody = jsonDecode(body) as Map<String, Object?>;
        return sse([
          {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'thinking…', 'thought': true},
                    {'text': 'Hel'},
                  ],
                },
              },
            ],
          },
          {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'lo'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          },
        ]);
      }, saved: tokens(id: idToken));
      await google.refreshStatus();
      final partials = <String>[];
      final answer = await google.respond(
        'r1',
        AiRequest(
          instructions: 'Be brief.',
          prompt: 'typed',
          imagePng: Uint8List.fromList([1, 2, 3]),
          jsonSchema: '{"type":"object","x-order":[]}',
        ),
        model: 'gemini-2.5-flash',
        onPartial: partials.add,
      );
      expect(answer, 'Hello');
      expect(partials, ['Hel', 'Hello']);
      expect(
        sent.url.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/'
        'gemini-2.5-flash:streamGenerateContent?alt=sse',
      );
      expect(sent.headers['Authorization'], 'Bearer access1');
      expect(sent.headers['x-goog-user-project'], 'my-project');
      expect(sentBody['systemInstruction'], {
        'parts': [
          {'text': 'Be brief.'},
        ],
      });
      expect((sentBody['contents']! as List).single['parts'], [
        {'text': 'typed'},
        {
          'inlineData': {'mimeType': 'image/png', 'data': 'AQID'},
        },
      ]);
      expect(sentBody['generationConfig'], {
        'responseMimeType': 'application/json',
        'responseJsonSchema': {'type': 'object'},
      });
    });

    test('video search uses the YouTube Data API', () async {
      final google = provider((request, body) async {
        expect(request.url.host, 'www.googleapis.com');
        expect(request.url.path, '/youtube/v3/search');
        expect(request.url.queryParameters, {
          'part': 'snippet',
          'type': 'video',
          'maxResults': '8',
          'safeSearch': 'moderate',
          'q': 'photosynthesis',
        });
        return jsonResponse({
          'items': [
            {
              'id': {'kind': 'youtube#video', 'videoId': 'Le7KOX91w7U'},
              'snippet': {
                'title': 'Light &amp; Dark Reactions &#39;explained&#39;',
                'channelTitle': 'Bozeman Science',
                'thumbnails': {
                  'default': {
                    'url': 'https://i.ytimg.com/vi/Le7KOX91w7U/default.jpg',
                  },
                  'medium': {
                    'url': 'https://i.ytimg.com/vi/Le7KOX91w7U/mqdefault.jpg',
                  },
                },
              },
            },
            {
              'id': {'kind': 'youtube#channel', 'channelId': 'UC1'},
              'snippet': {'title': 'A channel'},
            },
          ],
        });
      }, saved: tokens(id: idToken));
      await google.refreshStatus();
      final links = await google.search(
        's1',
        'photosynthesis',
        kind: .video,
        model: 'gemini-2.5-flash',
      );
      expect(links, hasLength(1));
      expect(links.single.title, 'Light & Dark Reactions \'explained\'');
      expect(links.single.source, 'Bozeman Science');
      expect(
        links.single.url.toString(),
        'https://www.youtube.com/watch?v=Le7KOX91w7U',
      );
      expect(
        links.single.thumbnail.toString(),
        'https://i.ytimg.com/vi/Le7KOX91w7U/mqdefault.jpg',
      );
    });

    test('source search gives plain links plus a Wikipedia search', () async {
      final google = provider((request, body) async {
        final json = jsonDecode(body) as Map;
        expect(json.containsKey('tools'), isFalse); // no grounding
        return sse([
          {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'links': [
                          {
                            'title': 'Photosynthesis',
                            'url':
                                'https://en.wikipedia.org/wiki/Photosynthesis',
                          },
                        ],
                      }),
                    },
                  ],
                },
              },
            ],
          },
        ]);
      }, saved: tokens(id: idToken));
      await google.refreshStatus();
      final links = await google.search(
        's2',
        'photosynthesis',
        kind: .source,
        model: 'gemini-2.5-flash',
      );
      expect(links.first.title, 'Photosynthesis');
      expect(links.last.url.path, '/w/index.php');
      expect(links.last.url.queryParameters['search'], 'photosynthesis');
    });

    test('maps denied projects, limits and missing models', () {
      final denied = GoogleProvider.googleError(403, {
        'error': {
          'code': 403,
          'message':
              'Your project has been denied access. Please contact support.',
          'status': 'PERMISSION_DENIED',
        },
      });
      expect(denied.code, AiError.denied);
      expect(denied.message, contains('Your project has been denied access.'));
      expect(denied.helpUrl, GoogleProvider.console);

      // Google's link to the fix, e.g. to turn an API on
      final disabled = GoogleProvider.googleError(403, {
        'error': {
          'code': 403,
          'message':
              'YouTube Data API v3 has not been used in project 123 before or '
              'it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/youtube.googleapis.com/overview?project=123 then retry.',
          'status': 'PERMISSION_DENIED',
          'details': [
            {'reason': 'SERVICE_DISABLED'},
          ],
        },
      });
      expect(disabled.code, AiError.denied);
      expect(
        '${disabled.helpUrl}',
        'https://console.developers.google.com/apis/api/youtube.googleapis.com/overview?project=123',
      );

      // A permission unticked on the consent screen: sign in again
      for (final error in [
        {
          'code': 403,
          'message': 'Request had insufficient authentication scopes.',
          'status': 'PERMISSION_DENIED',
          'details': [
            {'reason': 'ACCESS_TOKEN_SCOPE_INSUFFICIENT'},
          ],
        },
        {
          'code': 403,
          'message': 'Insufficient Permission',
          'errors': [
            {'reason': 'insufficientPermissions'},
          ],
        },
      ]) {
        final scope = GoogleProvider.googleError(403, {'error': error});
        expect(scope.code, AiError.signedOut);
        expect(scope.message, contains('allow all permissions'));
      }

      final limit = GoogleProvider.googleError(429, {
        'error': {
          'code': 429,
          'message': 'Quota exceeded',
          'status': 'RESOURCE_EXHAUSTED',
          'details': [
            {
              '@type': 'type.googleapis.com/google.rpc.RetryInfo',
              'retryDelay': '37s',
            },
          ],
        },
      }, now: DateTime(2026, 9, 27, 12));
      expect(limit.code, AiError.limit);
      expect(limit.message, contains('Try again after'));

      final youtube = GoogleProvider.googleError(403, {
        'error': {
          'code': 403,
          'message': 'The request cannot be completed because you have exceeded your quota.',
          'errors': [
            {'reason': 'quotaExceeded', 'domain': 'youtube.quota'},
          ],
        },
      });
      expect(youtube.code, AiError.limit);
      expect(youtube.message, startsWith('YouTube\'s daily search limit'));

      expect(
        GoogleProvider.googleError(404, {
          'error': {'code': 404, 'message': 'models/gemini-9 is not found'},
        }).code,
        AiError.modelUnavailable,
      );
      expect(GoogleProvider.googleError(401, {}).code, AiError.signedOut);
    });

    test('models: Gemini text models, the default first', () {
      final models = GoogleProvider.parseModels(
        jsonEncode({
          'models': [
            {
              'name': 'models/gemini-2.5-pro',
              'displayName': 'Gemini 2.5 Pro',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/gemini-2.5-flash',
              'displayName': 'Gemini 2.5 Flash',
              'supportedGenerationMethods': ['generateContent', 'countTokens'],
            },
            {
              'name': 'models/gemini-2.5-flash-image',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/text-embedding-004',
              'supportedGenerationMethods': ['embedContent'],
            },
            {
              'name': 'models/gemma-3-4b-it',
              'supportedGenerationMethods': ['generateContent'],
            },
          ],
        }),
      );
      expect(models.map((m) => m.id), ['gemini-2.5-flash', 'gemini-2.5-pro']);
    });

    test('makes no pictures', () {
      final google = provider((request, body) async => fail('no request'));
      expect(google.generateImage('i', 'leaf', model: 'x'), isNull);
    });
  });

  // Runs the real Claude Code on this Mac, signed in to the owner's plan:
  // NTS_REAL_CLAUDE=1 flutter test test/ai_providers_test.dart
  group('real Claude Code', () {
    test(
      'respond, picture + JSON, and search',
      () async {
        final claude = ClaudeCodeProvider();
        await claude.refreshStatus();
        expect(
          claude.status.value.isSignedIn,
          isTrue,
          reason: '${claude.status.value}',
        );

        var stopwatch = Stopwatch()..start();
        final partials = <String>[];
        final answer = await claude.respond(
          'real1',
          const AiRequest(
            instructions: 'Answer with only the number.',
            prompt: 'What is 2 + 2?',
          ),
          model: 'haiku',
          onPartial: partials.add,
        );
        // ignore: avoid_print
        print(
          'respond: ${stopwatch.elapsedMilliseconds} ms, '
          '${partials.length} partials, answer "$answer"',
        );
        expect(answer, contains('4'));

        final picture = img.Image(width: 120, height: 60)
          ..clear(img.ColorRgb8(255, 255, 255));
        img.drawLine(
          picture,
          x1: 10,
          y1: 50,
          x2: 110,
          y2: 10,
          color: img.ColorRgb8(0, 0, 0),
          thickness: 3,
        );
        stopwatch = Stopwatch()..start();
        final json = await claude.respond(
          'real2',
          AiRequest(
            instructions: 'Describe the picture.',
            prompt: 'What is drawn?',
            imagePng: img.encodePng(picture),
            jsonSchema:
                '{"type":"object","additionalProperties":false,"properties":'
                '{"shape":{"type":"string"}},"required":["shape"]}',
          ),
          model: 'haiku',
        );
        // ignore: avoid_print
        print('picture + JSON: ${stopwatch.elapsedMilliseconds} ms, $json');
        expect(jsonDecode(json), contains('shape'));

        stopwatch = Stopwatch()..start();
        final links = await claude.search(
          'real3',
          'photosynthesis light reactions',
          kind: .video,
          model: 'haiku',
        );
        // ignore: avoid_print
        print(
          'search: ${stopwatch.elapsedMilliseconds} ms, '
          '${links.map((l) => '${l.title} <${l.url}>').join('; ')}',
        );
        expect(links, isNotEmpty);
        expect(links.every((l) => youTubeId(l.url) != null), isTrue);
      },
      skip: Platform.environment['NTS_REAL_CLAUDE'] != '1',
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

/// A `claude` process printing [lines] of stream-json, then exiting unless
/// it should [hang]. Its stdin goes to [stdinLines].
class _FakeContext extends Fake implements BuildContext;

class FakeProcess implements Process {
  new(this.stdinLines, List<String> lines, {bool hang = false}) {
    _stdin.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(stdinLines.add);
    for (final line in lines) {
      _stdout.add(utf8.encode('$line\n'));
    }
    // Else it keeps running until killed
    if (!hang) _finish(0);
  }

  final List<String> stdinLines;
  // ignore: close_sinks (closed by the code under test)
  final _stdin = StreamController<List<int>>();
  final _stdout = StreamController<List<int>>();
  final _exitCode = Completer<int>();
  var killed = false;

  void _finish(int code) {
    if (_exitCode.isCompleted) return;
    unawaited(_stdout.close());
    _exitCode.complete(code);
  }

  @override
  // ignore: close_sinks (closed by the code under test)
  late final stdin = IOSink(_stdin);

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  int get pid => 1;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    _finish(-15);
    return true;
  }
}
