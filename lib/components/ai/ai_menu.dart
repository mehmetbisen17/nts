import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/ai/ai_result_sheet.dart';
import 'package:nts/components/ai/web_results_sheet.dart';
import 'package:nts/components/canvas/text_boxes.dart';
import 'package:nts/components/settings/ai_accounts.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/components/toolbar/selection_bar.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/ai_router.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/services/ai_actions.dart';
import 'package:nts/data/services/selection_image.dart';
import 'package:nts/data/tools/select.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';

/// The AI menu for the lasso's selection: next to it on wide screens,
/// a bottom sheet on phones. Picking an action renders what was circled
/// ([selectionPng]), then shows the answer ([showAiResult]) or links
/// ([showWebResults]). With no AI account signed in, it says where to
/// sign in instead. The AI settings open over it. If there's nothing to
/// read (no ink, no imported page, no typed text), it says so.
Future<void> showAiMenu(BuildContext context, EditorState editor) async {
  final selection = SelectionActions.selectionOf(editor.currentTool);
  if (selection == null) return;

  final typedText = _typedTextIn(editor, selection);
  if (selection.isEmpty &&
      typedText.isEmpty &&
      editor.coreInfo.pages[selection.pageIndex].backgroundImage == null) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(t.ai.nothingToRead)));
    return;
  }
  if (!AiRouter.anySignedIn) {
    // In case one was signed in elsewhere meanwhile (e.g. Claude Code)
    for (final provider in AiRouter.providers) {
      unawaited(provider.refreshStatus());
    }
  }

  /// For the search query, and cancelled if the menu is dismissed.
  final id = AiActions.newId();
  Future<AiInput?>? input;

  /// '' when ready, or for video and source the search query. Throws
  /// [AiError], shown in the menu.
  Future<String?> prepare(AiAction action) async {
    final circled = await (input ??= _input(editor, selection, typedText));
    if (circled == null) {
      throw AiError(AiActions.unreadable, t.ai.nothingToRead);
    }
    if (action != .video && action != .source) return '';
    final (provider, model) = await AiRouter.resolve(action);
    final (_, query) = await AiActions.searchQuery(
      id,
      circled,
      provider: provider,
      model: model,
    );
    return query;
  }

  final menu = AiMenu(
    prepare: prepare,
    onOpenSettings: () => AiAccountsSection.open(editor.context),
  );
  final (AiAction, String)? picked;
  final screen = MediaQuery.sizeOf(editor.context);
  // A popover needs room for all six rows (not phones, even in landscape)
  if (screen.width < 600 || screen.height < 560) {
    picked = await showModalBottomSheet<(AiAction, String)>(
      context: editor.context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: editor.context.higan.surface1,
      builder: (_) => menu,
    );
  } else {
    final anchor = _selectionRect(selection, editor);
    picked = await showGeneralDialog<(AiAction, String)>(
      context: editor.context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(editor.context)
          .modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: HiganMotion.fast,
      pageBuilder: (context, _, _) => CustomSingleChildLayout(
        delegate: _PopoverLayout(anchor, MediaQuery.paddingOf(context)),
        child: AiMenu.popover(menu),
      ),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: HiganMotion.curve,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
  if (picked == null) {
    unawaited(AiActions.cancel(id)); // stops making the search query
    return;
  }
  final circled = await input;
  if (!editor.mounted || circled == null) return;

  final (action, query) = picked;
  final readOnly = editor.coreInfo.readOnly;
  switch (action) {
    case .video || .source:
      await showWebResults(
        editor.context,
        initialQuery: query,
        kind: action == .video ? .video : .source,
      );
    default:
      await showAiResult(
        editor.context,
        action: action,
        input: circled,
        onAddText: readOnly
            ? null
            : (text, side) => SelectionActions.addText(
                editor,
                selection.pageIndex,
                text,
                side: side,
              ),
        onAddImage: readOnly
            ? null
            : (bytes, extension, side) => editor.addImageNear(
                selection.pageIndex,
                side,
                SelectionActions.anchorOf(
                  editor.coreInfo.pages[selection.pageIndex],
                ),
                bytes,
                extension,
              ),
        // A whiteboard has no sides
        besidePage: !editor.coreInfo.pages[selection.pageIndex].isBoard,
      );
  }
}

/// What was circled as the AI sees it. Tape hides what's under it, like
/// in an export.
Future<AiInput?> _input(
  EditorState editor,
  SelectResult selection,
  String typedText,
) async {
  final png = await AiMenu.render(
    editor.coreInfo,
    selection,
    hasText: typedText.isNotEmpty,
  );
  return png == null ? null : AiInput(png: png, typedText: typedText);
}

/// The typed text inside the lasso: the text boxes at least half in it.
String _typedTextIn(EditorState editor, SelectResult selection) {
  final page = editor.coreInfo.pages[selection.pageIndex];
  return [
    for (final box in page.textBoxes)
      if (box.text.trim().isNotEmpty &&
          Select.rectPercentInside(selection.path, TextBoxes.boundsOf(box)) >=
              0.5)
        box.text.trim(),
  ].join('\n');
}

/// The selection's bounds on screen, or the lasso's if nothing's selected.
Rect? _selectionRect(SelectResult selection, EditorState editor) {
  final bounds =
      Select.currentSelect.selectionBounds ?? selection.path.getBounds();
  final box = editor.coreInfo.pages[selection.pageIndex].renderBox;
  if (box == null || !box.attached) return null;
  return MatrixUtils.transformRect(box.getTransformTo(null), bounds);
}

/// Puts the menu beside [anchor] (right, else left, else over it),
/// on screen and inside [padding]. In the middle if there's no [anchor].
class _PopoverLayout extends SingleChildLayoutDelegate {
  const new(this.anchor, this.padding);

  final Rect? anchor;
  final EdgeInsets padding;

  static const gap = 12.0;

  EdgeInsets get _margin => padding + const EdgeInsets.all(gap);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(_margin);

  @override
  Offset getPositionForChild(Size size, Size child) {
    final anchor = this.anchor;
    final area = _margin.deflateRect(Offset.zero & size);
    if (anchor == null) {
      return area.center - child.center(Offset.zero);
    }
    final x = anchor.right + gap + child.width <= area.right
        ? anchor.right + gap
        : anchor.left - gap - child.width >= area.left
        ? anchor.left - gap - child.width
        : anchor.center.dx - child.width / 2;
    return Offset(
      x.clamp(area.left, area.right - child.width),
      anchor.top.clamp(area.top, area.bottom - child.height),
    );
  }

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      old.anchor != anchor || old.padding != padding;
}

/// The six actions, each with the account it uses. Picking one shows
/// progress on its row while [prepare] runs, then closes the menu with
/// the action and what [prepare] returned (or stays open if it returned
/// null, or on its row says what went wrong). A row whose account can't
/// be used says why, and opens Settings. With no account at all, it's
/// one message and a button.
class AiMenu extends StatefulWidget {
  const new({super.key, required this.prepare, this.onOpenSettings});

  /// Throws [AiError] to show on the action's row.
  final Future<String?> Function(AiAction action) prepare;

  /// Opens the AI settings, over the menu.
  final VoidCallback? onOpenSettings;

  /// Draws what was circled. Replaced in widget tests, where drawing
  /// offscreen only finishes in `runAsync`.
  @visibleForTesting
  static Future<Uint8List?> Function(
    EditorCoreInfo coreInfo,
    SelectResult selection, {
    bool hasText,
  })
  render = selectionPng;

  /// Set by the toolbar's "Ask AI": finishing a lasso opens the menu.
  /// Choosing any tool turns it off (see [EditorState.currentTool]).
  static var lassoArmed = false;

  /// [menu] as a floating card.
  static Widget popover(Widget menu) => Builder(
    builder: (context) {
      final c = context.higan;
      return SizedBox(
        width: 340,
        child: Material(
          color: c.surface2,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: c.isNight ? 0.5 : 0.14),
          shape: RoundedRectangleBorder(
            borderRadius: const .all(.circular(HiganRadius.card)),
            side: BorderSide(color: c.hairlineStrong),
          ),
          clipBehavior: .antiAlias,
          child: Padding(
            padding: const .only(top: HiganSpace.m),
            child: menu,
          ),
        ),
      );
    },
  );

  @override
  State<AiMenu> createState() => _AiMenuState();
}

class _AiMenuState extends State<AiMenu> {
  static final log = Logger('AiMenu');

  late final _changes = AiRouter.changes;
  AiAction? _busy;

  /// What went wrong preparing an action, shown on its row: in the menu,
  /// since a snack bar would be hidden under it.
  final _errors = <AiAction, AiError>{};

  Future<void> _pick(AiAction action) async {
    setState(() {
      _busy = action;
      _errors.remove(action);
    });
    String? result;
    AiError? error;
    try {
      result = await widget.prepare(action);
    } on AiError catch (e) {
      if (e.code != AiError.cancelled) error = e;
    } on Object catch (e, st) {
      log.warning('Preparing $action failed', e, st);
      error = AiError(AiError.failed, t.ai.failed);
    }
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _busy = null;
        if (error != null) _errors[action] = error;
      });
      return;
    }
    // Not if the menu was dismissed meanwhile: that would close the note
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      setState(() => _busy = null); // e.g. the AI settings are over it
      return;
    }
    Navigator.pop(context, (action, result));
  }

  void _openSettings() => widget.onOpenSettings?.call();

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return ListenableBuilder(
      listenable: _changes,
      builder: (context, _) {
        final header = Padding(
          padding: const .fromLTRB(20, 0, 20, HiganSpace.s),
          child: Row(
            spacing: HiganSpace.s,
            children: [
              Icon(Symbols.auto_awesome, size: 14, color: c.higanText),
              HiganLabel(t.ai.menuTitle),
            ],
          ),
        );
        if (!AiRouter.anySignedIn) {
          // e.g. Claude Code needs an update: that, not "sign in"
          final problem = AiRouter.providers
              .where((provider) => provider.status.value.state == .error)
              .firstOrNull;
          return SingleChildScrollView(
            padding: .only(bottom: MediaQuery.paddingOf(context).bottom),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                header,
                HiganEmptyState(
                  title: problem == null ? t.ai.noAccount : t.ai.accountProblem,
                  body: switch (problem?.status.value.detail) {
                    final detail? => '${AiRouter.shortName(problem!)}: $detail',
                    null => t.ai.signInToUse,
                  },
                  lilySize: 64,
                  action: FilledButton(
                    onPressed: _openSettings,
                    child: Text(t.ai.openSettings),
                  ),
                ),
              ],
            ),
          );
        }

        Widget row(AiAction action) {
          final reason = AiRouter.unavailableReason(action);
          final error = _errors[action];
          return _AiMenuRow(
            action: action,
            busy: _busy == action,
            reason: reason,
            error: error == null ? null : AiErrorBody.messageOf(error),
            provider: reason == null
                ? switch (AiRouter.providerFor(action)) {
                    final provider? => AiRouter.shortName(provider),
                    null => null,
                  }
                : null,
            onTap: _busy != null
                ? null
                : reason != null ||
                      (error != null && AiResultSheet.needsSettings(error))
                ? _openSettings
                : () => _pick(action),
          );
        }

        return SingleChildScrollView(
          padding: .only(
            bottom: HiganSpace.s + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              header,
              row(.explainExample),
              row(.paragraph),
              row(.graph),
              row(.illustration),
              Padding(
                padding: const .symmetric(
                  horizontal: 20,
                  vertical: HiganSpace.xs,
                ),
                child: Divider(color: c.hairline),
              ),
              row(.video),
              row(.source),
            ],
          ),
        );
      },
    );
  }
}

class _AiMenuRow extends StatelessWidget {
  const new({
    required this.action,
    required this.busy,
    required this.onTap,
    this.reason,
    this.error,
    this.provider,
  });

  final AiAction action;
  final bool busy;
  final VoidCallback? onTap;

  /// Why it can't run, instead of its description.
  final String? reason;

  /// What went wrong last time, instead of its description.
  final String? error;

  /// The account it uses.
  final String? provider;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final enabled = (onTap != null && reason == null) || busy;
    final note = reason ?? error;
    return HiganFocusRing(
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(10))),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: .symmetric(
            horizontal: 20,
            vertical: HiganTap.isTouch(context) ? 11 : 8,
          ),
          child: Row(
            spacing: 14,
            children: [
              Icon(
                action.icon,
                size: 20,
                weight: 300,
                color: enabled ? c.text : c.textTertiary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 1,
                  children: [
                    Text(
                      action.title,
                      style: HiganText.body(
                        context,
                        color: enabled ? c.text : c.textTertiary,
                      ),
                    ),
                    Text(
                      note ?? action.description,
                      maxLines: note == null ? 1 : 3,
                      overflow: .ellipsis,
                      style: HiganText.body(
                        context,
                        size: 12.5,
                        color: note != null
                            ? c.higanText
                            : enabled
                            ? c.textSecondary
                            : c.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else if (provider case final provider?)
                HiganLabel(provider, size: 9.5, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
