import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/i18n/strings.g.dart';

final logsHistory = _LogsHistory();

class _LogsHistory extends ChangeNotifier {
  final _history = <LogRecord>[];

  /// A frozen copy of the history.
  List<LogRecord>? _frozenHistory;

  /// The history of log records. Do not modify this list directly.
  List<LogRecord> get history => _frozenHistory ?? _history;

  bool get isFrozen => _frozenHistory != null;

  void freeze() {
    _frozenHistory = List.unmodifiable(_history);
    notifyListeners();
  }

  void unfreeze() {
    _frozenHistory = null;
    notifyListeners();
  }

  void add(LogRecord record) {
    _history.add(record);
    notifyListeners();
  }

  void clear() {
    _history.clear();
    _frozenHistory = null;
    notifyListeners();
  }
}

class const LogsPage({super.key}) extends StatelessWidget {
  void _copy() {
    final buffer = StringBuffer();
    for (final record in logsHistory.history) {
      buffer.write(record.level.name);
      buffer.write(' at ');
      buffer.writeln(record.time);
      buffer.writeln(record.message);
      if (record.error != null) buffer.writeln(record.error);
      if (record.stackTrace != null) buffer.writeln(record.stackTrace);
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width < 600
        ? HiganSpace.gutterPhone
        : HiganSpace.gutterTablet;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: logsHistory,
          builder: (context, _) {
            final history = logsHistory.history;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: .fromLTRB(gutter, 20, gutter, HiganSpace.l),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Row(
                          spacing: HiganSpace.s,
                          children: [
                            if (Navigator.canPop(context))
                              HiganCircleButton(
                                icon: Symbols.chevron_left,
                                tooltip: t.higan.back,
                                onPressed: () => Navigator.maybePop(context),
                              ),
                            const Spacer(),
                            if (logsHistory.isFrozen)
                              HiganCircleButton(
                                icon: Symbols.play_arrow,
                                onPressed: logsHistory.unfreeze,
                              )
                            else
                              HiganCircleButton(
                                icon: Symbols.pause,
                                onPressed: logsHistory.freeze,
                              ),
                            HiganCircleButton(
                              icon: Symbols.content_copy,
                              tooltip: MaterialLocalizations.of(context)
                                  .copyButtonLabel,
                              onPressed: history.isEmpty ? null : _copy,
                            ),
                          ],
                        ),
                        const SizedBox(height: HiganSpace.xl),
                        HiganTitle(t.logs.logs),
                      ],
                    ),
                  ),
                ),
                if (history.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    // A still lily: this page is for debugging.
                    child: HiganEmptyState(
                      title: t.logs.noLogs,
                      body: t.logs.useTheApp,
                      animate: false,
                    ),
                  )
                else
                  SliverPadding(
                    padding: .fromLTRB(gutter, 0, gutter, 60),
                    sliver: SliverList.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) => _LogsItem(
                        record: history[history.length - 1 - index],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LogsItem extends StatelessWidget {
  const new({required this.record});

  final LogRecord record;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final severe = record.level >= Level.SEVERE;
    final dot = severe
        ? c.higan
        : record.level >= Level.WARNING
        ? c.stamenMark
        : c.textTertiary;
    TextStyle mono(double size, Color color) => HiganText.label(
      context,
      size: size,
      color: color,
      tracking: 0,
    ).copyWith(height: 1.5);

    return Container(
      padding: const .symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 6,
        children: [
          Row(
            spacing: HiganSpace.s,
            children: [
              SizedBox.square(
                dimension: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: dot, shape: .circle),
                ),
              ),
              Flexible(
                child: HiganLabel(
                  '${record.level.name} · ${record.loggerName}',
                  size: 10.5,
                  color: severe ? c.higanText : c.textSecondary,
                ),
              ),
            ],
          ),
          SelectableText(record.message, style: mono(12.5, c.text)),
          if (record.stackTrace != null)
            SingleChildScrollView(
              scrollDirection: .horizontal,
              child: Text(
                record.stackTrace.toString().trimRight(),
                style: mono(11, c.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
