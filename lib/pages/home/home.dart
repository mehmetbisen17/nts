import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nts/components/home/sentry_consent_dialog.dart';
import 'package:nts/components/navbar/responsive_navbar.dart';
import 'package:nts/components/theming/dynamic_material_app.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/pages/home/browse.dart';
import 'package:nts/pages/home/recent_notes.dart';
import 'package:nts/pages/home/settings.dart';
import 'package:nts/pages/home/whiteboard.dart';

class HomePage extends StatefulWidget {
  const new({super.key, required this.subpage, required this.path});

  final String subpage;
  final String? path;

  @override
  State<HomePage> createState() => _HomePageState();

  static const recentSubpage = 'recent';
  static const browseSubpage = 'browse';
  static const whiteboardSubpage = 'whiteboard';
  static const settingsSubpage = 'settings';
  static const List<String> subpages = [
    recentSubpage,
    browseSubpage,
    whiteboardSubpage,
    settingsSubpage,
  ];
}

class _HomePageState extends State<HomePage> {
  /// Bumped when the shell (sidebar, tabs) opens a folder, so the browse
  /// page starts over at the new path instead of keeping its own.
  var _browseGeneration = 0;
  var _shellNavigated = false;

  @override
  void initState() {
    DynamicMaterialApp.addFullscreenListener(_setState);
    super.initState();
    _showDialogs();
  }

  void _showDialogs() async {
    await null; // initState must be completed before using context
    if (!mounted) return;
    SentryConsentDialog.showIfNeeded(context);
  }

  void _setState() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shellNavigated && oldWidget.path != widget.path) _browseGeneration++;
    _shellNavigated = false;
  }

  void _go(String location) {
    // if leaving whiteboard, check if saved
    if (widget.subpage == HomePage.whiteboardSubpage) {
      switch (Whiteboard.savingState) {
        case null:
        case .saved:
          break;
        case .waitingToSave:
          Whiteboard.triggerSave();
          return;
        case .saving:
          return;
      }
    }
    _shellNavigated = true;
    context.go(location);
  }

  void _onDestinationSelected(int index) {
    final subpage = HomePage.subpages[index];
    final isInFolder = widget.path != null && widget.path != '/';
    // Tapping Folders again goes back to the root folder.
    if (subpage == widget.subpage &&
        !(subpage == HomePage.browseSubpage && isInFolder)) {
      return;
    }
    _go(HomeRoutes.routes[index].path);
  }

  void _onFolderSelected(String folderPath) =>
      _go(HomeRoutes.browseFilePath(folderPath));

  Widget get body {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(widget.subpage),
        child: switch (widget.subpage) {
          HomePage.browseSubpage => BrowsePage(
            key: ValueKey(_browseGeneration),
            path: widget.path,
          ),
          HomePage.whiteboardSubpage => const Whiteboard(),
          HomePage.settingsSubpage => const SettingsPage(),
          _ => const RecentPage(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // hide navbar in fullscreen whiteboard
    if (widget.subpage == HomePage.whiteboardSubpage &&
        DynamicMaterialApp.isFullscreen) {
      return body;
    }

    final index = HomePage.subpages.indexOf(widget.subpage);
    return ResponsiveNavbar(
      selectedIndex: index < 0 ? 0 : index,
      path: widget.path,
      onDestinationSelected: _onDestinationSelected,
      onFolderSelected: _onFolderSelected,
      body: body,
    );
  }

  @override
  void dispose() {
    DynamicMaterialApp.removeFullscreenListener(_setState);

    super.dispose();
  }
}
