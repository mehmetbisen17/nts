import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/i18n/strings.g.dart';

var _isConnecting = false;

/// The sync status line (sidebar, settings): its label and dot color.
/// Gold when synced, red only when iCloud needs a reconnect.
(String label, Color dot) iCloudStatus(
  BuildContext context,
  ICloudState state,
) {
  final c = context.higan;
  return switch (state) {
    .connected when ICloudStorage.folderIsInICloud => (
      t.higan.sync.synced,
      c.stamenMark,
    ),
    .needsReconnect => (t.higan.sync.reconnect, c.higan),
    _ => (t.higan.sync.localOnly, c.textTertiary),
  };
}

/// Lets the user pick an iCloud Drive folder, then reports the result
/// in a [SnackBar].
Future<void> connectICloud(BuildContext context) async {
  if (_isConnecting) return;
  _isConnecting = true;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final message = switch (await ICloudStorage.connect()) {
      .connected => t.icloud.connected,
      .connectedNotICloud => t.icloud.connectedNotICloud,
      .cancelled => null,
      .failed => ICloudStorage.lastError ?? t.icloud.failed,
    };
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  } finally {
    _isConnecting = false;
  }
}

/// A quiet card on the home pages that asks the user to connect
/// (or reconnect) iCloud. Shows nothing when connected.
/// Adds no horizontal padding; put it inside the page's gutter.
class const ICloudBanner({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!ICloudStorage.isSupported) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: ICloudStorage.state,
      builder: (context, state, _) {
        final needsReconnect = state == .needsReconnect;
        if (state != .notConnected && !needsReconnect) {
          return const SizedBox.shrink();
        }
        final c = context.higan;
        return Padding(
          padding: const .only(bottom: HiganSpace.xl),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface1,
              borderRadius: const .all(.circular(14)),
              border: Border.all(color: c.hairline),
            ),
            child: Padding(
              padding: const .fromLTRB(18, 12, 8, 12),
              child: Row(
                spacing: HiganSpace.m,
                children: [
                  SizedBox.square(
                    dimension: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: needsReconnect ? c.higan : c.textTertiary,
                        shape: .circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      spacing: 4,
                      children: [
                        HiganLabel(t.icloud.title, size: 10),
                        Text(
                          needsReconnect
                              ? t.icloud.needsReconnect
                              : t.icloud.banner,
                          style: HiganText.body(
                            context,
                            size: 14,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => connectICloud(context),
                    style: TextButton.styleFrom(foregroundColor: c.higanText),
                    child: Text(
                      needsReconnect ? t.icloud.reconnect : t.icloud.connect,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Circle button that asks iCloud Drive for the latest files,
/// then calls [onRefreshed] so the page can rescan.
/// Only shown when iCloud is connected.
class ICloudRefreshButton extends HookWidget {
  const new({super.key, required this.onRefreshed});

  final VoidCallback onRefreshed;

  @override
  Widget build(BuildContext context) {
    final state = useValueListenable(ICloudStorage.state);
    final isRefreshing = useState(false);
    if (!ICloudStorage.isSupported || state != .connected) {
      return const SizedBox.shrink();
    }

    if (isRefreshing.value) {
      return SizedBox.square(
        dimension: 36,
        child: Padding(
          padding: const .all(10),
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: context.higan.textSecondary,
          ),
        ),
      );
    }
    return HiganCircleButton(
      icon: Symbols.sync,
      tooltip: t.icloud.refresh,
      onPressed: () async {
        isRefreshing.value = true;
        try {
          await ICloudStorage.refresh();
        } finally {
          if (context.mounted) isRefreshing.value = false;
        }
        onRefreshed();
      },
    );
  }
}
