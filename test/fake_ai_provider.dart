import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/ai_router.dart';
import 'package:nts/data/services/ai_actions.dart';

/// An AI account for tests: answers with [onRespond], [onImage] and
/// [onSearch], and records what it was asked.
class FakeAiProvider implements AiProvider {
  new(this.id, {bool signedIn = true, List<AiModel>? models})
    : modelList = models ?? _defaultModels(id),
      _status = ValueNotifier(
        signedIn
            ? AiAccountStatus(.signedIn, label: _labels[id])
            : AiAccountStatus.signedOut,
      );

  /// ChatGPT, Claude and Google, as [AiRouter.debugProviders].
  static List<FakeAiProvider> install({
    bool chatgpt = true,
    bool claude = true,
    bool google = true,
  }) {
    final providers = [
      FakeAiProvider(.chatgpt, signedIn: chatgpt),
      FakeAiProvider(.claude, signedIn: claude),
      FakeAiProvider(.google, signedIn: google),
    ];
    AiRouter.debugProviders = providers;
    for (final route in AiRouter.routes.values) {
      route.value = AiRouter.auto;
    }
    return providers;
  }

  static const _labels = {
    AiProviderId.chatgpt: 'mehmet@example.com',
    AiProviderId.claude: 'Max plan',
    AiProviderId.google: 'mehmet@gmail.com',
  };

  static List<AiModel> _defaultModels(AiProviderId id) => switch (id) {
    .chatgpt => const [
      AiModel('gpt-5.4', 'GPT-5.4'),
      AiModel('gpt-5.4-mini', 'GPT-5.4 mini'),
      AiModel('gpt-image-2', 'GPT Image 2', isImageModel: true),
    ],
    .claude => const [
      AiModel('sonnet', 'Sonnet'),
      AiModel('opus', 'Opus'),
      AiModel('fable', 'Fable', mayCostExtra: true),
    ],
    .google => const [
      AiModel('gemini-2.5-flash', 'Gemini 2.5 Flash'),
      AiModel('gemini-2.5-pro', 'Gemini 2.5 Pro'),
    ],
  };

  @override
  final AiProviderId id;

  @override
  String get displayName => switch (id) {
    .chatgpt => 'ChatGPT',
    .claude => 'Claude',
    .google => 'Google (your Cloud project)',
  };

  final ValueNotifier<AiAccountStatus> _status;

  @override
  ValueListenable<AiAccountStatus> get status => _status;

  void setStatus(AiAccountStatus status) => _status.value = status;

  List<AiModel> modelList;

  /// (request id, request, model) of each [respond].
  final requests = <(String, AiRequest, String)>[];
  final images = <(String prompt, String model)>[];
  final searches = <(String query, AiSearchKind kind, String model)>[];
  final cancelled = <String>[];

  Future<String> Function(AiRequest req, void Function(String)? onPartial)
  onRespond = (_, _) async => 'OK.';

  /// Null: can't make pictures.
  Future<Uint8List> Function(String prompt)? onImage;

  Future<List<AiLink>> Function(String query, AiSearchKind kind) onSearch = (
    _,
    _,
  ) async => const [];

  @override
  Future<void> refreshStatus() async {}

  @override
  Future<void> signIn(BuildContext context) async =>
      _status.value = AiAccountStatus(.signedIn, label: _labels[id]);

  @override
  Future<void> signOut() async => _status.value = AiAccountStatus.signedOut;

  @override
  Future<List<AiModel>> models() async => modelList;

  @override
  Future<String> respond(
    String requestId,
    AiRequest req, {
    required String model,
    void Function(String partial)? onPartial,
  }) {
    requests.add((requestId, req, model));
    return onRespond(req, onPartial);
  }

  @override
  Future<Uint8List>? generateImage(
    String requestId,
    String prompt, {
    required String model,
  }) {
    final onImage = this.onImage;
    if (onImage == null) return null;
    images.add((prompt, model));
    return onImage(prompt);
  }

  @override
  Future<List<AiLink>> search(
    String requestId,
    String query, {
    required AiSearchKind kind,
    required String model,
  }) {
    searches.add((query, kind, model));
    return onSearch(query, kind);
  }

  @override
  Future<void> cancel(String requestId) async => cancelled.add(requestId);
}

/// A tiny circled region, for [AiInput]s.
final testPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

AiInput testInput([String typedText = '']) =>
    AiInput(png: testPng, typedText: typedText);
