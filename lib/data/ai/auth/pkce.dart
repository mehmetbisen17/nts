import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Proof Key for Code Exchange (RFC 7636) with the S256 method.
class Pkce {
  const new _(this.verifier);

  /// A new random verifier (86 characters).
  factory generate() => Pkce._(randomUrlSafe(64));

  static const method = 'S256';

  /// Sent with the token request.
  final String verifier;

  /// Sent with the authorization request.
  String get challenge => challengeOf(verifier);

  static String challengeOf(String verifier) =>
      _base64UrlNoPad(sha256.convert(ascii.encode(verifier)).bytes);
}

/// [bytes] random bytes as base64url without padding, e.g. for an OAuth
/// `state`.
String randomUrlSafe([int bytes = 32]) {
  final random = Random.secure();
  return _base64UrlNoPad([for (var i = 0; i < bytes; i++) random.nextInt(256)]);
}

String _base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
