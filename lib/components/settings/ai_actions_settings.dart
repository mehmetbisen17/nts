import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/ai/ai_result_sheet.dart';
import 'package:nts/components/settings/settings_row.dart';
import 'package:nts/components/settings/settings_subtitle.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/ai_router.dart';
import 'package:nts/data/services/ai_actions.dart';
import 'package:nts/i18n/strings.g.dart';

/// Settings → AI actions: for each action, Automatic or a signed-in
/// account's model. The signed-in accounts' models are fetched for their
/// names, and again when a picker opens.
class AiActionsSection extends StatefulWidget {
  const new({super.key});

  /// Models fetched so far, for their names.
  static final _models = <AiProviderId, List<AiModel>>{};

  @override
  State<AiActionsSection> createState() => _AiActionsSectionState();
}

class _AiActionsSectionState extends State<AiActionsSection> {
  late final _changes = AiRouter.changes;
  final _loading = <AiProviderId>{};

  @override
  void initState() {
    super.initState();
    _changes.addListener(_loadModels);
    _loadModels();
  }

  @override
  void dispose() {
    _changes.removeListener(_loadModels);
    super.dispose();
  }

  /// The models of newly signed-in accounts, for what Automatic uses and
  /// the pickers' labels.
  void _loadModels() {
    for (final provider in AiRouter.providers) {
      if (!provider.status.value.isSignedIn ||
          AiActionsSection._models.containsKey(provider.id) ||
          !_loading.add(provider.id)) {
        continue;
      }
      provider
          .models()
          .then((models) {
            AiActionsSection._models[provider.id] = models;
            if (mounted) setState(() {});
          })
          .catchError((Object _) {})
          .whenComplete(() => _loading.remove(provider.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return ListenableBuilder(
      listenable: _changes,
      builder: (context, _) => Column(
        crossAxisAlignment: .stretch,
        children: [
          SettingsSubtitle(subtitle: t.ai.actionsSettings.title),
          Padding(
            padding: const .only(top: HiganSpace.m, bottom: HiganSpace.xs),
            child: Text(
              t.ai.actionsSettings.help,
              style: HiganText.body(context, size: 13, color: c.textSecondary),
            ),
          ),
          for (final action in AiAction.values)
            SettingsRow(
              title: action.title,
              subtitle: _subtitle(action),
              modified: AiRouter.routeOf(action) != null,
              trailing: _RoutePicker(action: action),
            ),
        ],
      ),
    );
  }

  /// Who Automatic uses now, or why the picked account can't be used.
  String? _subtitle(AiAction action) {
    if (AiRouter.routeOf(action) != null) {
      return AiRouter.unavailableReason(action);
    }
    final provider = AiRouter.autoProvider(action);
    if (provider == null) return t.ai.actionsSettings.automaticNone;
    final model = switch (AiActionsSection._models[provider.id]) {
      final models? => AiRouter.defaultOf(models, action),
      null => null,
    };
    return t.ai.actionsSettings.automaticUses(
      provider: model == null
          ? AiRouter.shortName(provider)
          : _modelLabel(provider, model),
    );
  }
}

/// E.g. "ChatGPT · GPT-5.4", "Claude Haiku" or
/// "ChatGPT · GPT Image 2 (picture)".
String _modelLabel(AiProvider provider, AiModel model) {
  final label = AiRouter.label(provider, model.label);
  return model.isImageModel
      ? '$label (${t.ai.actionsSettings.picture})'
      : label;
}

/// A pill with the action's route; tapping it lists Automatic and the
/// models of the signed-in accounts.
class _RoutePicker extends StatefulWidget {
  const new({required this.action});

  final AiAction action;

  @override
  State<_RoutePicker> createState() => _RoutePickerState();
}

class _RoutePickerState extends State<_RoutePicker> {
  var _loading = false;

  /// "Automatic", or e.g. "ChatGPT · GPT-5.4" or "Claude Sonnet".
  String get _label {
    final route = AiRouter.routeOf(widget.action);
    if (route == null) return t.ai.actionsSettings.automatic;
    final provider = AiRouter.provider(route.provider);
    if (provider == null) return '${route.provider.name} · ${route.model}';
    return AiRouter.label(
      provider,
      AiActionsSection._models[route.provider]
              ?.where((model) => model.id == route.model)
              .firstOrNull
              ?.label ??
          route.model,
    );
  }

  Future<void> _pick() async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final signedIn = [
      for (final provider in AiRouter.providers)
        if (provider.status.value.isSignedIn) provider,
    ];
    setState(() => _loading = true);
    await Future.wait([
      for (final provider in signedIn)
        provider
            .models()
            .then((models) => AiActionsSection._models[provider.id] = models)
            .catchError((Object _) => const <AiModel>[]),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);

    final c = context.higan;
    final current = AiRouter.routes[widget.action]!.value;
    PopupMenuItem<String> item(String value, String label, [String? note]) =>
        PopupMenuItem(
          value: value,
          height: 40,
          child: Row(
            spacing: HiganSpace.s,
            children: [
              SizedBox(
                width: 18,
                child: value == current
                    ? Icon(Symbols.check, size: 16, color: c.higanText)
                    : null,
              ),
              Flexible(child: Text(label, overflow: .ellipsis)),
              if (note != null)
                HiganLabel(note, size: 9.5, color: c.textTertiary),
            ],
          ),
        );

    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
        Offset.zero & overlay.size,
      ),
      items: [
        item(AiRouter.auto, t.ai.actionsSettings.automatic),
        for (final provider in signedIn) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            enabled: false,
            height: 28,
            child: HiganLabel(AiRouter.shortName(provider), size: 10),
          ),
          for (final model in AiActionsSection._models[provider.id] ?? [])
            // Only pictures need a picture model; searches need text
            if (!model.isImageModel || widget.action == .illustration)
              item(
                AiRouter.encode(provider.id, model.id),
                model.label,
                model.isImageModel
                    ? t.ai.actionsSettings.picture
                    : model.mayCostExtra
                    ? t.ai.actionsSettings.mayCostExtra
                    : null,
              ),
        ],
      ],
    );
    if (picked != null) AiRouter.routes[widget.action]!.value = picked;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return Tooltip(
      message: widget.action.title,
      child: InkWell(
        onTap: _loading ? null : _pick,
        customBorder: const StadiumBorder(),
        child: Container(
          height: 34,
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const .only(left: 14, right: 9),
          decoration: ShapeDecoration(
            shape: StadiumBorder(side: BorderSide(color: c.hairlineStrong)),
          ),
          child: Row(
            mainAxisSize: .min,
            spacing: 6,
            children: [
              Flexible(
                child: Text(
                  _label,
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: HiganText.body(context, size: 13.5),
                ),
              ),
              if (_loading)
                const SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else
                Icon(
                  Symbols.expand_more,
                  size: 16,
                  weight: 300,
                  color: c.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
