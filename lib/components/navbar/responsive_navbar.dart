import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/home/new_note_button.dart';
import 'package:nts/components/navbar/home_sidebar.dart';
import 'package:nts/components/theming/dynamic_material_app.dart';
import 'package:nts/components/theming/higan/higan_lily.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/home/home.dart';
import 'package:stow_codecs/stow_codecs.dart';
import 'package:window_manager/window_manager.dart';

/// The frame around the home pages: a header with tabs on phones and
/// tablets, a sidebar on desktop.
class ResponsiveNavbar extends HookWidget {
  const new({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onFolderSelected,
    this.path,
  });

  final Widget body;

  /// Index into [HomePage.subpages].
  final int selectedIndex;

  /// The folder the browse page shows (from the route), or null for the root.
  final String? path;

  /// Called with an index into [HomePage.subpages].
  final ValueChanged<int> onDestinationSelected;

  /// Called with a folder path like `/Mathematics`.
  final ValueChanged<String> onFolderSelected;

  /// Height of the macOS title bar, which the window draws the content under.
  static const macTitlebarHeight = 28.0;

  /// Sidebar on desktop, header with tabs on phones and tablets.
  /// The "Layout type" setting can force either.
  static bool isSidebarLayout(BuildContext context) =>
      switch (stows.layoutSize.value) {
        .phone => false,
        .tablet => true,
        .auto => switch (Theme.of(context).platform) {
          .macOS ||
          .windows ||
          .linux => MediaQuery.sizeOf(context).width >= 720,
          _ => false,
        },
      };

  /// Padding for a home page's scrolling content: the side gutters,
  /// the gap below the header, and room for the new-note button.
  static EdgeInsets pagePadding(BuildContext context) {
    if (isSidebarLayout(context)) {
      return const .fromLTRB(
        HiganSpace.gutterDesktop,
        14,
        HiganSpace.gutterDesktop,
        120,
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final gutter = wide ? HiganSpace.gutterTablet : HiganSpace.gutterPhone;
    return .fromLTRB(gutter, wide ? 32 : 24, gutter, 120);
  }

  @override
  Widget build(BuildContext context) {
    useListenable(stows.locale); // update labels
    useListenable(stows.layoutSize);

    final theme = Theme.of(context);
    final subpage = HomePage.subpages[selectedIndex];
    final isMac = theme.platform == .macOS;

    // Transparent pages let the ember show through.
    final page = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Theme(
        data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
        child: body,
      ),
    );

    final Widget frame;
    if (isSidebarLayout(context)) {
      final hasNewNote =
          subpage == HomePage.recentSubpage ||
          subpage == HomePage.browseSubpage;
      // Settings keeps the same row (empty) so headings line up across tabs.
      final hasTopRow = hasNewNote || subpage == HomePage.settingsSubpage;
      // Tab goes through the sidebar, then the page (not back and forth).
      frame = Row(
        crossAxisAlignment: .stretch,
        children: [
          FocusTraversalGroup(
            child: HomeSidebar(
              selectedIndex: selectedIndex,
              path: path,
              onDestinationSelected: onDestinationSelected,
              onFolderSelected: onFolderSelected,
            ),
          ),
          Expanded(
            child: FocusTraversalGroup(
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  if (hasTopRow)
                    WindowDragArea(
                      child: Padding(
                        padding: .fromLTRB(
                          HiganSpace.gutterDesktop,
                          isMac ? macTitlebarHeight : 22,
                          HiganSpace.gutterDesktop,
                          0,
                        ),
                        child: Align(
                          alignment: .centerEnd,
                          child: hasNewNote
                              ? NewNotePill(
                                  path: subpage == HomePage.browseSubpage
                                      ? path
                                      : null,
                                )
                              : const SizedBox(height: 36),
                        ),
                      ),
                    )
                  else if (isMac)
                    const WindowDragArea(
                      child: SizedBox(height: macTitlebarHeight),
                    ),
                  Expanded(child: page),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      frame = Column(
        crossAxisAlignment: .stretch,
        children: [
          WindowDragArea(
            child: _HomeHeader(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
            ),
          ),
          Expanded(child: page),
        ],
      );
    }

    return Material(
      color: context.higan.bg,
      child: Stack(
        fit: .expand,
        children: [
          if (subpage != HomePage.whiteboardSubpage) const HiganEmber(),
          frame,
        ],
      ),
    );
  }
}

/// Phones and tablets: lily mark, RECENT / FOLDERS / WHITEBOARD tabs
/// and a settings button.
class _HomeHeader extends StatelessWidget {
  const new({required this.selectedIndex, required this.onDestinationSelected});

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 600;
    final roomy = width >= 480;
    final settingsIndex = HomePage.subpages.indexOf(HomePage.settingsSubpage);
    final gutter = wide ? HiganSpace.gutterTablet : HiganSpace.gutterPhone;
    // On macOS, SafeArea includes the title bar (see MacTitlebar).
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: .fromLTRB(gutter, wide ? 26 : 12, gutter, 0),
        child: SizedBox(
          height: 50,
          child: Stack(
            children: [
              Align(
                alignment: .centerStart,
                child: roomy
                    ? const HiganMark(size: 26)
                    : const HiganLily(size: 24),
              ),
              Padding(
                // Keep clear of the mark and the settings button.
                padding: .symmetric(horizontal: roomy ? 84 : 44),
                child: Center(
                  child: FittedBox(
                    fit: .scaleDown,
                    child: HiganTabs(
                      labels: [
                        t.higan.recent,
                        t.higan.folders,
                        t.higan.whiteboard,
                      ],
                      selectedIndex: selectedIndex,
                      onSelected: onDestinationSelected,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: .centerEnd,
                child: HiganCircleButton(
                  icon: Symbols.settings,
                  tooltip: t.higan.settings,
                  selected: selectedIndex == settingsIndex,
                  onPressed: () => onDestinationSelected(settingsIndex),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// On macOS, dragging here moves the window (the title bar is hidden).
/// Taps still reach the buttons inside.
class WindowDragArea extends StatelessWidget {
  const new({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != .macOS) return child;
    // ponytail: no double-click to zoom; add onDoubleTap on a button-free
    // strip if it's missed (on this whole area it would delay taps).
    // Only once the mouse moves: a plain click here won the gesture straight
    // away, and the native window drag it started could swallow the
    // mouse-up (losing the next click).
    var dragging = false;
    return GestureDetector(
      behavior: .translucent,
      onPanDown: (_) => dragging = false,
      onPanUpdate: (_) {
        if (dragging) return;
        dragging = true;
        windowManager.startDragging();
      },
      child: child,
    );
  }
}

/// On macOS the window draws every route under its hidden title bar
/// (MainFlutterWindow.swift), and the Flutter view doesn't move the window.
/// So on every route: report the title bar as top padding (SafeArea and
/// AppBar keep clear of the traffic lights), and let that strip move the
/// window, with double-click to zoom. Not in full screen, which has no
/// title bar. Wraps the whole app, see [ExplicitlyThemedApp].
class MacTitlebar extends StatelessWidget {
  const new({super.key, required this.child});

  final Widget child;

  static Future<void> _zoom() async => (await windowManager.isMaximized())
      ? windowManager.unmaximize()
      : windowManager.maximize();

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != .macOS) return child;
    return ValueListenableBuilder(
      valueListenable: DynamicMaterialApp.fullscreen,
      builder: (context, fullscreen, child) {
        if (fullscreen) return child!;
        const height = ResponsiveNavbar.macTitlebarHeight;
        final mediaQuery = MediaQuery.of(context);
        EdgeInsets inset(EdgeInsets padding) =>
            padding.copyWith(top: math.max(padding.top, height));
        return MediaQuery(
          data: mediaQuery.copyWith(
            padding: inset(mediaQuery.padding),
            viewPadding: inset(mediaQuery.viewPadding),
          ),
          child: Stack(
            fit: .expand,
            children: [
              child!,
              // Nothing tappable sits here: every route keeps clear of it.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: height,
                child: GestureDetector(
                  behavior: .translucent,
                  excludeFromSemantics: true,
                  onPanStart: (_) => windowManager.startDragging(),
                  onDoubleTap: _zoom,
                ),
              ),
            ],
          ),
        );
      },
      child: child,
    );
  }
}

enum LayoutSize {
  auto,
  phone,
  tablet;

  static const codec = EnumCodec(values);
}
