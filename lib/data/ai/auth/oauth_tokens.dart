import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:stow_secure/stow_secure.dart';

/// OAuth tokens as saved in the Keychain by [TokenStore].
class OAuthTokens {
  const new({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
    this.idToken,
  });

  final String accessToken;
  final DateTime expiresAt;
  final String? refreshToken;

  /// An OpenID Connect id token, see `jwtClaims`.
  final String? idToken;

  /// From a token endpoint's reply (RFC 6749 section 5.1). A refresh reply
  /// may leave out the refresh or id token: [previous]'s are kept then.
  factory fromTokenResponse(
    Map<String, Object?> json, {
    OAuthTokens? previous,
    DateTime? now,
  }) {
    final accessToken = json['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const FormatException('No access_token in the token response');
    }
    final expiresIn = switch (json['expires_in']) {
      final num seconds => seconds.toInt(),
      final String seconds => int.tryParse(seconds) ?? 3600,
      _ => 3600,
    };
    return OAuthTokens(
      accessToken: accessToken,
      expiresAt: (now ?? DateTime.now()).add(Duration(seconds: expiresIn)),
      refreshToken: json['refresh_token'] as String? ?? previous?.refreshToken,
      idToken: json['id_token'] as String? ?? previous?.idToken,
    );
  }

  factory fromJson(Map<String, Object?> json) => OAuthTokens(
    accessToken: json['access']! as String,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAt']! as int),
    refreshToken: json['refresh'] as String?,
    idToken: json['id'] as String?,
  );

  Map<String, Object?> toJson() => {
    'access': accessToken,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
    'refresh': ?refreshToken,
    'id': ?idToken,
  };

  /// Refreshed this long before they expire.
  static const refreshMargin = Duration(minutes: 5);

  bool expiresSoon([DateTime? now]) =>
      !(now ?? DateTime.now()).isBefore(expiresAt.subtract(refreshMargin));

  @override
  String toString() => 'OAuthTokens(expiresAt: $expiresAt)'; // no secrets
}

/// POSTs [form] (form-encoded) to an OAuth token endpoint, for a code
/// exchange or a refresh. [previous] is kept where the reply leaves out
/// the refresh or id token.
///
/// Throws [AiError]: SIGNED_OUT if the grant is no longer valid (the user
/// must sign in again), FAILED otherwise (e.g. offline). Never logs tokens.
Future<OAuthTokens> requestTokens(
  Uri endpoint,
  Map<String, String> form, {
  OAuthTokens? previous,
  Map<String, String>? headers,
  http.Client? client,
}) async {
  final http.Response response;
  try {
    response = await (client?.post ?? http.post)(
      endpoint,
      headers: {'Accept': 'application/json', ...?headers},
      body: form,
    ).timeout(const Duration(seconds: 30));
  } on Exception catch (e) {
    TokenStore.log.warning('Token request to ${endpoint.host} failed: $e');
    throw const AiError(
      AiError.failed,
      'Couldn\'t reach the sign-in server. Check your connection.',
    );
  }

  Object? json;
  try {
    json = jsonDecode(response.body);
  } on FormatException {
    json = null;
  }
  final map = json is Map
      ? json.cast<String, Object?>()
      : const <String, Object?>{};

  if (response.statusCode == HttpStatus.ok) {
    try {
      return OAuthTokens.fromTokenResponse(map, previous: previous);
    } on Exception catch (e) {
      TokenStore.log.warning('Bad token response from ${endpoint.host}: $e');
      throw const AiError(AiError.failed, 'Sign-in failed. Try again.');
    }
  }

  // e.g. {"error": "invalid_grant"} or {"error": {"code": "..."}}
  final error = switch (map['error']) {
    final String code => code,
    {'code': final String code} => code,
    _ => null,
  };
  TokenStore.log.warning(
    'Token request to ${endpoint.host}: ${response.statusCode} $error',
  );
  if (response.statusCode == HttpStatus.unauthorized ||
      _grantGone.contains(error)) {
    throw const AiError(AiError.signedOut, 'Signed out. Sign in again.');
  }
  final description = map['error_description'];
  throw AiError(
    AiError.failed,
    'Sign-in failed (${description is String ? description : error ?? response.statusCode}).',
  );
}

/// Token errors meaning the refresh token (or code) can't be used again.
const _grantGone = {
  'invalid_grant',
  'refresh_token_expired',
  'refresh_token_reused',
  'refresh_token_invalidated',
};

/// Keeps one account's [OAuthTokens] in the Keychain (a [SecureStow]
/// holding JSON) and hands out fresh access tokens.
///
/// Refreshes [OAuthTokens.refreshMargin] before expiry, one refresh at a
/// time (refresh tokens rotate, so parallel refreshes could sign the user
/// out), and always saves the rotated refresh token. When the grant is gone
/// the tokens are removed and SIGNED_OUT is thrown. A refresh that finishes
/// after [clear] or [save] (signing out or in meanwhile) is thrown away.
class TokenStore {
  new(this._stow, {required this.refresh});

  static final log = Logger('TokenStore');

  final SecureStow<String> _stow;

  /// Gets new tokens for [current], usually with [requestTokens] and
  /// `previous: current`.
  final Future<OAuthTokens> Function(OAuthTokens current) refresh;

  Future<OAuthTokens>? _refreshing;

  /// The saved tokens (once the Keychain was read), or null if signed out.
  OAuthTokens? get tokens {
    if (_stow.value.isEmpty) return null;
    try {
      return OAuthTokens.fromJson(
        (jsonDecode(_stow.value) as Map).cast<String, Object?>(),
      );
    } on Object {
      log.warning('Ignoring unreadable saved tokens');
      return null;
    }
  }

  Future<OAuthTokens?> load() async {
    await _stow.waitUntilRead();
    return tokens;
  }

  /// Saves new tokens, e.g. from signing in.
  Future<void> save(OAuthTokens tokens) => _write(jsonEncode(tokens.toJson()));

  /// Signs out: removes the tokens, also if a refresh is running.
  Future<void> clear() => _write('');

  Future<void> _write(String json) async {
    _refreshing = null; // a running one is out of date
    await _stow.waitUntilRead();
    _stow.value = json;
    await _stow.waitUntilWritten();
  }

  /// A valid access token. Pass the token a server just rejected (401) as
  /// [rejected] to get a refreshed one: call again once, then give up.
  /// Throws [AiError] (SIGNED_OUT if there are no usable tokens).
  Future<String> accessToken({String? rejected}) async {
    final current = await load();
    if (current == null) {
      throw const AiError(AiError.signedOut, 'Signed out. Sign in again.');
    }
    if (current.accessToken != rejected && !current.expiresSoon()) {
      return current.accessToken;
    }
    return (await _refresh(current)).accessToken;
  }

  Future<OAuthTokens> _refresh(OAuthTokens current) {
    if (_refreshing case final running?) return running;
    late final Future<OAuthTokens> refreshing;
    refreshing = _doRefresh(current).whenComplete(() {
      if (_refreshing == refreshing) _refreshing = null;
    });
    return _refreshing = refreshing;
  }

  Future<OAuthTokens> _doRefresh(OAuthTokens current) async {
    try {
      if (current.refreshToken == null) {
        throw const AiError(AiError.signedOut, 'Signed out. Sign in again.');
      }
      final fresh = await refresh(current);
      await _stow.waitUntilRead();
      if (_changedSince(current)) return await _now();
      _stow.value = jsonEncode(fresh.toJson());
      await _stow.waitUntilWritten();
      return fresh;
    } on AiError catch (e) {
      if (_changedSince(current)) return await _now();
      if (e.code == AiError.signedOut) await clear();
      rethrow;
    }
  }

  /// Whether the user signed out or in again since [current] was read.
  bool _changedSince(OAuthTokens current) =>
      tokens?.refreshToken != current.refreshToken;

  /// The tokens saved now: none after signing out.
  Future<OAuthTokens> _now() async =>
      await load() ??
      (throw const AiError(AiError.signedOut, 'Signed out. Sign in again.'));
}

/// A [SecureStow] (Keychain) that also works in the Mac build: it's ad-hoc
/// signed, without the team ID that the data protection keychain needs
/// (error -34018), so on macOS this uses the login keychain.
class KeychainStow extends SecureStow<String> {
  new(String key, {super.volatile}) : super(key, '');

  @override
  FlutterSecureStorage get storage => const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  String toString() => 'KeychainStow($key)'; // no secrets
}
