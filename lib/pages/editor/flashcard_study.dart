import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/canvas/inner_canvas.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/i18n/strings.g.dart';

/// Studies a flashcards note one card at a time: tap a card to flip it,
/// swipe (or use the arrows) for the next one.
Future<void> showFlashcardStudy(
  BuildContext context,
  EditorCoreInfo coreInfo,
) => Navigator.of(context).push(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => FlashcardStudy(coreInfo: coreInfo),
  ),
);

class FlashcardStudy extends StatefulWidget {
  const new({super.key, required this.coreInfo});

  final EditorCoreInfo coreInfo;

  /// The cards (by their front's page index) with anything on them.
  static List<int> cardsOf(EditorCoreInfo coreInfo) => [
    for (var front = 0; front + 1 < coreInfo.pages.length; front += 2)
      if (coreInfo.pages[front].isNotEmpty ||
          coreInfo.pages[front + 1].isNotEmpty)
        front,
  ];

  @override
  State<FlashcardStudy> createState() => _FlashcardStudyState();
}

class _FlashcardStudyState extends State<FlashcardStudy> {
  late var cards = FlashcardStudy.cardsOf(widget.coreInfo);
  var index = 0;
  var flipped = false;

  void _go(int by) {
    if (cards.isEmpty) return;
    setState(() {
      index = (index + by) % cards.length;
      flipped = false;
    });
  }

  void _shuffle() => setState(() {
    cards = [...cards]..shuffle();
    index = 0;
    flipped = false;
  });

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final strings = t.nts.flashcards;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: HiganLabel(
          cards.isEmpty
              ? strings.study
              : strings.cardOf(n: index + 1, total: cards.length),
        ),
        actions: [
          IconButton(
            tooltip: strings.shuffle,
            onPressed: cards.length > 1 ? _shuffle : null,
            icon: const Icon(Symbols.shuffle),
          ),
        ],
      ),
      body: SafeArea(
        child: cards.isEmpty
            ? Center(
                child: Text(
                  strings.empty,
                  style: HiganText.body(context, color: c.textSecondary),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: .opaque,
                      onTap: () => setState(() => flipped = !flipped),
                      onHorizontalDragEnd: (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity.abs() > 200) _go(velocity < 0 ? 1 : -1);
                      },
                      child: Padding(
                        padding: const .all(24),
                        child: Center(child: _flipCard(context)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const .fromLTRB(16, 0, 16, 16),
                    child: Row(
                      mainAxisAlignment: .center,
                      spacing: 12,
                      children: [
                        IconButton.outlined(
                          tooltip: strings.previous,
                          onPressed: () => _go(-1),
                          icon: const Icon(Symbols.arrow_back),
                        ),
                        FilledButton.icon(
                          onPressed: () => setState(() => flipped = !flipped),
                          icon: const Icon(Symbols.flip, size: 18),
                          label: Text(
                            flipped ? strings.showFront : strings.showBack,
                          ),
                        ),
                        IconButton.outlined(
                          tooltip: strings.next,
                          onPressed: () => _go(1),
                          icon: const Icon(Symbols.arrow_forward),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// The card turning over: its front, then its back past halfway.
  Widget _flipCard(BuildContext context) {
    final front = cards[index];
    return TweenAnimationBuilder<double>(
      key: ValueKey(front),
      tween: Tween(end: flipped ? pi : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
      builder: (context, angle, _) {
        final showBack = angle > pi / 2;
        return Transform(
          alignment: .center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0006)
            ..rotateY(angle),
          child: showBack
              // Turned the right way round
              ? Transform(
                  alignment: .center,
                  transform: Matrix4.rotationY(pi),
                  child: _card(context, front + 1),
                )
              : _card(context, front),
        );
      },
    );
  }

  Widget _card(BuildContext context, int pageIndex) {
    final c = context.higan;
    final page = widget.coreInfo.pages[pageIndex];
    return AspectRatio(
      aspectRatio: page.size.aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const .all(.circular(HiganRadius.card)),
          boxShadow: c.paperShadow,
        ),
        child: ClipRRect(
          borderRadius: const .all(.circular(HiganRadius.card)),
          child: FittedBox(
            child: SizedBox.fromSize(
              size: page.size,
              child: InnerCanvas(
                pageIndex: pageIndex,
                width: page.size.width,
                height: page.size.height,
                showPageIndicator: false,
                coreInfo: widget.coreInfo,
                currentStroke: null,
                currentStrokeDetectedShape: null,
                currentSelection: null,
                currentToolIsSelect: false,
                currentScale: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
