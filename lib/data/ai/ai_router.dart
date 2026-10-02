import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/ai_registry.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/services/ai_actions.dart';
import 'package:nts/i18n/strings.g.dart';

/// Which account and model each [AiAction] uses: "auto" (the first
/// signed-in account in [order]) or `<provider>:<model>`, saved as
/// `ai.route.<action>`. Picked in Settings → AI actions.
abstract final class AiRouter {
  static const auto = 'auto';

  static final routes = {
    for (final action in AiAction.values) action: stows.aiRoutes[action.name]!,
  };

  /// Who Automatic tries, in order.
  static List<AiProviderId> order(AiAction action) => switch (action) {
    .explainExample ||
    .paragraph ||
    .graph => const [.chatgpt, .claude, .google],
    // Claude's line drawings first: gpt-image uses the plan up fast
    .illustration => const [.claude, .chatgpt, .google],
    // The official YouTube search first
    .video => const [.google, .chatgpt, .claude],
    .source => const [.chatgpt, .claude, .google],
  };

  @visibleForTesting
  static List<AiProvider>? debugProviders;

  /// No real accounts in tests: they'd run the user's Claude Code and
  /// read the Keychain. Tests set [debugProviders] instead.
  static final _inTests =
      !kReleaseMode && Platform.environment.containsKey('FLUTTER_TEST');

  static List<AiProvider> get providers =>
      debugProviders ?? (_inTests ? const [] : AiRegistry.all);

  static AiProvider? provider(AiProviderId id) =>
      providers.firstWhereOrNull((provider) => provider.id == id);

  /// [provider]'s name without the part in brackets, e.g. "Google" for
  /// "Google (your Cloud project)", for small labels.
  static String shortName(AiProvider provider) =>
      provider.displayName.split(' (').first;

  static bool get anySignedIn =>
      providers.any((provider) => provider.status.value.isSignedIn);

  /// Notifies when an account's status or a route changes.
  static Listenable get changes => Listenable.merge([
    for (final provider in providers) provider.status,
    ...routes.values,
  ]);

  /// The saved route of [action]: null for Automatic.
  static ({AiProviderId provider, String model})? routeOf(AiAction action) =>
      parse(routes[action]!.value);

  static ({AiProviderId provider, String model})? parse(String route) {
    final colon = route.indexOf(':');
    if (colon < 0) return null;
    final provider = AiProviderId.values.asNameMap()[route.substring(0, colon)];
    final model = route.substring(colon + 1);
    if (provider == null || model.isEmpty) return null;
    return (provider: provider, model: model);
  }

  static String encode(AiProviderId provider, String model) =>
      '${provider.name}:$model';

  /// Who Automatic uses for [action] right now, if anyone.
  static AiProvider? autoProvider(AiAction action) {
    for (final id in order(action)) {
      final provider = AiRouter.provider(id);
      if (provider != null && provider.status.value.isSignedIn) {
        return provider;
      }
    }
    return null;
  }

  /// Who [action] would use right now: the saved route's account (even
  /// if it's signed out), or Automatic's.
  static AiProvider? providerFor(AiAction action) => switch (routeOf(action)) {
    final route? => provider(route.provider),
    null => autoProvider(action),
  };

  /// Why [action] can't run right now, or null if it can.
  static String? unavailableReason(AiAction action) {
    final route = routeOf(action);
    if (route == null) {
      return autoProvider(action) == null ? t.ai.signInToUse : null;
    }
    final provider = AiRouter.provider(route.provider);
    if (provider == null) return t.ai.route.noAccount;
    final status = provider.status.value;
    if (status.isSignedIn) return null;
    // e.g. that Claude Code needs an update: signing in again won't help
    if (status.detail case final detail?) return detail;
    return status.state == .unavailable
        ? t.ai.route.unavailable(provider: shortName(provider))
        : t.ai.route.signedOut(provider: shortName(provider));
  }

  /// The account and model to use for [action]. Throws an [AiError]
  /// (SIGNED_OUT, NOT_AVAILABLE, MODEL_UNAVAILABLE) to show as is.
  static Future<(AiProvider, AiModel)> resolve(AiAction action) async {
    final route = routeOf(action);
    if (route == null) {
      final provider = autoProvider(action);
      if (provider == null) {
        throw AiError(AiError.signedOut, t.ai.signInToUse);
      }
      return (provider, await defaultModel(provider, action));
    }
    final provider = AiRouter.provider(route.provider);
    if (provider == null) {
      throw AiError(AiError.notAvailable, t.ai.route.noAccount);
    }
    final status = provider.status.value;
    if (!status.isSignedIn) {
      final unavailable = status.state == .unavailable;
      throw AiError(
        unavailable ? AiError.notAvailable : AiError.signedOut,
        unavailableReason(action)!,
      );
    }
    final models = await provider.models();
    return (
      provider,
      // One that's gone fails with MODEL_UNAVAILABLE when used
      models.firstWhereOrNull((model) => model.id == route.model) ??
          AiModel(route.model, route.model),
    );
  }

  /// What Automatic uses on [provider]: its first model that isn't billed
  /// extra; for pictures a picture model if it has one (e.g. gpt-image on
  /// paid ChatGPT plans), else a text model draws lines.
  static Future<AiModel> defaultModel(
    AiProvider provider,
    AiAction action,
  ) async {
    final model = defaultOf(await provider.models(), action);
    if (model == null) {
      throw AiError(
        AiError.modelUnavailable,
        t.ai.route.noModel(provider: shortName(provider)),
      );
    }
    return model;
  }

  /// [defaultModel] of [models], or null if none can do [action].
  static AiModel? defaultOf(List<AiModel> models, AiAction action) {
    final included = models.where((model) => !model.mayCostExtra);
    return (action == .illustration
            ? included.firstWhereOrNull((model) => model.isImageModel)
            : null) ??
        included.firstWhereOrNull((model) => !model.isImageModel) ??
        models.firstWhereOrNull((model) => !model.isImageModel);
  }

  /// E.g. "ChatGPT · GPT-5.4", or just "Claude Sonnet" when the model's
  /// name already says who.
  static String label(AiProvider provider, String model) {
    final name = shortName(provider);
    return model.startsWith(name) ? model : '$name · $model';
  }
}
