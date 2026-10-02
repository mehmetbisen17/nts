import 'dart:io';

import 'package:collapsible/collapsible.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nts/components/navbar/responsive_navbar.dart';
import 'package:nts/components/settings/ai_accounts.dart';
import 'package:nts/components/settings/ai_actions_settings.dart';
import 'package:nts/components/settings/app_info.dart';
import 'package:nts/components/settings/settings_button.dart';
import 'package:nts/components/settings/settings_directory_selector.dart';
import 'package:nts/components/settings/settings_dropdown.dart';
import 'package:nts/components/settings/settings_icloud.dart';
import 'package:nts/components/settings/settings_selection.dart';
import 'package:nts/components/settings/settings_sentry.dart';
import 'package:nts/components/settings/settings_subtitle.dart';
import 'package:nts/components/settings/settings_switch.dart';
import 'package:nts/components/theming/adaptive_alert_dialog.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/locales.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/routes.dart';
import 'package:nts/data/sentry/sentry_init.dart';
import 'package:nts/data/tools/shape_pen.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:stow/stow.dart';

class const SettingsPage({super.key}) extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();

  static Future<bool?> showResetDialog({
    required BuildContext context,
    required Stow pref,
    required String prefTitle,
  }) async {
    if (pref.value == pref.defaultValue) return null;
    return await showDialog(
      context: context,
      builder: (context) => AdaptiveAlertDialog(
        title: Text(t.settings.reset.title),
        content: Text(prefTitle),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              pref.value = pref.defaultValue;
              Navigator.of(context).pop(true);
            },
            child: Text(t.settings.reset.button),
          ),
        ],
      ),
    );
  }
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    stows.locale.addListener(onChanged);
    super.initState();
  }

  void onChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    final pagePadding = ResponsiveNavbar.pagePadding(context);

    // Transparent so the home shell's background (and ember) shows through.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          // Less 4 for the version readout's tap padding, so the heading
          // lines up with Recent's and Folders'.
          padding: pagePadding.copyWith(top: pagePadding.top - 4, bottom: 96),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  Row(
                    crossAxisAlignment: .end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          spacing: 6,
                          children: [
                            const AppInfo(),
                            HiganTitle(
                              t.higan.settings,
                              size: isPhone ? 34 : 40,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SettingsSubtitle(subtitle: t.higan.appearance),
                  SettingsSelection<ThemeMode>(
                    title: t.higan.theme.label,
                    pref: stows.appTheme,
                    options: [
                      HiganSegment(value: .dark, label: t.higan.theme.night),
                      HiganSegment(value: .light, label: t.higan.theme.paper),
                      HiganSegment(value: .system, label: t.higan.theme.system),
                    ],
                  ),
                  SettingsSelection<bool>(
                    title: t.higan.pages.label,
                    subtitle: t.higan.pages.description,
                    pref: stows.editorAutoInvert,
                    options: [
                      HiganSegment(value: false, label: t.higan.pages.paper),
                      HiganSegment(value: true, label: t.higan.pages.black),
                    ],
                  ),
                  SettingsSelection<double>(
                    title: t.higan.gallerySize.label,
                    subtitle: t.higan.gallerySize.description,
                    pref: stows.galleryScale,
                    options: [
                      HiganSegment(value: 0.6, label: t.higan.gallerySize.xs),
                      HiganSegment(value: 0.8, label: t.higan.gallerySize.s),
                      HiganSegment(value: 1, label: t.higan.gallerySize.m),
                      HiganSegment(value: 1.25, label: t.higan.gallerySize.l),
                      HiganSegment(value: 1.6, label: t.higan.gallerySize.xl),
                    ],
                  ),

                  const SettingsICloud(),

                  const AiAccountsSection(),
                  const AiActionsSection(),

                  SettingsSubtitle(subtitle: t.settings.prefCategories.general),
                  SettingsDropdown<String>(
                    title: t.settings.prefLabels.locale,
                    pref: stows.locale,
                    options: [
                      HiganSegment(value: '', label: t.settings.systemLanguage),
                      for (final locale in AppLocaleUtils.supportedLocales)
                        HiganSegment(
                          value: locale.toLanguageTag(),
                          label:
                              localeNames[locale.toLanguageTag()] ??
                              locale.toLanguageTag(),
                        ),
                    ],
                  ),
                  SettingsSelection<LayoutSize>(
                    title: t.settings.prefLabels.layoutSize,
                    pref: stows.layoutSize,
                    options: [
                      HiganSegment(
                        value: .auto,
                        label: t.settings.layoutSizes.auto,
                      ),
                      HiganSegment(
                        value: .phone,
                        label: t.settings.layoutSizes.phone,
                      ),
                      HiganSegment(
                        value: .tablet,
                        label: t.settings.layoutSizes.tablet,
                      ),
                    ],
                  ),
                  SettingsSwitch(
                    title: t.settings.prefLabels.hyperlegibleFont,
                    subtitle: t.settings.prefDescriptions.hyperlegibleFont,
                    pref: stows.hyperlegibleFont,
                  ),

                  SettingsSubtitle(subtitle: t.settings.prefCategories.writing),
                  SettingsSwitch(
                    title: t.settings.prefLabels.preferGreyscale,
                    subtitle: t.settings.prefDescriptions.preferGreyscale,
                    pref: stows.preferGreyscale,
                  ),
                  SettingsSwitch(
                    title: t.settings.prefLabels.autoClearWhiteboardOnExit,
                    subtitle:
                        t.settings.prefDescriptions.autoClearWhiteboardOnExit,
                    pref: stows.autoClearWhiteboardOnExit,
                  ),
                  SettingsSwitch(
                    title: t.settings.prefLabels.disableEraserAfterUse,
                    subtitle: t.settings.prefDescriptions.disableEraserAfterUse,
                    pref: stows.disableEraserAfterUse,
                  ),
                  SettingsSwitch(
                    title: t.editor.canvasTools.holdToSnapShape,
                    subtitle: t.settings.prefDescriptions.holdToSnapShape,
                    pref: stows.holdToSnapShape,
                  ),
                  SettingsSwitch(
                    title: t.editor.canvasTools.scribbleToErase,
                    subtitle: t.settings.prefDescriptions.scribbleToErase,
                    pref: stows.scribbleToErase,
                  ),
                  ValueListenableBuilder(
                    valueListenable: stows.hideFingerDrawingToggle,
                    builder: (context, hideFingerDrawing, _) {
                      final descriptions =
                          t.settings.prefDescriptions.hideFingerDrawing;
                      return SettingsSwitch(
                        title: t.settings.prefLabels.hideFingerDrawingToggle,
                        subtitle: !hideFingerDrawing
                            ? descriptions.shown
                            : stows.editorFingerDrawing.value
                            ? descriptions.fixedOn
                            : descriptions.fixedOff,
                        pref: stows.hideFingerDrawingToggle,
                      );
                    },
                  ),
                  ValueListenableBuilder(
                    valueListenable: stows.hideFingerDrawingToggle,
                    builder: (context, hideFingerDrawing, _) {
                      return Collapsible(
                        collapsed: hideFingerDrawing,
                        axis: CollapsibleAxis.vertical,
                        child: SettingsSwitch(
                          title: t
                              .settings
                              .prefLabels
                              .autoDisableFingerDrawingWhenStylusDetected,
                          subtitle: t
                              .settings
                              .prefDescriptions
                              .autoDisableFingerDrawingWhenStylusDetected,
                          pref:
                              stows.autoDisableFingerDrawingWhenStylusDetected,
                        ),
                      );
                    },
                  ),

                  SettingsSubtitle(subtitle: t.settings.prefCategories.editor),
                  SettingsSelection<AxisDirection>(
                    title: t.settings.prefLabels.editorToolbarAlignment,
                    pref: stows.editorToolbarAlignment,
                    options: [
                      for (final direction in AxisDirection.values)
                        HiganSegment(
                          value: direction,
                          label: t.settings.axisDirections[direction.index],
                        ),
                    ],
                  ),
                  SettingsSwitch(
                    title: t.settings.prefLabels.editorToolbarShowInFullscreen,
                    pref: stows.editorToolbarShowInFullscreen,
                  ),
                  SettingsSwitch(
                    title: t.settings.prefLabels.editorPromptRename,
                    subtitle: t.settings.prefDescriptions.editorPromptRename,
                    pref: stows.editorPromptRename,
                  ),
                  SettingsSwitch(
                    title: t.settings.prefLabels.recentColorsDontSavePresets,
                    pref: stows.recentColorsDontSavePresets,
                  ),
                  SettingsSelection<int>(
                    title: t.settings.prefLabels.recentColorsLength,
                    pref: stows.recentColorsLength,
                    options: const [
                      HiganSegment(value: 5, label: '5'),
                      HiganSegment(value: 10, label: '10'),
                    ],
                  ),
                  SettingsSwitch(
                    title: t.settings.prefLabels.printPageIndicators,
                    subtitle: t.settings.prefDescriptions.printPageIndicators,
                    pref: stows.printPageIndicators,
                  ),

                  SettingsSubtitle(
                    subtitle: t.settings.prefCategories.performance,
                  ),
                  SettingsSelection<double>(
                    title: t.settings.prefLabels.maxImageSize,
                    subtitle: t.settings.prefDescriptions.maxImageSize,
                    pref: stows.maxImageSize,
                    options: const [
                      HiganSegment(value: 500, label: '500'),
                      HiganSegment(value: 1000, label: '1000'),
                      HiganSegment(value: 2000, label: '2000'),
                    ],
                  ),
                  SettingsSelection<int>(
                    title: t.settings.prefLabels.autosave,
                    subtitle: t.settings.prefDescriptions.autosave,
                    pref: stows.autosaveDelay,
                    options: [
                      const HiganSegment(value: 5000, label: '5s'),
                      const HiganSegment(value: 10000, label: '10s'),
                      HiganSegment(
                        value: -1,
                        label: t.settings.autosaveDisabled,
                      ),
                    ],
                  ),
                  SettingsSelection<int>(
                    title: t.settings.prefLabels.shapeRecognitionDelay,
                    subtitle: t.settings.prefDescriptions.shapeRecognitionDelay,
                    pref: stows.shapeRecognitionDelay,
                    options: [
                      const HiganSegment(value: 500, label: '0.5s'),
                      const HiganSegment(value: 1000, label: '1s'),
                      HiganSegment(
                        value: -1,
                        label: t.settings.shapeRecognitionDisabled,
                      ),
                    ],
                    afterChange: (ms) {
                      ShapePen.debounceDuration =
                          ShapePen.getDebounceFromPref();
                    },
                  ),
                  SettingsSwitch(
                    title: t.settings.prefLabels.autoStraightenLines,
                    subtitle: t.settings.prefDescriptions.autoStraightenLines,
                    pref: stows.autoStraightenLines,
                  ),

                  SettingsSubtitle(
                    subtitle: t.settings.prefCategories.advanced,
                  ),
                  if (isSentryAvailable) const SettingsSentryConsent(),
                  if (Platform.isAndroid)
                    SettingsDirectorySelector(
                      title: t.settings.prefLabels.customDataDir,
                    ),
                  if (Platform.isWindows ||
                      Platform.isLinux ||
                      Platform.isMacOS)
                    SettingsButton(
                      title: t.settings.openDataDir,
                      onPressed: () {
                        if (Platform.isWindows) {
                          Process.run('explorer', [
                            FileManager.documentsDirectory,
                          ]);
                        } else if (Platform.isLinux) {
                          Process.run('xdg-open', [
                            FileManager.documentsDirectory,
                          ]);
                        } else if (Platform.isMacOS) {
                          Process.run('open', [FileManager.documentsDirectory]);
                        }
                      },
                    ),
                  SettingsButton(
                    title: t.logs.viewLogs,
                    subtitle: t.logs.debuggingInfo,
                    onPressed: () => context.push(RoutePaths.logs),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    stows.locale.removeListener(onChanged);
    super.dispose();
  }
}
