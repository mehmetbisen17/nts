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
import 'package:nts/data/ai/auth/oauth_tokens.dart';
import 'package:nts/data/ai/auth/pkce.dart';
import 'package:nts/data/ai/providers/common.dart';
import 'package:stow/stow.dart';
import 'package:stow_secure/stow_secure.dart';

/// Gemini (free Flash tier) and YouTube search through the user's own
/// Google Cloud project: a Google sign-in with its iOS-type OAuth client.
/// Not the Gemini app subscription, which no app may use.
///
/// Web sources are plain links, not Google Search grounding: grounded
/// answers must show Google's search suggestions unedited.
class GoogleProvider implements AiProvider {
  new(
    this._tokenStow, {
    required this._clientId,
    required this._projectId,
    http.Client? client,
    WebAuth? webAuth,
  }) : _client = client ?? http.Client(),
       _webAuth = webAuth ?? FlutterWebAuth2.authenticate {
    _clientId.addListener(_setupChanged);
    _projectId.addListener(_setupChanged);
  }

  static final log = Logger('GoogleProvider');

  static const scopes = [
    'openid',
    'email',
    'https://www.googleapis.com/auth/generative-language.retriever',
    'https://www.googleapis.com/auth/youtube.readonly',
  ];
  static final tokenUrl = Uri.https('oauth2.googleapis.com', '/token');
  static const geminiHost = 'generativelanguage.googleapis.com';

  static const defaultModel = 'gemini-2.5-flash';
  static const fallbackModels = [
    AiModel(defaultModel, 'Gemini 2.5 Flash'),
    AiModel('gemini-2.5-flash-lite', 'Gemini 2.5 Flash-Lite'),
    AiModel('gemini-2.5-pro', 'Gemini 2.5 Pro'),
  ];

  static const setupNeeded =
      'Set up Google in Settings → AI accounts: paste your Cloud project\'s '
      'client ID and project ID.';
  static final console = Uri.https('console.cloud.google.com', '/');

  final SecureStow<String> _tokenStow;
  final ValueListenable<String> _clientId;
  final ValueListenable<String> _projectId;
  final http.Client _client;
  final WebAuth _webAuth;
  late final _tokens = TokenStore(_tokenStow, refresh: _refresh);

  final _status = ValueNotifier(
    const AiAccountStatus(.unavailable, detail: setupNeeded),
  );
  final _cancels = Cancels();
  List<AiModel>? _models;
  var _attempt = 0;

  @override
  AiProviderId get id => .google;

  @override
  String get displayName => 'Google (your Cloud project)';

  @override
  ValueListenable<AiAccountStatus> get status => _status;

  String get _clientIdValue => _clientId.value.trim();
  String get _projectIdValue => _projectId.value.trim();
  bool get _isSetUp =>
      redirectScheme(_clientIdValue) != null && _projectIdValue.isNotEmpty;

  void _setupChanged() {
    _models = null;
    unawaited(refreshStatus());
  }

  /// The custom URL scheme Google redirects an iOS client to: its reversed
  /// client ID, e.g. `com.googleusercontent.apps.123-abc`.
  @visibleForTesting
  static String? redirectScheme(String clientId) {
    final prefix = clientId.trim().replaceFirst(
      RegExp(r'\.apps\.googleusercontent\.com$'),
      '',
    );
    if (!RegExp(r'^[\w-]+$').hasMatch(prefix)) return null;
    return 'com.googleusercontent.apps.$prefix';
  }

  static String _fullClientId(String clientId) =>
      clientId.endsWith('.apps.googleusercontent.com')
      ? clientId
      : '$clientId.apps.googleusercontent.com';

  @visibleForTesting
  static Uri authorizeUrl({
    required String clientId,
    required Pkce pkce,
    required String state,
  }) => Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': _fullClientId(clientId),
    'redirect_uri': '${redirectScheme(clientId)}:/oauth2redirect',
    'response_type': 'code',
    'scope': scopes.join(' '),
    'code_challenge': pkce.challenge,
    'code_challenge_method': Pkce.method,
    'state': state,
    'access_type': 'offline',
    // Always a refresh token, also when signing in again
    'prompt': 'consent',
  });

  Future<OAuthTokens> _refresh(OAuthTokens current) => requestTokens(
    tokenUrl,
    {
      'client_id': _fullClientId(_clientIdValue),
      'grant_type': 'refresh_token',
      'refresh_token': current.refreshToken!,
    },
    previous: current,
    client: _client,
  );

  @visibleForTesting
  static AiAccountStatus statusOf(OAuthTokens tokens) => AiAccountStatus(
    .signedIn,
    label: jwtClaims(tokens.idToken)?['email'] as String?,
  );

  @override
  Future<void> refreshStatus() async {
    if (_status.value.state == .signingIn) return;
    for (final setup in [_clientId, _projectId]) {
      if (setup case final Stow stow) await stow.waitUntilRead();
    }
    if (!_isSetUp) {
      _status.value = const AiAccountStatus(.unavailable, detail: setupNeeded);
      return;
    }
    final tokens = await _tokens.load();
    // Tokens of another client (the setup changed) can't be refreshed
    final audience = jwtClaims(tokens?.idToken)?['aud'];
    if (tokens != null &&
        audience is String &&
        audience != _fullClientId(_clientIdValue)) {
      await _tokens.clear();
      _status.value = AiAccountStatus.signedOut;
      return;
    }
    _status.value = tokens == null
        ? AiAccountStatus.signedOut
        : statusOf(tokens);
  }

  @override
  Future<void> signIn(BuildContext context) => signInWithBrowser();

  /// Google's own sign-in page in the system's sign-in sheet (passkeys and
  /// 2-step verification work there). Google shows "Google hasn't verified
  /// this app" for a personal project: Advanced → Continue.
  Future<void> signInWithBrowser() async {
    if (!_isSetUp) throw const AiError(AiError.setupNeeded, setupNeeded);
    final attempt = ++_attempt;
    final clientId = _clientIdValue;
    final scheme = redirectScheme(clientId)!;
    final pkce = Pkce.generate();
    final state = randomUrlSafe();
    _status.value = const AiAccountStatus(
      .signingIn,
      detail:
          'Finish signing in to Google in the browser. If it says Google '
          'hasn\'t verified this app, tap Advanced, then Continue.',
    );
    try {
      final String callback;
      try {
        callback = await _webAuth(
          url: authorizeUrl(
            clientId: clientId,
            pkce: pkce,
            state: state,
          ).toString(),
          callbackUrlScheme: scheme,
        );
      } on PlatformException catch (e) {
        if (e.code == 'CANCELED') throw cancelledError;
        log.warning('Google sign-in sheet failed: ${e.code}');
        throw const AiError(AiError.failed, 'Sign-in failed. Try again.');
      }
      final query = Uri.parse(callback).queryParameters;
      if (query['state'] != state) {
        throw const AiError(AiError.failed, 'Sign-in failed. Try again.');
      }
      if (query['error'] case final error?) {
        throw error == 'access_denied'
            ? const AiError(AiError.denied, 'Sign-in was cancelled.')
            : AiError(AiError.failed, 'Sign-in failed ($error).');
      }
      final code = query['code'];
      if (code == null) {
        throw const AiError(AiError.failed, 'Sign-in failed. Try again.');
      }
      final tokens = await requestTokens(tokenUrl, {
        'client_id': _fullClientId(clientId),
        'code': code,
        'code_verifier': pkce.verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': '$scheme:/oauth2redirect',
      }, client: _client);
      if (attempt != _attempt) return;
      await _tokens.save(tokens);
      _models = null;
      _status.value = statusOf(tokens);
    } on AiError catch (e) {
      if (attempt != _attempt) return;
      final tokens = await _tokens.load();
      _status.value = tokens != null
          ? statusOf(tokens)
          : AiAccountStatus(
              .signedOut,
              detail: e.code == AiError.cancelled ? null : e.message,
            );
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    _attempt++;
    _models = null;
    await _tokens.clear();
    await refreshStatus();
  }

  @override
  Future<List<AiModel>> models() async {
    if (!_status.value.isSignedIn) return fallbackModels;
    if (_models case final models?) return models;
    try {
      final response = await _send(
        'models',
        'GET',
        Uri.https(geminiHost, '/v1beta/models', {'pageSize': '1000'}),
      );
      final models = parseModels(await response.stream.bytesToString());
      if (models.isNotEmpty) return _models = models;
    } on AiError catch (e) {
      log.info('No model list from Google: $e');
    }
    return fallbackModels;
  }

  /// The text models of a `GET /v1beta/models` reply, [defaultModel] first.
  @visibleForTesting
  static List<AiModel> parseModels(String body) {
    final models = [
      if (jsonObject(body)['models'] case final List list)
        for (final model in list)
          if (model case {
            'name': final String name,
            'supportedGenerationMethods': final List methods,
          })
            if (name.startsWith('models/gemini') &&
                methods.contains('generateContent') &&
                !RegExp('image|tts|audio|live|embedding|native').hasMatch(name))
              AiModel(
                name.substring('models/'.length),
                model['displayName'] as String? ?? name.substring(7),
              ),
    ];
    final index = models.indexWhere((model) => model.id == defaultModel);
    if (index > 0) models.insert(0, models.removeAt(index));
    return models;
  }

  /// The generateContent request for [req]. [AiRequest.webSearch] isn't
  /// used: see [GoogleProvider].
  @visibleForTesting
  static Map<String, Object?> requestBody(AiRequest req) => {
    'systemInstruction': {
      'parts': [
        {'text': req.instructions},
      ],
    },
    'contents': [
      {
        'role': 'user',
        'parts': [
          if (req.prompt.trim().isNotEmpty || req.imagePng == null)
            {'text': req.prompt},
          if (req.imagePng case final png?)
            {
              'inlineData': {
                'mimeType': 'image/png',
                'data': base64Encode(png),
              },
            },
        ],
      },
    ],
    if (req.jsonSchema case final schema?)
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseJsonSchema': cleanSchema(jsonDecode(schema)),
      },
  };

  @override
  Future<String> respond(
    String requestId,
    AiRequest req, {
    required String model,
    void Function(String partial)? onPartial,
  }) async {
    final response = await _send(
      requestId,
      'POST',
      Uri.https(
        geminiHost,
        '/v1beta/models/${Uri.encodeComponent(model)}:streamGenerateContent',
        {'alt': 'sse'},
      ),
      body: requestBody(req),
    );
    final text = StringBuffer();
    try {
      await for (final data in sseData(response.stream)) {
        final chunk = jsonObject(data);
        if (chunk['error'] is Map) throw googleError(0, chunk);
        if (chunk['promptFeedback'] case {'blockReason': final String reason}) {
          throw AiError(
            AiError.denied,
            'Gemini won\'t answer this (${reason.toLowerCase()}).',
          );
        }
        if (chunk['candidates'] case [
          {'content': {'parts': final List parts}},
          ...,
        ]) {
          for (final part in parts) {
            if (part case {'text': final String delta}
                when part['thought'] != true) {
              text.write(delta);
            }
          }
          onPartial?.call(text.toString());
        }
      }
    } on http.RequestAbortedException {
      throw cancelledError;
    } on http.ClientException catch (e) {
      log.warning('Gemini stream broke: $e');
      throw const AiError(AiError.failed, 'Lost the connection to Google.');
    }
    _cancels.check(requestId);
    if (text.isEmpty) {
      throw const AiError(AiError.failed, 'Gemini didn\'t give an answer.');
    }
    return text.toString();
  }

  /// Google's free tier here makes no pictures.
  @override
  Future<Uint8List>? generateImage(
    String requestId,
    String prompt, {
    required String model,
  }) => null;

  @override
  Future<List<AiLink>> search(
    String requestId,
    String query, {
    required AiSearchKind kind,
    required String model,
  }) async {
    if (kind == .video) return _searchYouTube(requestId, query);

    final json = await respond(
      requestId,
      AiRequest(
        instructions:
            '${searchInstructions(kind)} You can\'t search, so only give '
            'pages you are sure exist, like Wikipedia articles and '
            'well-known textbook or university pages.',
        prompt: 'Topic: $query',
        jsonSchema: linksSchema,
      ),
      model: model,
    );
    final language = PlatformDispatcher.instance.locale.languageCode;
    return keepLinks([
      ...linksFromJson(json),
      // Always works, unlike links the model remembers
      linkFor(
        'Search Wikipedia for “$query”',
        Uri.https('$language.wikipedia.org', '/w/index.php', {'search': query}),
      ),
    ], kind);
  }

  /// Official YouTube search (Data API v3; 100 free searches a day).
  Future<List<AiLink>> _searchYouTube(String id, String query) async {
    final response = await _send(
      id,
      'GET',
      Uri.https('www.googleapis.com', '/youtube/v3/search', {
        'part': 'snippet',
        'type': 'video',
        'maxResults': '8',
        'safeSearch': 'moderate',
        'q': query,
      }),
      quotaProject: false,
    );
    final body = await response.stream.bytesToString();
    _cancels.check(id);
    return keepLinks(parseYouTube(body), .video);
  }

  /// The videos of a YouTube `search.list` reply.
  @visibleForTesting
  static List<AiLink> parseYouTube(String body) => [
    if (jsonObject(body)['items'] case final List items)
      for (final item in items)
        if (item case {
          'id': {'videoId': final String videoId},
          'snippet': final Map snippet,
        })
          linkFor(
            _unescapeHtml(snippet['title'] as String? ?? ''),
            Uri.https('www.youtube.com', '/watch', {'v': videoId}),
            source: _unescapeHtml(
              snippet['channelTitle'] as String? ?? 'YouTube',
            ),
            thumbnail: switch (snippet['thumbnails']) {
              {'medium': {'url': final String url}} ||
              {'high': {'url': final String url}} ||
              {'default': {'url': final String url}} => Uri.tryParse(url),
              _ => null,
            },
          ),
  ];

  /// YouTube titles come HTML-escaped, e.g. `Rock &amp; Roll`.
  static String _unescapeHtml(String text) => text.replaceAllMapped(
    RegExp(r'&(#\d+|#x[0-9a-fA-F]+|amp|quot|apos|lt|gt);'),
    (match) => switch (match[1]!) {
      'amp' => '&',
      'quot' => '"',
      'apos' => "'",
      'lt' => '<',
      'gt' => '>',
      final code when code.startsWith('#x') => String.fromCharCode(
        int.parse(code.substring(2), radix: 16),
      ),
      final code => String.fromCharCode(int.parse(code.substring(1))),
    },
  );

  @override
  Future<void> cancel(String requestId) async => _cancels.cancel(requestId);

  /// Sends a request as the signed-in user, refreshing the access token
  /// once if it's rejected. Gemini calls are billed to (and allowed by)
  /// the user's project through `x-goog-user-project`. Throws [AiError].
  Future<http.StreamedResponse> _send(
    String id,
    String method,
    Uri url, {
    Object? body,
    bool quotaProject = true,
  }) async {
    if (!_isSetUp) throw const AiError(AiError.setupNeeded, setupNeeded);
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
            detail: 'Signed out of Google. Sign in again in Settings.',
          );
        }
        rethrow;
      }
      final request =
          http.AbortableRequest(method, url, abortTrigger: _cancels.trigger(id))
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              if (quotaProject) 'x-goog-user-project': _projectIdValue,
              'User-Agent': userAgent,
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
        throw const AiError(AiError.failed, 'Google took too long. Try again.');
      } on Exception catch (e) {
        log.warning('Google request failed: $e');
        throw const AiError(
          AiError.failed,
          'Couldn\'t reach Google. Check your connection.',
        );
      }
      if (response.statusCode == HttpStatus.unauthorized && rejected == null) {
        await response.stream.drain<void>();
        rejected = token;
        continue;
      }
      if (response.statusCode >= 400) {
        final error = googleError(
          response.statusCode,
          jsonObject(await response.stream.bytesToString()),
        );
        if (error.code == AiError.signedOut) {
          await _tokens.clear();
          _status.value = AiAccountStatus(.signedOut, detail: error.message);
        }
        throw error;
      }
      return response;
    }
  }

  /// The [AiError] for a failed Google request: HTTP [status] (0 for an
  /// error in a stream) and the reply's [json].
  @visibleForTesting
  static AiError googleError(
    int status,
    Map<String, Object?> json, {
    DateTime? now,
  }) {
    final error = json['error'] is Map
        ? (json['error']! as Map).cast<String, Object?>()
        : const <String, Object?>{};
    final code = (error['code'] as num?)?.toInt() ?? status;
    final message = (error['message'] as String? ?? '').trim();
    final details = error['details'] is List
        ? error['details']! as List
        : const [];
    // e.g. SERVICE_DISABLED, or YouTube's quotaExceeded
    final reasons = [
      error['status'],
      for (final detail in details)
        if (detail is Map) detail['reason'],
      if (error['errors'] case final List errors)
        for (final e in errors)
          if (e is Map) e['reason'],
    ].whereType<String>().toSet();
    final retryDelay = [
      for (final detail in details)
        if (detail case {'retryDelay': final String delay})
          int.tryParse(delay.replaceFirst(RegExp(r's$'), '').split('.').first),
    ].nonNulls.firstOrNull;

    if (code == HttpStatus.unauthorized ||
        reasons.contains('UNAUTHENTICATED')) {
      return const AiError(
        AiError.signedOut,
        'Signed out of Google. Sign in again in Settings.',
      );
    }
    if (code == HttpStatus.tooManyRequests ||
        reasons.contains('RESOURCE_EXHAUSTED') ||
        reasons.contains('quotaExceeded') ||
        reasons.contains('rateLimitExceeded')) {
      final reset = retryDelay == null
          ? null
          : (now ?? DateTime.now()).add(Duration(seconds: retryDelay));
      return AiError(
        AiError.limit,
        '${reasons.contains('quotaExceeded') ? 'YouTube\'s daily search limit' : 'Google\'s free limit'} '
        'for your project is used up.${tryAgainAfter(reset)}',
      );
    }
    if (code == HttpStatus.notFound &&
        message.toLowerCase().contains('model')) {
      return const AiError(
        AiError.modelUnavailable,
        'This Gemini model isn\'t available to your project. Pick another in '
        'Settings.',
      );
    }
    // A permission unticked on Google's consent screen
    if (reasons.contains('ACCESS_TOKEN_SCOPE_INSUFFICIENT') ||
        reasons.contains('insufficientPermissions') ||
        message.toLowerCase().contains('insufficient authentication scopes')) {
      return const AiError(
        AiError.signedOut,
        'Sign in to Google again and allow all permissions.',
      );
    }
    if (code == HttpStatus.forbidden || reasons.contains('PERMISSION_DENIED')) {
      // e.g. "Your project has been denied access", billing or API not on.
      // Google's message may link to the fix, e.g. to turn an API on.
      final link = RegExp(
        r'https://console\.(?:cloud|developers)\.google\.com/\S*',
      ).firstMatch(message)?[0]?.replaceFirst(RegExp(r'[.,;)]+$'), '');
      return AiError(
        AiError.denied,
        message.isEmpty ? 'Google denied access to your project.' : message,
        helpUrl: link == null ? console : Uri.tryParse(link) ?? console,
      );
    }
    return AiError(
      AiError.failed,
      message.isEmpty
          ? 'Google couldn\'t answer${code == 0 ? '' : ' (error $code)'}.'
          : 'Google: $message',
    );
  }
}
