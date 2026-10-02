import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/ai/ai_chart.dart';
import 'package:nts/components/settings/ai_accounts.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/ai_router.dart';
import 'package:nts/data/services/ai_actions.dart';
import 'package:nts/data/services/plot_spec.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:url_launcher/url_launcher.dart';

extension AiActionLabels on AiAction {
  String get title => switch (this) {
    .explainExample => t.ai.actions.explainExample.title,
    .paragraph => t.ai.actions.paragraph.title,
    .graph => t.ai.actions.graph.title,
    .illustration => t.ai.actions.illustration.title,
    .video => t.ai.actions.video.title,
    .source => t.ai.actions.source.title,
  };

  String get description => switch (this) {
    .explainExample => t.ai.actions.explainExample.description,
    .paragraph => t.ai.actions.paragraph.description,
    .graph => t.ai.actions.graph.description,
    .illustration => t.ai.actions.illustration.description,
    .video => t.ai.actions.video.description,
    .source => t.ai.actions.source.description,
  };

  IconData get icon => switch (this) {
    .explainExample => Symbols.lightbulb,
    .paragraph => Symbols.notes,
    .graph => Symbols.show_chart,
    .illustration => Symbols.draw,
    .video => Symbols.smart_display,
    .source => Symbols.menu_book,
  };
}

/// Runs [action] (not video or source) on the circled [input] with the
/// account `AiRouter` picks, and shows the answer as it comes. Closing
/// the sheet stops it.
///
/// [onAddText] and [onAddImage] put the answer on the page (`side` 0) or
/// beside it (-1 on the left, 1 on the right); null (e.g. in read-only
/// notes) hides "Add to page".
Future<void> showAiResult(
  BuildContext context, {
  required AiAction action,
  required AiInput input,
  void Function(String text, int side)? onAddText,
  void Function(Uint8List bytes, String extension, int side)? onAddImage,
  bool besidePage = true,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: context.higan.surface1,
  constraints: const BoxConstraints(maxWidth: 560),
  // Above the keyboard, while the student fixes the reading
  builder: (context) => Padding(
    padding: .only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: AiResultSheet(
      action: action,
      input: input,
      onAddText: onAddText,
      onAddImage: onAddImage,
      besidePage: besidePage,
    ),
  ),
);

class AiResultSheet extends StatefulWidget {
  const new({
    super.key,
    required this.action,
    required this.input,
    this.onAddText,
    this.onAddImage,
    this.besidePage = true,
  }) : assert(action != .video && action != .source);

  final AiAction action;
  final AiInput input;
  final void Function(String text, int side)? onAddText;
  final void Function(Uint8List bytes, String extension, int side)? onAddImage;

  /// Whether the answer can go beside the page (not on a whiteboard).
  final bool besidePage;

  /// Whether [error] is fixed in Settings → AI accounts or AI actions,
  /// e.g. by picking another account when a plan's limit is reached.
  static bool needsSettings(AiError error) => const {
    AiError.signedOut,
    AiError.notAvailable,
    AiError.modelUnavailable,
    AiError.setupNeeded,
    AiError.limit,
  }.contains(error.code);

  @override
  State<AiResultSheet> createState() => _AiResultSheetState();
}

class _AiResultSheetState extends State<AiResultSheet> {
  static final log = Logger('AiResultSheet');

  /// The running request, or null when done.
  String? _id;
  String? _text, _madeBy;
  AiError? _error;
  PlotSpec? _plot;

  /// The illustration: (bytes, extension).
  (Uint8List, String)? _picture;
  var _copied = false, _adding = false;

  /// What the AI read in the circle ('' if it didn't say, '?' if it
  /// couldn't), or what the student said it says ([_confirmed]).
  var _reading = '';

  /// What the student typed over [_reading], sent with every run after.
  String? _confirmed;

  bool get _busy => _id != null;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    if (_id case final id?) AiActions.cancel(id);
    super.dispose();
  }

  /// Runs the action again, taking [reading] as what the circle says.
  /// Nothing to do if it's what the AI read already.
  void _confirm(String reading) {
    reading = reading.trim();
    if (reading.isEmpty || reading == _reading) return;
    _confirmed = reading;
    _run();
  }

  Future<void> _run() async {
    if (_id case final old?) AiActions.cancel(old);
    final id = AiActions.newId();
    setState(() {
      _id = id;
      _error = null;
      _copied = false;
      _text = _plot = _picture = null;
      _reading = _confirmed ?? '';
    });
    bool current() => mounted && _id == id;
    try {
      final (provider, model) = await AiRouter.resolve(widget.action);
      if (!current()) return;
      setState(
        () => _madeBy = t.ai.madeBy(
          provider: AiRouter.shortName(provider),
          model: model.label,
        ),
      );
      switch (widget.action) {
        case .explainExample || .paragraph:
          final answer = await AiActions.explain(
            id,
            widget.input,
            action: widget.action,
            provider: provider,
            model: model,
            confirmedReading: _confirmed,
            onPartial: (partial) {
              // The spinner stays while "You wrote: …" comes
              if (current())
                setState(() => _text = partial.isEmpty ? null : partial);
            },
          );
          if (current()) {
            _reading = answer.reading;
            _text = answer.body;
          }
        case .graph:
          final (plot, reading) = await AiActions.graph(
            id,
            widget.input,
            provider: provider,
            model: model,
            confirmedReading: _confirmed,
          );
          if (current()) {
            _reading = reading;
            _plot = plot;
          }
        case .illustration:
          final (reading, bytes, extension) = await AiActions.illustrate(
            id,
            widget.input,
            provider: provider,
            model: model,
            confirmedReading: _confirmed,
          );
          if (current()) {
            _reading = reading;
            _picture = (bytes, extension);
          }
        case .video || .source:
          throw ArgumentError.value(widget.action, 'action');
      }
    } on AiError catch (e) {
      if (e.code == AiError.cancelled) return;
      log.info('${widget.action} failed: $e');
      if (current()) {
        _error = e;
        // e.g. a misread "y = 2x + |" with "Nothing to chart"
        if (e case AiReadingError(:final reading)) _reading = reading;
      }
    } on Object catch (e, st) {
      // Also Errors, e.g. from drawing an SVG: never a spinner forever
      log.warning('${widget.action} failed', e, st);
      if (current()) _error = AiError(AiError.failed, t.ai.failed);
    }
    if (current()) setState(() => _id = null);
  }

  /// Whether there's an answer to copy or add.
  bool get _done =>
      !_busy &&
      !_adding &&
      _error == null &&
      (_text ?? _plot ?? _picture) != null;

  /// The answer as an image, for copying or adding it: (bytes, extension).
  Future<(Uint8List, String)?> _image() async {
    if (_picture case final picture?) return picture;
    if (_plot case final plot?) return (await AiChart.renderPng(plot), '.png');
    return null;
  }

  Future<void> _copy() async {
    if (_text case final text?) {
      await Clipboard.setData(ClipboardData(text: text));
    } else if (await _image() case (final bytes, final extension)?) {
      await SystemClipboard.instance?.write([
        DataWriterItem()
          ..add(extension == '.png' ? Formats.png(bytes) : Formats.jpeg(bytes)),
      ]);
    }
    if (mounted) setState(() => _copied = true);
  }

  /// Adds the answer on the page ([side] 0) or beside it (-1, 1).
  Future<void> _addToPage([int side = 0]) async {
    // A chart takes a moment to become a PNG: meanwhile the sheet may be
    // closed, and popping again would close the note.
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    bool open() => mounted && (route?.isCurrent ?? false);
    setState(() => _adding = true);
    if (_text case final text?) {
      widget.onAddText?.call(text, side);
    } else if (await _image() case (final bytes, final extension)?) {
      if (!open()) return;
      widget.onAddImage?.call(bytes, extension, side);
    }
    if (open()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final canAdd = _text != null
        ? widget.onAddText != null
        : widget.onAddImage != null;
    final canCopy = _text != null || SystemClipboard.instance != null;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: .fromLTRB(
          24,
          0,
          24,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            Row(
              spacing: 10,
              children: [
                Icon(widget.action.icon, size: 20, weight: 300, color: c.text),
                Expanded(
                  child: Text(
                    widget.action.title,
                    style: HiganText.title(context, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HiganSpace.m),
            _YourNote(
              input: widget.input,
              reading:
                  _reading.isNotEmpty ||
                      (!_busy &&
                          (_error == null ||
                              const {
                                AiError.failed,
                                AiActions.unreadable,
                              }.contains(_error!.code)))
                  ? _Reading(reading: _reading, onConfirm: _confirm)
                  : null,
            ),
            const SizedBox(height: HiganSpace.l),
            Divider(color: c.hairline),
            Flexible(
              child: SingleChildScrollView(
                padding: const .symmetric(vertical: HiganSpace.l),
                child: AnimatedSize(
                  duration: HiganMotion.fast,
                  curve: HiganMotion.curve,
                  alignment: .topCenter,
                  child: _body(context),
                ),
              ),
            ),
            // Not under an error: nothing was made
            if (_madeBy case final madeBy? when _error == null)
              Text(
                madeBy,
                style: HiganText.label(
                  context,
                  size: 10,
                  color: c.textTertiary,
                  tracking: 0.04,
                ),
              ),
            const SizedBox(height: HiganSpace.m),
            Row(
              spacing: HiganSpace.s,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.ai.close),
                ),
                Expanded(
                  // Stacked when narrow, e.g. in Slide Over
                  child: OverflowBar(
                    alignment: .end,
                    overflowAlignment: .end,
                    spacing: HiganSpace.s,
                    overflowSpacing: HiganSpace.s,
                    children: [
                      if (canCopy)
                        OutlinedButton.icon(
                          onPressed: _done ? _copy : null,
                          icon: Icon(
                            _copied ? Symbols.check : Symbols.content_copy,
                            size: 16,
                            weight: 300,
                          ),
                          label: Text(_copied ? t.ai.copied : t.ai.copy),
                        ),
                      if (canAdd)
                        // Beside the page on the left, on it, or on the
                        // right, kept together (smaller when narrow)
                        FittedBox(
                          fit: .scaleDown,
                          child: Row(
                            mainAxisSize: .min,
                            spacing: 4,
                            children: [
                              if (widget.besidePage)
                                IconButton.outlined(
                                  tooltip: t.nts.side.addLeft,
                                  onPressed: _done
                                      ? () => _addToPage(-1)
                                      : null,
                                  icon: const Icon(
                                    Symbols.dock_to_left,
                                    size: 18,
                                    weight: 300,
                                  ),
                                ),
                              FilledButton.icon(
                                onPressed: _done ? _addToPage : null,
                                icon: const Icon(
                                  Symbols.add,
                                  size: 16,
                                  weight: 400,
                                ),
                                label: Text(t.ai.addToPage),
                              ),
                              if (widget.besidePage)
                                IconButton.outlined(
                                  tooltip: t.nts.side.addRight,
                                  onPressed: _done ? () => _addToPage(1) : null,
                                  icon: const Icon(
                                    Symbols.dock_to_right,
                                    size: 18,
                                    weight: 300,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final c = context.higan;
    if (_error case final error?) {
      return AiErrorBody(error: error, onTryAgain: _run);
    }
    if (_text case final text?) {
      return SelectableText(
        text,
        style: HiganText.body(context).copyWith(height: 1.6),
      );
    }
    if (_plot case final plot?) {
      return AspectRatio(aspectRatio: 3 / 2, child: AiChart(plot));
    }
    if (_picture case (final bytes, _)?) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: min(360, MediaQuery.sizeOf(context).height * 0.4),
          ),
          child: AspectRatio(
            aspectRatio: 1,
            // Paper behind it: line drawings are see-through
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.pagePaper,
                borderRadius: const .all(.circular(HiganRadius.card)),
                border: Border.all(color: c.hairlineStrong),
              ),
              child: ClipRRect(
                borderRadius: const .all(.circular(HiganRadius.card)),
                child: Image.memory(bytes, fit: .contain),
              ),
            ),
          ),
        ),
      );
    }
    return Row(
      spacing: HiganSpace.m,
      children: [
        const _Spinner(),
        Text(
          _confirmed != null
              ? t.ai.rereading
              : widget.action == .illustration
              ? t.ai.drawing
              : t.ai.working,
          style: HiganText.body(context, color: c.textSecondary),
        ),
      ],
    );
  }
}

/// What went wrong (selectable, e.g. to copy a link in it) and what can be
/// done: try again, fix it in the AI settings (over this sheet), or open
/// the page that helps.
class AiErrorBody extends StatelessWidget {
  const new({super.key, required this.error, required this.onTryAgain});

  final AiError error;
  final VoidCallback onTryAgain;

  /// [error]'s message, in the app's language where the app knows it.
  static String messageOf(AiError error) =>
      error.code == AiActions.unreadable ? t.ai.nothingToRead : error.message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    spacing: HiganSpace.s,
    children: [
      SelectableText(
        messageOf(error),
        style: HiganText.body(context, size: 15),
      ),
      Wrap(
        spacing: HiganSpace.s,
        runSpacing: HiganSpace.s,
        children: [
          OutlinedButton(onPressed: onTryAgain, child: Text(t.ai.tryAgain)),
          if (AiResultSheet.needsSettings(error))
            FilledButton(
              onPressed: () => AiAccountsSection.open(context),
              child: Text(t.ai.openSettings),
            ),
          if (error.helpUrl case final url?)
            OutlinedButton.icon(
              onPressed: () => launchUrl(url, mode: .externalApplication),
              icon: const Icon(Symbols.open_in_new, size: 16, weight: 300),
              label: Text(t.ai.google.openConsole),
            ),
        ],
      ),
    ],
  );
}

/// What was circled, small, as the AI saw it, and beside it (or under
/// it, if there's no room) what the AI read there ([reading]).
class _YourNote extends StatelessWidget {
  const new({required this.input, this.reading});

  final AiInput input;
  final Widget? reading;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return Column(
      crossAxisAlignment: .start,
      spacing: HiganSpace.xs,
      children: [
        HiganLabel(t.ai.yourNote, size: 10, color: c.textTertiary),
        Wrap(
          spacing: HiganSpace.l,
          runSpacing: HiganSpace.m,
          crossAxisAlignment: .center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 64, maxWidth: 280),
              child: DecoratedBox(
                position: .foreground,
                decoration: BoxDecoration(
                  borderRadius: const .all(.circular(HiganRadius.paper)),
                  border: Border.all(color: c.hairlineStrong),
                ),
                child: ClipRRect(
                  borderRadius: const .all(.circular(HiganRadius.paper)),
                  child: Image.memory(
                    input.png,
                    fit: .contain,
                    semanticLabel: input.typedText.isEmpty
                        ? t.ai.yourNote
                        : input.typedText,
                  ),
                ),
              ),
            ),
            ?reading,
          ],
        ),
      ],
    );
  }
}

/// "You wrote …": what the AI read in the circle ('' or '?' if it didn't
/// or couldn't). Tapping it lets the student fix it; [onConfirm] then runs
/// the action again with their words.
class _Reading extends StatefulWidget {
  const new({required this.reading, required this.onConfirm});

  final String reading;
  final ValueChanged<String> onConfirm;

  @override
  State<_Reading> createState() => _ReadingState();
}

class _ReadingState extends State<_Reading> {
  /// While editing.
  TextEditingController? _field;

  bool get _known => widget.reading.isNotEmpty && widget.reading != '?';

  void _edit() => setState(
    () => _field = TextEditingController(text: _known ? widget.reading : ''),
  );

  /// Stops editing, running the action again with [text] if there is one.
  void _stop([String? text]) {
    final field = _field;
    setState(() => _field = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => field?.dispose());
    if (text != null) widget.onConfirm(text);
  }

  @override
  void dispose() {
    _field?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final label = HiganLabel(t.ai.youWrote, size: 10, color: c.textTertiary);
    if (_field case final field?) {
      return Column(
        crossAxisAlignment: .start,
        spacing: HiganSpace.xs,
        children: [
          label,
          Row(
            spacing: HiganSpace.s,
            children: [
              Expanded(
                child: TextField(
                  controller: field,
                  autofocus: true,
                  textInputAction: .done,
                  onSubmitted: _stop,
                  style: HiganText.body(context),
                  decoration: InputDecoration(
                    hintText: t.ai.typeReading,
                    isDense: true,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => _stop(field.text),
                child: Text(t.ai.askAgain),
              ),
              HiganCircleButton(
                icon: Symbols.close,
                tooltip: t.common.cancel,
                bordered: false,
                onPressed: _stop,
              ),
            ],
          ),
        ],
      );
    }
    return Tooltip(
      message: t.ai.editReading,
      child: HiganFocusRing(
        shape: const RoundedRectangleBorder(
          borderRadius: .all(.circular(HiganRadius.paper)),
        ),
        child: InkWell(
          onTap: _edit,
          borderRadius: const .all(.circular(HiganRadius.paper)),
          child: Padding(
            padding: const .symmetric(vertical: HiganSpace.xs),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 3,
              children: [
                label,
                Row(
                  mainAxisSize: .min,
                  spacing: 6,
                  children: [
                    Flexible(
                      child: Text(
                        _known ? widget.reading : t.ai.typeReading,
                        maxLines: 3,
                        overflow: .ellipsis,
                        style: HiganText.body(
                          context,
                          color: _known ? c.text : c.textTertiary,
                        ),
                      ),
                    ),
                    Icon(
                      Symbols.edit,
                      size: 14,
                      weight: 300,
                      color: c.textTertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 16,
    child: CircularProgressIndicator(strokeWidth: 1.5),
  );
}
