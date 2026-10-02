import 'dart:convert';

/// The claims (payload) of [jwt], or null if it isn't a JWT.
///
/// NOT verified: only for tokens that came straight from the issuer's token
/// endpoint over HTTPS, to read things like the email or account id.
Map<String, Object?>? jwtClaims(String? jwt) {
  final parts = jwt?.split('.');
  if (parts == null || parts.length != 3) return null;
  try {
    final json = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final claims = jsonDecode(json);
    return claims is Map ? claims.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}
