import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The accounts the AI tool can use. See `AiRegistry` for the instances.
enum AiProviderId { chatgpt, claude, google }

enum AiAuthState {
  signedOut,
  signingIn,
  signedIn,

  /// Can't be used here, e.g. Claude on iPad, Claude Code isn't installed,
  /// or Google isn't set up yet. [AiAccountStatus.detail] says why.
  unavailable,
  error,
}

class AiAccountStatus {
  const new(this.state, {this.label, this.detail, this.plan});

  static const signedOut = AiAccountStatus(.signedOut);

  final AiAuthState state;

  /// Who is signed in, e.g. an email or "Max plan".
  final String? label;

  /// An error or a hint to show under the account.
  final String? detail;

  /// The plan, if known, e.g. "plus" or "free".
  final String? plan;

  bool get isSignedIn => state == .signedIn;

  @override
  String toString() => 'AiAccountStatus(${state.name}, $label, $detail, $plan)';
}

class AiModel {
  const new(
    this.id,
    this.label, {
    this.isImageModel = false,
    this.mayCostExtra = false,
  });

  /// What the provider calls it, e.g. "gpt-5.4-mini" or "sonnet".
  final String id;
  final String label;

  /// Makes pictures ([AiProvider.generateImage]) instead of text.
  final bool isImageModel;

  /// May be billed on top of the plan (e.g. Claude's Fable models).
  final bool mayCostExtra;
}

class AiRequest {
  const new({
    required this.instructions,
    required this.prompt,
    this.imagePng,
    this.jsonSchema,
    this.webSearch = false,
    this.restrictSearchToDomain,
    this.maxTokens,
  });

  /// The system prompt.
  final String instructions;

  /// The user's text, e.g. typed text in the selection.
  final String prompt;

  /// The circled part of the page.
  final Uint8List? imagePng;

  /// With a JSON Schema, [AiProvider.respond] returns JSON matching it.
  final String? jsonSchema;

  final bool webSearch;

  /// E.g. "youtube.com", with [webSearch].
  final String? restrictSearchToDomain;

  final int? maxTokens;
}

/// A link found by [AiProvider.search], shown in a native list and opened
/// outside the app (never in an embedded web view).
class AiLink {
  const new({
    required this.title,
    required this.url,
    this.source,
    this.thumbnail,
  });

  final String title;
  final Uri url;

  /// The channel or site.
  final String? source;
  final Uri? thumbnail;

  @override
  String toString() => 'AiLink($title, $url)';
}

enum AiSearchKind { video, source }

/// A failed AI call or sign-in. [message] can be shown to the user as is.
class AiError implements Exception {
  const new(this.code, this.message, {this.helpUrl});

  final String code;
  final String message;

  /// The Google Cloud Console page that fixes it, e.g. to turn an API on.
  final Uri? helpUrl;

  static const signedOut = 'SIGNED_OUT';
  static const limit = 'LIMIT';
  static const notAvailable = 'NOT_AVAILABLE';
  static const denied = 'DENIED';
  static const failed = 'FAILED';
  static const cancelled = 'CANCELLED';
  static const modelUnavailable = 'MODEL_UNAVAILABLE';
  static const setupNeeded = 'SETUP_NEEDED';

  @override
  String toString() => 'AiError($code: $message)';
}

/// An account the AI tool can send the circled region to.
/// Implementations: lib/data/ai/providers/.
abstract class AiProvider {
  AiProviderId get id;
  String get displayName;

  ValueListenable<AiAccountStatus> get status;

  /// Re-checks [status], e.g. when Settings opens.
  Future<void> refreshStatus();

  /// Opens the provider's own sign-in (system browser or sheet, never an
  /// embedded web view). Throws [AiError] on failure.
  Future<void> signIn(BuildContext context);
  Future<void> signOut();

  Future<List<AiModel>> models();

  /// Text, or with [AiRequest.jsonSchema], JSON. Streams the text so far
  /// to [onPartial]. Throws [AiError].
  Future<String> respond(
    String requestId,
    AiRequest req, {
    required String model,
    void Function(String partial)? onPartial,
  });

  /// A PNG or JPEG of [prompt], or null if this provider can't make pictures.
  Future<Uint8List>? generateImage(
    String requestId,
    String prompt, {
    required String model,
  });

  /// Videos or web sources for [query]. Throws [AiError].
  Future<List<AiLink>> search(
    String requestId,
    String query, {
    required AiSearchKind kind,
    required String model,
  });

  /// Stops the calls with [requestId]; they throw [AiError.cancelled].
  Future<void> cancel(String requestId);
}
