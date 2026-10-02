import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/home/sentry_consent_dialog.dart';
import 'package:nts/components/theming/higan/higan_lily.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/sentry/sentry_init.dart';
import 'package:nts/pages/home/settings.dart';
import 'package:nts/pages/logs.dart';

import 'higan_snapshot_util.dart';

/// Renders the Higan settings and logs screens to PNGs for visual checks:
/// `HIGAN_SNAPSHOT=1 flutter test test/higan_settings_snapshot_test.dart`
void main() {
  FlavorConfig.setup();
  disableSentryForTesting();

  const devices = {
    'ipad': (Size(1180, 820), TargetPlatform.iOS),
    'mac': (Size(1280, 800), TargetPlatform.macOS),
    'phone': (Size(390, 844), TargetPlatform.iOS),
  };

  for (final brightness in Brightness.values) {
    final mode = brightness == .dark ? 'night' : 'paper';
    group(mode, () {
      setUp(() => stows.appTheme.value = brightness == .dark ? .dark : .light);

      for (final MapEntry(key: device, value: (size, platform))
          in devices.entries) {
        testWidgets('settings $device $mode', skip: !higanSnapshotsEnabled, (
          tester,
        ) async {
          ICloudStorage.state.value = .notConnected;
          await higanSnapshot(
            tester,
            name: 'settings_${device}_$mode',
            brightness: brightness,
            size: size,
            platform: platform,
            child: _Shell(
              desktop: platform == .macOS,
              child: const SettingsPage(),
            ),
          );
        });
      }

      testWidgets('settings full $mode', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        ICloudStorage.state.value = .needsReconnect;
        stows.hyperlegibleFont.value = false;
        stows.preferGreyscale.value = true; // shows the "changed" italic
        addTearDown(() => stows.preferGreyscale.value = false);
        await higanSnapshot(
          tester,
          name: 'settings_full_$mode',
          brightness: brightness,
          size: const Size(1180, 3000),
          child: const _Shell(child: SettingsPage()),
        );
        ICloudStorage.state.value = .notConnected;
      });

      testWidgets('logs $mode', skip: !higanSnapshotsEnabled, (tester) async {
        logsHistory.clear();
        logsHistory.add(LogRecord(.INFO, 'Opened Linear algebra', 'Editor'));
        logsHistory.add(
          LogRecord(
            .WARNING,
            'This note is still downloading from iCloud',
            'ICloudStorage',
          ),
        );
        logsHistory.add(
          LogRecord(
            .SEVERE,
            'Failed to save note',
            'FileManager',
            const FileSystemException('Permission denied'),
            StackTrace.fromString(
              '#0      FileManager.writeFile (package:nts/data/file_manager/file_manager.dart:212:7)\n'
              '#1      EditorState.saveToFile (package:nts/pages/editor/editor.dart:811:5)\n',
            ),
          ),
        );
        await higanSnapshot(
          tester,
          name: 'logs_ipad_$mode',
          brightness: brightness,
          size: const Size(1180, 820),
          child: const LogsPage(),
        );
      });

      testWidgets('logs empty $mode', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        logsHistory.clear();
        await higanSnapshot(
          tester,
          name: 'logs_empty_phone_$mode',
          brightness: brightness,
          size: const Size(390, 844),
          child: const LogsPage(),
        );
      });

      testWidgets('sentry dialog $mode', skip: !higanSnapshotsEnabled, (
        tester,
      ) async {
        stows.sentryConsent.value = .unknown;
        await higanSnapshot(
          tester,
          name: 'settings_sentry_dialog_$mode',
          brightness: brightness,
          size: const Size(1180, 820),
          child: const _Shell(
            child: Stack(
              children: [
                SettingsPage(),
                Center(child: SentryConsentDialog()),
              ],
            ),
          ),
        );
      });
    });
  }
}

/// Stand-in for the home shell (header or sidebar, background, ember),
/// which is owned by another screen.
class _Shell extends StatelessWidget {
  const new({required this.child, this.desktop = false});

  final Widget child;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: Stack(
        children: [
          const HiganEmber(),
          if (desktop)
            Row(
              crossAxisAlignment: .stretch,
              children: [
                Container(
                  width: HiganSpace.sidebar,
                  padding: const .fromLTRB(28, 28, 18, 0),
                  alignment: .topLeft,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: c.hairline)),
                  ),
                  child: const HiganMark(),
                ),
                Expanded(child: child),
              ],
            )
          else
            Column(
              crossAxisAlignment: .stretch,
              children: [
                Padding(
                  padding: const .fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      const HiganMark(size: 26),
                      const Spacer(),
                      if (MediaQuery.sizeOf(context).width > 600)
                        HiganTabs(
                          labels: const ['Recent', 'Folders', 'Whiteboard'],
                          selectedIndex: -1,
                          onSelected: (_) {},
                        ),
                      const Spacer(),
                      HiganCircleButton(
                        icon: Symbols.settings,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
        ],
      ),
    );
  }
}
