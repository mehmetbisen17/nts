import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:nts/components/navbar/responsive_navbar.dart';
import 'package:nts/components/theming/higan/higan_theme.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/i18n/extensions/redirecting_localization_delegate.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:window_manager/window_manager.dart';

class DynamicMaterialApp extends StatefulHookWidget {
  const new({super.key, required this.title, required this.router});

  final String title;
  final GoRouter router;

  @override
  State<DynamicMaterialApp> createState() => DynamicMaterialAppState();

  static final ValueNotifier<bool> _isFullscreen = ValueNotifier(false);
  static bool get isFullscreen => _isFullscreen.value;
  static ValueListenable<bool> get fullscreen => _isFullscreen;

  static void setFullscreen(bool value, {required bool updateSystem}) {
    _isFullscreen.value = value;
    if (!updateSystem) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.setFullScreen(value);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        value ? SystemUiMode.immersive : SystemUiMode.edgeToEdge,
      );
    }
  }

  static void addFullscreenListener(void Function() listener) {
    _isFullscreen.addListener(listener);
  }

  static void removeFullscreenListener(void Function() listener) {
    _isFullscreen.removeListener(listener);
  }
}

class DynamicMaterialAppState extends State<DynamicMaterialApp>
    with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    SystemChrome.setSystemUIChangeCallback(_onFullscreenChange);

    super.initState();
  }

  @override
  void onWindowEnterFullScreen() {
    DynamicMaterialApp.setFullscreen(true, updateSystem: false);
  }

  @override
  void onWindowLeaveFullScreen() {
    DynamicMaterialApp.setFullscreen(false, updateSystem: false);
  }

  Future<void> _onFullscreenChange(bool systemOverlaysAreVisible) async {
    DynamicMaterialApp.setFullscreen(
      !systemOverlaysAreVisible,
      updateSystem: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = useValueListenable(stows.appTheme);
    final platform = useValueListenable(stows.platform);
    final hyperlegibleFont = useValueListenable(stows.hyperlegibleFont);

    // Higan is the theme on every platform: no Yaru, dynamic or accent colors.
    final night = useMemoized(() => HiganTheme.night(platform), [
      platform,
      hyperlegibleFont,
    ]);
    final paper = useMemoized(() => HiganTheme.paper(platform), [
      platform,
      hyperlegibleFont,
    ]);
    return ExplicitlyThemedApp(
      title: widget.title,
      router: widget.router,
      themeMode: themeMode,
      theme: paper,
      darkTheme: night,
      highContrastTheme: paper,
      highContrastDarkTheme: night,
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    SystemChrome.setSystemUIChangeCallback(null);

    super.dispose();
  }
}

@visibleForTesting
class ExplicitlyThemedApp extends StatelessWidget {
  @protected
  const new({
    super.key,
    required this.title,
    required this.router,
    required this.themeMode,
    required this.theme,
    required this.darkTheme,
    this.highContrastTheme,
    this.highContrastDarkTheme,
  });

  final String title;
  final GoRouter router;
  final ThemeMode themeMode;
  final ThemeData theme;
  final ThemeData? darkTheme, highContrastTheme, highContrastDarkTheme;

  static final _materialAppKey = GlobalKey<State<MaterialApp>>();

  @override
  Widget build(BuildContext context) {
    final highContrastTheme =
        this.highContrastTheme ??
        theme.copyWith(colorScheme: theme.colorScheme.withHighContrast());
    final highContrastDarkTheme =
        this.highContrastDarkTheme ??
        darkTheme?.copyWith(
          colorScheme: darkTheme?.colorScheme.withHighContrast(),
        );

    return MaterialApp.router(
      key: _materialAppKey,
      title: title,
      routeInformationProvider: router.routeInformationProvider,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: const [
        RedirectingLocalizationDelegate<CupertinoLocalizations>(
          GlobalCupertinoLocalizations.delegate,
        ),
        RedirectingLocalizationDelegate<MaterialLocalizations>(
          GlobalMaterialLocalizations.delegate,
        ),
        RedirectingLocalizationDelegate<WidgetsLocalizations>(
          GlobalWidgetsLocalizations.delegate,
        ),
        RedirectingLocalizationDelegate<FlutterQuillLocalizations>(
          FlutterQuillLocalizations.delegate,
        ),
      ],
      themeMode: themeMode,
      theme: theme,
      darkTheme: darkTheme,
      highContrastTheme: highContrastTheme,
      highContrastDarkTheme: highContrastDarkTheme,
      builder: (context, child) => MacTitlebar(child: child!),
      debugShowCheckedModeBanner: false,
    );
  }
}

extension on ColorScheme {
  ColorScheme withHighContrast() => ColorScheme.fromSeed(
    brightness: brightness,
    seedColor: primary,
    surface: brightness == .light ? Colors.white : Colors.black,
    contrastLevel: 1,
  );
}
