import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/auth/jwt.dart';
import 'package:nts/data/ai/auth/loopback_server.dart';
import 'package:nts/data/ai/auth/oauth_tokens.dart';
import 'package:nts/data/ai/auth/pkce.dart';
import 'package:nts/data/ai/providers/common.dart';
import 'package:nts/data/version.dart';
import 'package:stow_secure/stow_secure.dart';
import 'package:url_launcher/url_launcher.dart';

/// ChatGPT with the user's own ChatGPT plan, through the "Sign in with
/// ChatGPT" login of OpenAI's open-source Codex (its public client).
///
/// Undocumented and only informally tolerated for personal use, so it may
/// stop working. nts always says it is nts (`originator: nts`): never
/// pretend to be Codex (`codex_cli_rs`), even if a model is refused.
class ChatGptProvider implements AiProvider {
  new(this._tokenStow, {http.Client? client, WebAuth? webAuth})
    : _client = client ?? http.Client(),
      _webAuth = webAuth ?? FlutterWebAuth2.authenticate;

  static final log = Logger('ChatGptProvider');

  static const clientId = 'app_EMoamEEZ73f0CkXaXp7hrann';
  static const scope = 'openid profile email offline_access';
  static final tokenUrl = Uri.https('auth.openai.com', '/oauth/token');
  static const apiBase = 'https://chatgpt.com/backend-api/codex';

  /// The loopback server sends the browser here, which closes the sheet.
  static const callbackScheme = 'nts-auth';

  static const _modelUnavailable =
      'This model isn\'t available to nts right now. Pick another in '
      'Settings.';

  /// When [models] can't ask ChatGPT. gpt-5.5 retires on 2026-10-14.
  static const fallbackModels = [
    AiModel('gpt-6-sol', 'GPT-6 Sol'),
    AiModel('gpt-6-luna', 'GPT-6 Luna'),
    AiModel('gpt-5.4', 'GPT-5.4'),
    AiModel('gpt-5.4-mini', 'GPT-5.4 mini'),
  ];

  /// Paid plans only. They use up the plan's limits 3–5× faster.
  static const imageModels = [
    AiModel('gpt-image-2', 'GPT Image 2', isImageModel: true),
    AiModel('gpt-image-1.5', 'GPT Image 1.5', isImageModel: true),
  ];

  final SecureStow<String> _tokenStow;
  final http.Client _client;
  final WebAuth _webAuth;
  late final _tokens = TokenStore(_tokenStow, refresh: _refresh);

  final _status = ValueNotifier(AiAccountStatus.signedOut);
  final _cancels = Cancels();
  List<AiModel>? _models;

  /// Increases with every sign-in or sign-out, to stop an older one.
  var _attempt = 0;

  /// The browser sign-in's server, closed by [signOut] (Cancel).
  LoopbackServer? _server;

  @override
  AiProviderId get id => .chatgpt;

  @override
  String get displayName => 'ChatGPT';

  @override
  ValueListenable<AiAccountStatus> get status => _status;

  Future<OAuthTokens> _refresh(OAuthTokens current) => requestTokens(
    tokenUrl,
    {
      'grant_type': 'refresh_token',
      'refresh_token': current.refreshToken!,
      'client_id': clientId,
    },
    previous: current,
    client: _client,
  );

  @override
  Future<void> refreshStatus() async {
    if (_status.value.state == .signingIn) return;
    final tokens = await _tokens.load();
    _status.value = tokens == null
        ? AiAccountStatus.signedOut
        : statusOf(tokens);
  }

  /// The `https://api.openai.com/auth` claims: account id and plan.
  /// The access token's are fresher (it is renewed on refresh).
  static Map<String, Object?> _authClaims(OAuthTokens tokens) {
    for (final jwt in [tokens.accessToken, tokens.idToken]) {
      if (jwtClaims(jwt)?['https://api.openai.com/auth'] case final Map auth) {
        return auth.cast();
      }
    }
    return const {};
  }

  @visibleForTesting
  static AiAccountStatus statusOf(OAuthTokens tokens) {
    final id = jwtClaims(tokens.idToken) ?? const {};
    final profile = jwtClaims(
      tokens.accessToken,
    )?['https://api.openai.com/profile'];
    final email =
        id['email'] as String? ??
        (profile is Map ? profile['email'] as String? : null);
    return AiAccountStatus(
      .signedIn,
      label: email,
      plan: _authClaims(tokens)['chatgpt_plan_type'] as String?,
    );
  }

  /// The ChatGPT account (or workspace) the tokens are for.
  @visibleForTesting
  static String? accountId(OAuthTokens tokens) {
    if (_authClaims(tokens)['chatgpt_account_id'] case final String id) {
      return id;
    }
    return switch (jwtClaims(tokens.idToken)) {
      {'chatgpt_account_id': final String id} => id,
      {'organizations': [{'id': final String id}, ...]} => id,
      _ => null,
    };
  }

  bool get _isFreePlan => _status.value.plan == 'free';

  @visibleForTesting
  static Uri authorizeUrl({
    required String redirectUri,
    required Pkce pkce,
    required String state,
  }) => Uri.https('auth.openai.com', '/oauth/authorize', {
    'response_type': 'code',
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'scope': scope,
    'code_challenge': pkce.challenge,
    'code_challenge_method': Pkce.method,
    'id_token_add_organizations': 'true',
    'codex_cli_simplified_flow': 'true',
    'state': state,
    'originator': 'nts',
  });

  @override
  Future<void> signIn(BuildContext context) => signInWithBrowser();

  /// OpenAI's own sign-in page in the system's sign-in sheet (where
  /// "Continue with Google" works), then back through a one-time server on
  /// localhost. If another app (e.g. Codex) has its ports, the user can
  /// [signInWithDeviceCode] instead.
  Future<void> signInWithBrowser() => _signingIn(() async {
    final pkce = Pkce.generate();
    final state = randomUrlSafe();
    await _server?.close(); // an earlier sign-in's
    final LoopbackServer server;
    try {
      server = _server = await LoopbackServer.start(
        state: state,
        doneRedirect: Uri.parse('$callbackScheme://done'),
      );
    } on AiError catch (e) {
      log.info('No loopback server: $e');
      throw const AiError(
        AiError.failed,
        'Couldn\'t start sign-in: another app (e.g. Codex) is using its '
        'ports. Close it and try again, or use a code instead.',
      );
    }
    try {
      final url = authorizeUrl(
        redirectUri: server.redirectUri,
        pkce: pkce,
        state: state,
      );
      // Closing the sheet before the callback cancels the server; a sheet
      // that couldn't open says so
      unawaited(
        _webAuth(url: url.toString(), callbackUrlScheme: callbackScheme).then(
          (_) {},
          onError: (Object e) {
            if (e is PlatformException && e.code != 'CANCELED') {
              log.warning('No sign-in sheet: $e');
              return server.close(
                const AiError(
                  AiError.failed,
                  'Couldn\'t open the sign-in page. Try again, or use a code '
                  'instead.',
                ),
              );
            }
            return server.close();
          },
        ),
      );
      final query = await server.result;
      return await requestTokens(tokenUrl, {
        'grant_type': 'authorization_code',
        'code': query['code']!,
        'redirect_uri': server.redirectUri,
        'client_id': clientId,
        'code_verifier': pkce.verifier,
      }, client: _client);
    } finally {
      if (_server == server) _server = null;
      await server.close();
    }
  });

  /// Signs in with a code typed at auth.openai.com/codex/device, e.g. when
  /// the browser can't reach this device. The code is shown in
  /// [status]'s detail and copied. Needs "device code" sign-in turned on
  /// in ChatGPT → Settings → Security.
  Future<void> signInWithDeviceCode() => _signingIn(_deviceCode);

  Future<OAuthTokens> _deviceCode() async {
    final attempt = _attempt;
    final start = await _client.post(
      Uri.https('auth.openai.com', '/api/accounts/deviceauth/usercode'),
      headers: {'Content-Type': 'application/json', 'User-Agent': userAgent},
      body: jsonEncode({'client_id': clientId}),
    );
    final json = jsonObject(start.body);
    final deviceAuthId = json['device_auth_id'];
    final userCode = json['user_code'] ?? json['usercode'];
    if (start.statusCode != HttpStatus.ok ||
        deviceAuthId is! String ||
        userCode is! String) {
      throw const AiError(
        AiError.failed,
        'Couldn\'t get a sign-in code. In ChatGPT → Settings → Security, '
        'turn on device code sign-in for Codex, then try again.',
      );
    }
    final interval = Duration(
      seconds: (int.tryParse('${json['interval']}') ?? 5).clamp(1, 60),
    );
    final verifyUrl = Uri.https('auth.openai.com', '/codex/device');
    _status.value = AiAccountStatus(
      .signingIn,
      detail: 'Enter the code $userCode at auth.openai.com/codex/device',
    );
    unawaited(
      Clipboard.setData(ClipboardData(text: userCode)).catchError((_) {}),
    );
    unawaited(launchUrl(verifyUrl).catchError((_) => false));

    final deadline = DateTime.now().add(const Duration(minutes: 15));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      if (attempt != _attempt) throw cancelledError;
      final poll = await _client.post(
        Uri.https('auth.openai.com', '/api/accounts/deviceauth/token'),
        headers: {'Content-Type': 'application/json', 'User-Agent': userAgent},
        body: jsonEncode({
          'device_auth_id': deviceAuthId,
          'user_code': userCode,
        }),
      );
      // Not approved yet
      if (poll.statusCode == HttpStatus.forbidden ||
          poll.statusCode == HttpStatus.notFound) {
        continue;
      }
      final result = jsonObject(poll.body);
      if (poll.statusCode != HttpStatus.ok ||
          result['authorization_code'] is! String ||
          result['code_verifier'] is! String) {
        throw AiError(AiError.failed, 'Sign-in failed (${poll.statusCode}).');
      }
      // The approved page stays open in iOS's in-app Safari over Settings
      if (Platform.isIOS) unawaited(closeInAppWebView().catchError((_) {}));
      return requestTokens(tokenUrl, {
        'grant_type': 'authorization_code',
        'code': result['authorization_code']! as String,
        'redirect_uri': 'https://auth.openai.com/deviceauth/callback',
        'client_id': clientId,
        'code_verifier': result['code_verifier']! as String,
      }, client: _client);
    }
    throw const AiError(AiError.cancelled, 'Sign-in took too long. Try again.');
  }

  Future<void> _signingIn(Future<OAuthTokens> Function() signIn) async {
    final attempt = ++_attempt;
    _status.value = const AiAccountStatus(
      .signingIn,
      detail: 'Finish signing in to ChatGPT in the browser.',
    );
    try {
      final tokens = await signIn();
      if (attempt != _attempt) return;
      await _tokens.save(tokens);
      _models = null;
      _status.value = statusOf(tokens);
    } on Object catch (e) {
      if (attempt != _attempt) return;
      final tokens = await _tokens.load();
      _status.value = tokens == null
          ? AiAccountStatus(
              .signedOut,
              detail: e is AiError && e.code != AiError.cancelled
                  ? e.message
                  : null,
            )
          : statusOf(tokens);
      if (e is AiError) rethrow;
      log.warning('ChatGPT sign-in failed: $e');
      throw const AiError(AiError.failed, 'Sign-in failed. Try again.');
    }
  }

  /// Also cancels a sign-in: its server stops (so no code is exchanged)
  /// and a code sign-in stops waiting.
  @override
  Future<void> signOut() async {
    _attempt++;
    _models = null;
    final server = _server;
    _server = null;
    await server?.close();
    await _tokens.clear();
    _status.value = AiAccountStatus.signedOut;
  }

  @override
  Future<List<AiModel>> models() async {
    if (!_status.value.isSignedIn) return fallbackModels;
    var text = _models;
    if (text == null) {
      try {
        final response = await _send(
          'models',
          'GET',
          'models?client_version=$buildName',
          // An undocumented list; may refuse nts without the tokens being bad
          maySignOut: false,
        );
        text = parseModels(await response.stream.bytesToString());
        if (text.isNotEmpty) _models = text;
      } on AiError catch (e) {
        log.info('No model list from ChatGPT: $e');
      }
      if (text == null || text.isEmpty) text = fallbackModels;
    }
    return [...text, if (!_isFreePlan) ...imageModels];
  }

  /// The text models of a Codex `/models` reply, best first.
  @visibleForTesting
  static List<AiModel> parseModels(String body) {
    final entries = [
      if (jsonObject(body)['models'] case final List models)
        for (final model in models)
          if (model case {'slug': final String slug} when slug.isNotEmpty)
            if (model['supported_in_api'] != false &&
                !const {'hide', 'hidden'}.contains(model['visibility']))
              model,
    ];
    int priority(Map model) => (model['priority'] as num?)?.toInt() ?? 10000;
    entries.sort((a, b) => priority(a).compareTo(priority(b)));
    return [
      for (final model in entries)
        AiModel(
          model['slug'] as String,
          model['display_name'] as String? ?? model['slug'] as String,
        ),
    ];
  }

  /// The Responses API request for [req]. Also for the models Codex marks
  /// `use_responses_lite`: Codex sends those its instructions as a
  /// developer message with an internal header, but plain `instructions`
  /// are followed too, and nts doesn't imitate Codex's internal transport.
  @visibleForTesting
  static Map<String, Object?> requestBody(AiRequest req, String model) => {
    'model': model,
    'instructions': [
      req.instructions,
      if (req.restrictSearchToDomain case final domain?)
        'Only use search results from $domain.',
    ].join('\n'),
    'input': [
      {
        'type': 'message',
        'role': 'user',
        'content': [
          if (req.prompt.trim().isNotEmpty || req.imagePng == null)
            {'type': 'input_text', 'text': req.prompt},
          if (req.imagePng case final png?)
            {
              'type': 'input_image',
              'image_url': 'data:image/png;base64,${base64Encode(png)}',
            },
        ],
      },
    ],
    if (req.webSearch)
      'tools': [
        {'type': 'web_search'},
      ],
    if (req.jsonSchema case final schema?)
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'answer',
          'schema': cleanSchema(jsonDecode(schema)),
          'strict': false,
        },
      },
    'reasoning': {'effort': 'low'},
    'stream': true,
    'store': false,
  };

  @override
  Future<String> respond(
    String requestId,
    AiRequest req, {
    required String model,
    void Function(String partial)? onPartial,
  }) async {
    final answer = await _respond(requestId, req, model, onPartial);
    return answer.text;
  }

  @override
  Future<List<AiLink>> search(
    String requestId,
    String query, {
    required AiSearchKind kind,
    required String model,
  }) async {
    final answer = await _respond(
      requestId,
      AiRequest(
        instructions:
            '${searchInstructions(kind)} Write one line per result: its '
            'title, then its link.',
        prompt: query,
        webSearch: true,
        restrictSearchToDomain: kind == .video ? 'youtube.com' : null,
      ),
      model,
      null,
    );
    // Cited links came from the search; others may be made up
    return keepLinks(
      answer.citations.isNotEmpty ? answer.citations : linksInText(answer.text),
      kind,
    );
  }

  Future<({String text, List<AiLink> citations})> _respond(
    String id,
    AiRequest req,
    String model,
    void Function(String)? onPartial,
  ) async {
    final response = await _send(
      id,
      'POST',
      'responses',
      body: requestBody(req, model),
      stream: true,
    );
    // Each output message's text, by its place in the output. Newer models
    // may first send "commentary" messages (a preamble): only the answer
    // counts.
    final messages = <Object?, String>{};
    final commentary = <Object?>{};
    String answer() => [
      for (final MapEntry(:key, :value) in messages.entries)
        if (!commentary.contains(key) && value.trim().isNotEmpty) value,
    ].join('\n\n');
    Object? place(Map<String, Object?> event) =>
        event['output_index'] ??
        event['item_id'] ??
        (event['item'] is Map ? (event['item']! as Map)['id'] : null);
    final citations = <AiLink>[];
    void cite(Object? annotation) {
      if (annotation case {'type': 'url_citation', 'url': final String url}
          when Uri.tryParse(url)?.hasAuthority ?? false) {
        citations.add(
          linkFor(annotation['title'] as String? ?? '', Uri.parse(url)),
        );
      }
    }

    try {
      await for (final data in sseData(response.stream)) {
        final event = jsonObject(data);
        switch (event['type']) {
          case 'response.output_text.delta':
            final key = place(event);
            messages[key] = '${messages[key] ?? ''}${event['delta'] ?? ''}';
            if (!commentary.contains(key)) onPartial?.call(answer());
          case 'response.output_text.annotation.added':
            cite(event['annotation']);
          case 'response.output_item.added':
            if (event['item'] case {'type': 'message', 'phase': 'commentary'}) {
              commentary.add(place(event));
            }
          case 'response.output_item.done':
            if (event['item'] case {
              'type': 'message',
              'content': final List content,
            }) {
              final key = place(event);
              if ((event['item']! as Map)['phase'] == 'commentary') {
                commentary.add(key);
              }
              final text = StringBuffer();
              for (final part in content) {
                if (part case {'type': 'output_text'}) {
                  text.write(part['text'] as String? ?? '');
                  (part['annotations'] as List? ?? const []).forEach(cite);
                }
              }
              if (text.isNotEmpty) messages[key] = text.toString();
            }
          case 'response.failed' || 'response.incomplete' || 'error':
            final error = event['response'] is Map
                ? (event['response']! as Map)['error'] ??
                      (event['response']! as Map)['incomplete_details']
                : event['error'] ?? event;
            throw chatGptError(0, {'error': error});
        }
      }
    } on http.RequestAbortedException {
      throw cancelledError;
    } on http.ClientException catch (e) {
      log.warning('ChatGPT stream broke: $e');
      throw const AiError(AiError.failed, 'Lost the connection to ChatGPT.');
    }
    _cancels.check(id);
    return (text: answer(), citations: citations);
  }

  /// A picture from gpt-image, on paid plans. Base64 PNG in the reply.
  @override
  Future<Uint8List>? generateImage(
    String requestId,
    String prompt, {
    required String model,
  }) => _isFreePlan ? null : _generateImage(requestId, prompt, model);

  Future<Uint8List> _generateImage(
    String id,
    String prompt,
    String model,
  ) async {
    final response = await _send(
      id,
      'POST',
      'images/generations',
      body: {
        'model': model,
        'prompt': prompt,
        'size': '1024x1024',
        'quality': 'medium',
        'background': 'opaque',
      },
    );
    final json = jsonObject(await response.stream.bytesToString());
    _cancels.check(id);
    if (json['data'] case [{'b64_json': final String b64}, ...]) {
      return base64Decode(b64);
    }
    throw const AiError(AiError.failed, 'ChatGPT didn\'t make a picture.');
  }

  @override
  Future<void> cancel(String requestId) async => _cancels.cancel(requestId);

  /// Sends a request to the Codex backend as the signed-in user, refreshing
  /// the access token once if it's rejected, then signing out if
  /// [maySignOut]. Throws [AiError].
  Future<http.StreamedResponse> _send(
    String id,
    String method,
    String path, {
    Object? body,
    bool stream = false,
    bool maySignOut = true,
  }) async {
    String? rejected;
    while (true) {
      _cancels.check(id);
      final String token;
      try {
        token = await _tokens.accessToken(rejected: rejected);
      } on AiError catch (e) {
        if (e.code == AiError.signedOut) {
          _status.value = const AiAccountStatus(
            .signedOut,
            detail: 'Signed out of ChatGPT. Sign in again in Settings.',
          );
        }
        rethrow;
      }
      final request =
          http.AbortableRequest(
              method,
              Uri.parse('$apiBase/$path'),
              abortTrigger: _cancels.trigger(id),
            )
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              if (_tokens.tokens case final tokens?)
                'ChatGPT-Account-Id': ?accountId(tokens),
              'originator': 'nts',
              'User-Agent': userAgent,
              'Accept': stream ? 'text/event-stream' : 'application/json',
              if (body != null) 'Content-Type': 'application/json',
            });
      if (body != null) request.body = jsonEncode(body);

      final http.StreamedResponse response;
      try {
        response = await _client
            .send(request)
            .timeout(const Duration(seconds: 60));
      } on http.RequestAbortedException {
        throw cancelledError;
      } on TimeoutException {
        throw const AiError(
          AiError.failed,
          'ChatGPT took too long. Try again.',
        );
      } on Exception catch (e) {
        log.warning('ChatGPT request failed: $e');
        throw const AiError(
          AiError.failed,
          'Couldn\'t reach ChatGPT. Check your connection.',
        );
      }
      if (response.statusCode == HttpStatus.unauthorized && rejected == null) {
        await response.stream.drain<void>();
        rejected = token;
        continue;
      }
      if (response.statusCode >= 400) {
        final text = await response.stream.bytesToString();
        final error = chatGptError(response.statusCode, jsonObject(text));
        if (error.code == AiError.signedOut && maySignOut) {
          await _tokens.clear();
          _status.value = AiAccountStatus(.signedOut, detail: error.message);
        }
        throw error;
      }
      return response;
    }
  }

  /// The [AiError] for a failed ChatGPT request: HTTP [status] (0 for an
  /// error event in a stream) and the reply's [json].
  @visibleForTesting
  static AiError chatGptError(
    int status,
    Map<String, Object?> json, {
    DateTime? now,
  }) {
    final error = json['error'] is Map
        ? (json['error']! as Map).cast<String, Object?>()
        : json;
    final code = '${error['code'] ?? error['type'] ?? error['reason'] ?? ''}';
    final message = '${error['message'] ?? json['detail'] ?? ''}'.trim();
    final lower = '$code $message'.toLowerCase();
    if (status == HttpStatus.tooManyRequests ||
        lower.contains('usage_limit') ||
        lower.contains('usage limit') ||
        lower.contains('rate_limit')) {
      final inSeconds = error['resets_in_seconds'];
      final reset =
          epochSeconds(error['resets_at']) ??
          (inSeconds is num
              ? (now ?? DateTime.now()).add(
                  Duration(seconds: inSeconds.round()),
                )
              : null);
      return AiError(
        AiError.limit,
        'ChatGPT plan limit reached.${tryAgainAfter(reset)}',
      );
    }
    if (code == 'model_not_found' ||
        lower.contains('model') &&
            (lower.contains('not found') ||
                lower.contains('not supported') ||
                lower.contains('does not exist') ||
                lower.contains('unsupported'))) {
      return const AiError(AiError.modelUnavailable, _modelUnavailable);
    }
    if (status == HttpStatus.unauthorized) {
      return const AiError(
        AiError.signedOut,
        'Signed out of ChatGPT. Sign in again in Settings.',
      );
    }
    if (status == HttpStatus.forbidden) {
      return AiError(
        AiError.denied,
        message.isEmpty ? 'ChatGPT refused this request.' : 'ChatGPT: $message',
      );
    }
    return AiError(
      AiError.failed,
      message.isEmpty
          ? 'ChatGPT couldn\'t answer${status == 0 ? '' : ' (error $status)'}.'
          : 'ChatGPT: $message',
    );
  }
}
