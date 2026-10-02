import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/providers/common.dart';

typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment,
});

/// Claude through the owner's own, unmodified Claude Code program on this
/// Mac (`claude -p`), signed in to their Claude plan. nts never sees or
/// stores Claude's tokens: Claude Code signs in and calls Claude itself.
///
/// Never add `--bare`, `CLAUDE_CONFIG_DIR` or `--console`: each replaces the
/// plan's login with per-use API billing.
class ClaudeCodeProvider implements AiProvider {
  new({ProcessStarter? start, this._binary, bool? isMac})
    : _start = start ?? Process.start,
      _isMac = isMac ?? Platform.isMacOS {
    if (!_isMac)
      _status.value = const AiAccountStatus(
        .unavailable,
        detail: notOnThisDevice,
      );
  }

  static final log = Logger('ClaudeCodeProvider');

  static const notOnThisDevice =
      'Claude runs through Claude Code on your Mac and isn\'t available on '
      'iPad.';
  static const notInstalled =
      'Install Claude Code on this Mac (claude.com/claude-code), then sign in.';
  static const signInInTerminal =
      'Open Terminal, run claude, then type /login.';

  final ProcessStarter _start;
  final bool _isMac;
  String? _binary;

  final _status = ValueNotifier(AiAccountStatus.signedOut);
  final _cancels = Cancels();
  final _running = <String, Set<Process>>{};

  /// The running `claude auth login`, while [signIn] waits for it.
  Process? _login;

  @override
  AiProviderId get id => .claude;

  @override
  String get displayName => 'Claude';

  @override
  ValueListenable<AiAccountStatus> get status => _status;

  /// The environment for Claude Code: this app's, without variables that
  /// would make it bill an API key instead of the plan (a stray
  /// `ANTHROPIC_API_KEY`), or treat it as nested in another Claude Code.
  static Map<String, String> childEnvironment(Map<String, String> parent) => {
    for (final MapEntry(:key, :value) in parent.entries)
      if (!key.startsWith('ANTHROPIC_') &&
          key != 'CLAUDECODE' &&
          !key.startsWith('CLAUDE_CODE_'))
        key: value,
    // ponytail: the least thinking for every request. Unlimited, Haiku
    // thinks ~45 s before a line drawing (~11 s like this, nearly as
    // good); make it per action if an action needs deep thinking.
    'MAX_THINKING_TOKENS': '1024',
  };

  Future<Process> _startClaude(
    String binary,
    List<String> args, {
    String? workingDirectory,
  }) => _start(
    binary,
    args,
    workingDirectory: workingDirectory,
    environment: childEnvironment(Platform.environment),
    includeParentEnvironment: false,
  );

  /// Where `claude` is, or null if it isn't installed.
  Future<String?> _findBinary() async {
    if (_binary case final binary?) return binary;
    final home = Platform.environment['HOME'] ?? '';
    for (final path in [
      '$home/.local/bin/claude',
      '/opt/homebrew/bin/claude',
      '/usr/local/bin/claude',
    ]) {
      if (File(path).existsSync()) return _binary = path;
    }
    try {
      final result = await Process.run('/bin/zsh', [
        '-lc',
        'command -v claude',
      ]).timeout(const Duration(seconds: 10));
      final path = (result.stdout as String).trim();
      if (result.exitCode == 0 && path.startsWith('/')) return _binary = path;
    } on Exception catch (e) {
      log.info('No claude on the login shell\'s PATH: $e');
    }
    return null;
  }

  /// Runs `claude <args>` to the end: its exit code and output.
  Future<(int, String)> _run(String binary, List<String> args) async {
    final process = await _startClaude(binary, args);
    unawaited(process.stdin.close());
    final out = process.stdout.transform(utf8.decoder).join();
    unawaited(process.stderr.drain<void>());
    final code = await process.exitCode.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
    return (code, await out);
  }

  Future<AiAccountStatus> _checkStatus() async {
    if (!_isMac)
      return const AiAccountStatus(.unavailable, detail: notOnThisDevice);
    final binary = await _findBinary();
    if (binary == null) {
      return const AiAccountStatus(.unavailable, detail: notInstalled);
    }
    try {
      final (_, out) = await _run(binary, ['auth', 'status', '--json']);
      return parseStatus(out);
    } on Exception catch (e) {
      log.warning('claude auth status failed: $e');
      return const AiAccountStatus(
        .error,
        detail: 'Couldn\'t run Claude Code on this Mac.',
      );
    }
  }

  /// The account status from `claude auth status --json`.
  /// Only a claude.ai login counts: an API key would bill per use.
  @visibleForTesting
  static AiAccountStatus parseStatus(String json) {
    final status = jsonObject(json);
    if (status.isEmpty) {
      return const AiAccountStatus(
        .error,
        detail: 'Couldn\'t read Claude Code\'s sign-in. Update Claude Code.',
      );
    }
    if (status['loggedIn'] != true) return AiAccountStatus.signedOut;
    if (status['authMethod'] != 'claude.ai') {
      return const AiAccountStatus(
        .signedOut,
        detail:
            'Claude Code is set up to bill an API account, not your Claude '
            'plan. Sign in with your Claude account.',
      );
    }
    final plan = status['subscriptionType'] as String?;
    return AiAccountStatus(
      .signedIn,
      label: plan == null || plan.isEmpty
          ? 'Claude account'
          : '${plan[0].toUpperCase()}${plan.substring(1)} plan',
      plan: plan,
    );
  }

  @override
  Future<void> refreshStatus() async {
    if (_status.value.state == .signingIn) return;
    _status.value = await _checkStatus();
  }

  /// Runs `claude auth login`, which opens claude.ai's own sign-in in the
  /// browser, and waits until Claude Code is signed in.
  @override
  Future<void> signIn(BuildContext context) async {
    if (!_isMac) throw const AiError(AiError.notAvailable, notOnThisDevice);
    final binary = await _findBinary();
    if (binary == null) throw const AiError(AiError.notAvailable, notInstalled);
    await refreshStatus();
    if (_status.value.isSignedIn) return;

    final Process login;
    try {
      login = await _startClaude(binary, ['auth', 'login']);
    } on ProcessException catch (e) {
      log.warning('Couldn\'t start claude auth login: $e');
      throw const AiError(AiError.failed, 'Couldn\'t start Claude Code.');
    }
    _login = login;
    _status.value = const AiAccountStatus(
      .signingIn,
      detail: 'Finish signing in to Claude in your browser.',
    );
    unawaited(login.stdin.close());
    unawaited(login.stdout.drain<void>());
    unawaited(login.stderr.drain<void>());
    var exited = false;
    unawaited(login.exitCode.then((_) => exited = true));
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    var status = AiAccountStatus.signedOut;
    bool cancelled() => _login != login;
    try {
      while (!cancelled()) {
        await Future<void>.delayed(const Duration(seconds: 2));
        final hadExited = exited;
        if (cancelled()) break;
        status = await _checkStatus();
        if (status.isSignedIn || hadExited) break;
        if (DateTime.now().isAfter(deadline)) break;
      }
    } finally {
      login.kill();
    }
    if (cancelled()) throw cancelledError; // [cancelSignIn] set the status
    _login = null;
    if (status.isSignedIn) {
      _status.value = status;
      return;
    }
    // e.g. `claude auth login` needs a terminal
    _status.value = AiAccountStatus(
      status.state,
      detail: status.detail ?? signInInTerminal,
    );
    throw AiError(AiError.signedOut, status.detail ?? signInInTerminal);
  }

  /// Stops [signIn]: ends `claude auth login` and shows Claude Code's
  /// status again. Unlike [signOut], never signs Claude Code out.
  Future<void> cancelSignIn() async {
    final login = _login;
    if (login == null) return;
    _login = null;
    login.kill();
    final status = await _checkStatus();
    if (_login == null) _status.value = status; // not signing in again
  }

  /// Signs Claude Code itself out, also for Terminal.
  @override
  Future<void> signOut() async {
    final binary = await _findBinary();
    if (binary != null) await _run(binary, ['auth', 'logout']);
    await refreshStatus();
  }

  @override
  Future<List<AiModel>> models() async => const [
    AiModel('haiku', 'Claude Haiku'),
    AiModel('sonnet', 'Claude Sonnet'),
    AiModel('opus', 'Claude Opus'),
    // Billed as extra usage on Pro, and on Max past half the weekly limit
    AiModel('fable', 'Claude Fable', mayCostExtra: true),
  ];

  /// Claude has no picture model: illustrations are SVG from [respond].
  @override
  Future<Uint8List>? generateImage(
    String requestId,
    String prompt, {
    required String model,
  }) => null;

  @override
  Future<String> respond(
    String requestId,
    AiRequest req, {
    required String model,
    void Function(String partial)? onPartial,
  }) async {
    final result = await _query(
      requestId,
      req,
      model: model,
      onPartial: req.jsonSchema == null ? onPartial : null,
    );
    return result.text;
  }

  @override
  Future<List<AiLink>> search(
    String requestId,
    String query, {
    required AiSearchKind kind,
    required String model,
  }) async {
    final result = await _query(
      requestId,
      AiRequest(
        instructions:
            '${searchInstructions(kind)} Use the WebSearch tool'
            '${kind == .video ? ' with allowed_domains ["youtube.com"]' : ''}. '
            'Only give links that appeared in your search results.',
        prompt: 'Topic: $query',
        jsonSchema: linksSchema,
        webSearch: true,
      ),
      model: model,
    );
    // Only links the search really found: the model may make some up
    final found = [
      for (final link in linksFromJson(result.text))
        if (result.toolOutput.contains(link.url.toString())) link,
    ];
    return keepLinks(found, kind);
  }

  @override
  Future<void> cancel(String requestId) async {
    _cancels.cancel(requestId);
    for (final process in _running.remove(requestId) ?? const <Process>{}) {
      process.kill();
    }
  }

  /// The arguments for one `claude -p` request. The prompt (and picture)
  /// go to stdin as a stream-json user message.
  @visibleForTesting
  static List<String> args({
    required String model,
    required String instructions,
    String? jsonSchema,
    bool webSearch = false,
  }) => [
    '-p',
    ...['--input-format', 'stream-json'],
    ...['--output-format', 'stream-json'],
    '--verbose',
    '--include-partial-messages',
    ...['--model', model],
    ...['--append-system-prompt', instructions],
    // No personal settings, hooks, plugins, MCP servers or skills
    '--restricted',
    '--strict-mcp-config',
    '--disable-slash-commands',
    ...['--permission-mode', 'dontAsk'],
    // A search needs turns for searching and for the structured answer
    '--max-turns',
    if (webSearch) '8' else '4',
    '--no-session-persistence',
    '--tools',
    if (webSearch) 'WebSearch,WebFetch' else '',
    // Without this the searches are silently denied
    if (webSearch) ...['--allowedTools', 'WebSearch,WebFetch'],
    if (jsonSchema != null) ...['--json-schema', jsonSchema],
  ];

  /// The stream-json user message for [req].
  @visibleForTesting
  static Map<String, Object?> userMessage(AiRequest req) {
    final text = [
      req.prompt.trim(),
      if (req.restrictSearchToDomain case final domain?)
        'Only use results from $domain.',
    ].where((part) => part.isNotEmpty).join('\n\n');
    return {
      'type': 'user',
      'message': {
        'role': 'user',
        'content': [
          if (req.imagePng case final png?)
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/png',
                'data': base64Encode(png),
              },
            },
          // An empty text block is an error
          if (text.isNotEmpty || req.imagePng == null)
            {'type': 'text', 'text': text.isEmpty ? '?' : text},
        ],
      },
    };
  }

  Future<_Result> _query(
    String id,
    AiRequest req, {
    required String model,
    void Function(String partial)? onPartial,
  }) async {
    _cancels.check(id);
    if (!_isMac) throw const AiError(AiError.notAvailable, notOnThisDevice);
    if (!_status.value.isSignedIn) await refreshStatus();
    final status = _status.value;
    final binary = _binary;
    if (!status.isSignedIn || binary == null) {
      throw AiError(switch (status.state) {
        .unavailable => AiError.notAvailable,
        .error => AiError.failed,
        _ => AiError.signedOut,
      }, status.detail ?? 'Sign in to Claude Code in Settings.');
    }

    // An empty folder: nothing of the owner's for Claude Code to read
    final dir = await Directory.systemTemp.createTemp('nts-claude-');
    final Process process;
    try {
      process = await _startClaude(
        binary,
        args(
          model: model,
          instructions: req.instructions,
          jsonSchema: req.jsonSchema,
          webSearch: req.webSearch,
        ),
        workingDirectory: dir.path,
      );
    } on ProcessException catch (e) {
      dir.delete(recursive: true).ignore();
      log.warning('Couldn\'t start Claude Code: $e');
      throw const AiError(AiError.failed, 'Couldn\'t start Claude Code.');
    }
    (_running[id] ??= {}).add(process);
    final stopwatch = Stopwatch()..start();
    try {
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.writeln(jsonEncode(userMessage(req)));
      try {
        await process.stdin.close();
      } on Exception catch (e) {
        // It stopped early; its output says why
        log.info('Claude Code didn\'t read the request: $e');
      }

      final run = _Run();
      await for (final line
          in process.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              // No news for this long: it's stuck
              .timeout(const Duration(minutes: 2))) {
        run.add(jsonObject(line), onPartial);
      }
      final exitCode = await process.exitCode;
      _cancels.check(id);
      log.info(
        'claude -p ($model) took ${stopwatch.elapsedMilliseconds} ms, '
        'exit $exitCode',
      );
      final error = run.error(exitCode, await stderr);
      if (error != null) {
        if (error.code == AiError.signedOut) {
          _status.value = AiAccountStatus(.signedOut, detail: error.message);
        }
        throw error;
      }
      return (
        text: run.answer(json: req.jsonSchema != null),
        toolOutput: run.toolOutput.toString(),
      );
    } on TimeoutException {
      throw const AiError(AiError.failed, 'Claude took too long. Try again.');
    } finally {
      _running[id]?.remove(process);
      process.kill();
      dir.delete(recursive: true).ignore();
    }
  }
}

typedef _Result = ({String text, String toolOutput});

/// What one `claude -p --output-format stream-json` run printed.
class _Run {
  final text = StringBuffer();
  final toolOutput = StringBuffer();
  Map<String, Object?>? result;
  Map<String, Object?>? rateLimit;

  /// The last assistant message's error, e.g. "model_not_found".
  String? assistantError;

  void add(Map<String, Object?> event, void Function(String)? onPartial) {
    switch (event) {
      case {
        'type': 'stream_event',
        'event': {
          'type': 'content_block_delta',
          'delta': {'type': 'text_delta', 'text': final String delta},
        },
      }:
        text.write(delta);
        onPartial?.call(text.toString());
      case {'type': 'assistant', 'error': final String error}:
        assistantError = error;
      case {'type': 'user', 'message': {'content': final List content}}:
        for (final block in content) {
          if (block case {'type': 'tool_result', 'content': final content}) {
            toolOutput.writeln(
              content is List
                  ? content
                        .map((c) => c is Map ? c['text'] ?? '' : '')
                        .join('\n')
                  : content,
            );
          }
        }
      case {'type': 'rate_limit_event', 'rate_limit_info': final Map info}:
        rateLimit = info.cast();
      case {'type': 'result'}:
        result = event;
    }
  }

  String answer({required bool json}) {
    if (!json) return result?['result'] as String? ?? text.toString();
    final structured = result?['structured_output'];
    if (structured == null) {
      throw const AiError(AiError.failed, 'Claude didn\'t give an answer.');
    }
    return jsonEncode(structured);
  }

  AiError? error(int exitCode, String stderr) => claudeCodeError(
    result: result,
    rateLimit: rateLimit,
    assistantError: assistantError,
    exitCode: exitCode,
    stderr: stderr,
  );
}

/// A failed `claude -p` run as an [AiError], or null if it succeeded.
@visibleForTesting
AiError? claudeCodeError({
  required Map<String, Object?>? result,
  Map<String, Object?>? rateLimit,
  String? assistantError,
  int exitCode = 0,
  String stderr = '',
}) {
  final failed =
      result == null ||
      result['is_error'] == true ||
      result['subtype'] != 'success';
  if (!failed) return null;

  final status = result?['api_error_status'];
  final message = (result?['result'] as String?) ?? stderr;
  final lower = message.toLowerCase();
  if (rateLimit?['status'] == 'rejected' ||
      status == 429 ||
      assistantError == 'rate_limit' ||
      lower.contains('usage limit') ||
      lower.contains('hit your limit')) {
    return AiError(
      AiError.limit,
      'Claude plan limit reached.${tryAgainAfter(epochSeconds(rateLimit?['resetsAt']))}',
    );
  }
  if (status == 401 ||
      assistantError == 'authentication_failed' ||
      lower.contains('/login') ||
      lower.contains('not logged in') ||
      lower.contains('invalid api key')) {
    return const AiError(
      AiError.signedOut,
      'Claude Code is signed out. Sign in again in Settings.',
    );
  }
  if (status == 404 || assistantError == 'model_not_found') {
    return const AiError(
      AiError.modelUnavailable,
      'This Claude model isn\'t available on your plan. Pick another in '
      'Settings.',
    );
  }
  if (result?['subtype'] == 'error_max_turns') {
    return const AiError(
      AiError.failed,
      'Claude couldn\'t finish this. Try again.',
    );
  }
  ClaudeCodeProvider.log.warning(
    'claude -p failed (exit $exitCode): '
    '${message.length > 300 ? message.substring(0, 300) : message}',
  );
  final firstLine = message.trim().split('\n').first;
  return AiError(
    AiError.failed,
    firstLine.isEmpty
        ? 'Claude Code stopped unexpectedly. Update Claude Code and try again.'
        : 'Claude Code: $firstLine',
  );
}
