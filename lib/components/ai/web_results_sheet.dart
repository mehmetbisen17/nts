import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/ai/ai_result_sheet.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/ai_router.dart';
import 'package:nts/data/services/ai_actions.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Find a video/source": the search query in an editable field, and a
/// native list of what the AI account found. Links open outside the app
/// (Safari's sheet or the YouTube app on iPad, the browser on a Mac):
/// never in an embedded web view, where Google blocks signing in.
Future<void> showWebResults(
  BuildContext context, {
  required String initialQuery,
  required AiSearchKind kind,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.higan.surface1,
  constraints: const BoxConstraints(maxWidth: 720),
  builder: (context) => WebResultsSheet(initialQuery: initialQuery, kind: kind),
);

class WebResultsSheet extends StatefulWidget {
  const new({super.key, required this.initialQuery, required this.kind});

  final String initialQuery;
  final AiSearchKind kind;

  /// Opens [url] outside the app. Replaced in tests.
  @visibleForTesting
  static Future<bool> Function(Uri url) launch = _launch;

  static Future<bool> _launch(Uri url) async {
    if (Platform.isIOS) {
      // The YouTube app if it's there, else Safari's sheet
      if (_isYouTube(url)) {
        try {
          if (await launchUrl(url, mode: .externalNonBrowserApplication)) {
            return true;
          }
        } on Exception {
          // no app for it
        }
      }
      return launchUrl(url, mode: .inAppBrowserView);
    }
    return launchUrl(url, mode: .externalApplication);
  }

  static bool _isYouTube(Uri url) =>
      url.host == 'youtu.be' ||
      url.host == 'youtube.com' ||
      url.host.endsWith('.youtube.com');

  @override
  State<WebResultsSheet> createState() => _WebResultsSheetState();
}

class _WebResultsSheetState extends State<WebResultsSheet> {
  static final log = Logger('WebResultsSheet');

  late final _query = TextEditingController(text: widget.initialQuery.trim());

  /// The running search, or null when done.
  String? _id;
  List<AiLink>? _links;
  AiError? _error;
  String? _foundBy;

  /// Why the links may be wrong, e.g. Gemini's, which aren't searched.
  String? _caveat;

  AiAction get _action => switch (widget.kind) {
    .video => .video,
    .source => .source,
  };

  @override
  void initState() {
    super.initState();
    if (_query.text.isNotEmpty) _search();
  }

  @override
  void dispose() {
    _query.dispose();
    if (_id case final id?) unawaited(AiActions.cancel(id));
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_id case final old?) unawaited(AiActions.cancel(old));
    final id = AiActions.newId();
    setState(() {
      _id = id;
      _error = null;
      _links = null;
    });
    bool current() => mounted && _id == id;
    try {
      final (provider, model) = await AiRouter.resolve(_action);
      if (!current()) return;
      final (by, caveat) = switch ((provider.id, widget.kind)) {
        // The list is YouTube's own search, not the model's
        (.google, .video) => (t.ai.web.foundWithYouTube, null),
        // Remembered, not searched: nothing checks the links
        (.google, .source) => (
          t.ai.suggestedBy(
            provider: AiRouter.shortName(provider),
            model: model.label,
          ),
          t.ai.web.fromMemory,
        ),
        _ => (
          t.ai.foundBy(
            provider: AiRouter.shortName(provider),
            model: model.label,
          ),
          null,
        ),
      };
      setState(() {
        _foundBy = by;
        _caveat = caveat;
      });
      final links = await AiActions.search(
        id,
        query,
        kind: widget.kind,
        provider: provider,
        model: model,
      );
      if (current()) _links = links;
    } on AiError catch (e) {
      if (e.code == AiError.cancelled) return;
      log.info('Search failed: $e');
      if (current()) _error = e;
    } on Object catch (e, st) {
      log.warning('Search failed', e, st);
      if (current()) _error = AiError(AiError.failed, t.ai.failed);
    }
    if (current()) setState(() => _id = null);
  }

  Future<void> _open(AiLink link) async {
    try {
      await WebResultsSheet.launch(link.url);
    } on Exception catch (e) {
      log.info('Could not open ${link.url}', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .fromLTRB(22, 0, 14, HiganSpace.m),
            child: Row(
              spacing: HiganSpace.s,
              children: [
                Icon(_action.icon, size: 20, weight: 300, color: c.text),
                Expanded(
                  child: Text(
                    _action.title,
                    style: HiganText.title(context, size: 24),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ),
                HiganCircleButton(
                  icon: Symbols.close,
                  tooltip: t.ai.close,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const .symmetric(horizontal: 22),
            child: Row(
              spacing: HiganSpace.s,
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    textInputAction: .search,
                    onSubmitted: (_) => _search(),
                    style: HiganText.body(context),
                    decoration: InputDecoration(
                      hintText: t.ai.web.query,
                      prefixIcon: const Icon(Symbols.search, size: 18),
                    ),
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: _query,
                  builder: (context, value, _) => FilledButton(
                    onPressed: value.text.trim().isEmpty ? null : _search,
                    child: Text(t.ai.web.search),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const .fromLTRB(22, HiganSpace.l, 22, HiganSpace.s),
            child: Column(
              crossAxisAlignment: .start,
              spacing: HiganSpace.xs,
              children: [
                HiganLabel(_foundBy ?? '', size: 10, color: c.textTertiary),
                if (_caveat case final caveat? when _error == null)
                  Text(
                    caveat,
                    style: HiganText.body(
                      context,
                      size: 12.5,
                      color: c.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _body(context)),
          Padding(
            padding: .fromLTRB(
              22,
              HiganSpace.s,
              22,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Text(
              t.ai.web.opensOutside,
              style: HiganText.body(context, size: 12, color: c.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final c = context.higan;
    Widget message(Widget child) => Padding(
      padding: const .symmetric(horizontal: 22, vertical: HiganSpace.m),
      child: child,
    );

    if (_error case final error?) {
      return message(AiErrorBody(error: error, onTryAgain: _search));
    }
    final links = _links;
    if (links == null) {
      return Padding(
        padding: const .symmetric(horizontal: 22, vertical: HiganSpace.m),
        child: Row(
          spacing: HiganSpace.m,
          crossAxisAlignment: .start,
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            Text(
              t.ai.searching,
              style: HiganText.body(context, color: c.textSecondary),
            ),
          ],
        ),
      );
    }
    if (links.isEmpty) {
      return message(
        Text(t.ai.web.noResults, style: HiganText.body(context, size: 15)),
      );
    }
    return ListView.builder(
      padding: const .symmetric(horizontal: 16),
      itemCount: links.length,
      itemBuilder: (context, i) => _LinkRow(
        link: links[i],
        video: widget.kind == .video,
        topBorder: i == 0,
        onTap: () => _open(links[i]),
      ),
    );
  }
}

/// A found video (thumbnail, title, channel) or web page (title, site).
class _LinkRow extends StatelessWidget {
  const new({
    required this.link,
    required this.video,
    required this.topBorder,
    required this.onTap,
  });

  final AiLink link;
  final bool video, topBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final line = BorderSide(color: c.hairline);
    final site = link.url.host.replaceFirst(RegExp(r'^www\.'), '');
    final source = link.source?.trim();
    final placeholder = ColoredBox(
      color: c.well,
      child: Center(
        child: Icon(
          video ? Symbols.smart_display : Symbols.public,
          size: 20,
          weight: 300,
          color: c.textTertiary,
        ),
      ),
    );
    return HiganFocusRing(
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(6))),
      child: Material(
        color: Colors.transparent,
        shape: Border(top: topBorder ? line : .none, bottom: line),
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const .symmetric(horizontal: 6, vertical: 12),
            child: Row(
              spacing: HiganSpace.l,
              children: [
                ClipRRect(
                  borderRadius: const .all(.circular(HiganRadius.paper)),
                  child: SizedBox(
                    width: video ? 128 : 40,
                    height: video ? 72 : 40,
                    child: switch (link.thumbnail) {
                      final thumbnail? => Image.network(
                        thumbnail.toString(),
                        fit: .cover,
                        errorBuilder: (_, _, _) => placeholder,
                      ),
                      null => placeholder,
                    },
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 4,
                    children: [
                      Text(
                        link.title,
                        maxLines: 2,
                        overflow: .ellipsis,
                        style: HiganText.body(context, size: 15),
                      ),
                      HiganLabel(
                        source == null || source.isEmpty || source == site
                            ? site
                            : '$source · $site',
                        size: 10,
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: t.ai.web.open,
                  child: Icon(
                    Symbols.open_in_new,
                    size: 16,
                    weight: 300,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
