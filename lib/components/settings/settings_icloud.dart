import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nts/components/icloud/icloud_widgets.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/i18n/strings.g.dart';

/// The iCloud card in settings: the same status line as the sidebar
/// (see [iCloudStatus]), where notes are saved, and one button.
class const SettingsICloud({super.key}) extends HookWidget {
  static const _narrow = 520.0;

  @override
  Widget build(BuildContext context) {
    final state = useValueListenable(ICloudStorage.state);
    // Changing folders keeps [state] as connected, so rebuild manually.
    final connectCount = useState(0);
    if (!ICloudStorage.isSupported || state == .unsupported) {
      return const SizedBox.shrink();
    }

    final c = context.higan;
    final inICloud = ICloudStorage.folderIsInICloud;
    final (status, dot) = iCloudStatus(context, state);
    // A red warning only when something needs doing.
    final (String title, String? warning, Color warningColor) = switch (state) {
      .connected => (
        t.icloud.savingTo(folder: ICloudStorage.folderDisplayName ?? ''),
        inICloud ? null : t.icloud.notInICloud,
        c.textSecondary,
      ),
      .needsReconnect => (
        t.icloud.needsReconnect,
        ICloudStorage.lastError,
        c.higanText,
      ),
      _ => (t.icloud.banner, null, c.textSecondary),
    };

    Future<void> onPressed() async {
      await connectICloud(context);
      if (context.mounted) connectCount.value++;
    }

    // Red only when something needs doing.
    final button = state == .connected
        ? OutlinedButton(
            onPressed: onPressed,
            child: Text(t.icloud.changeFolder),
          )
        : FilledButton(
            onPressed: onPressed,
            child: Text(
              state == .needsReconnect
                  ? t.icloud.reconnect
                  : t.icloud.connectICloud,
            ),
          );

    final text = Column(
      crossAxisAlignment: .start,
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
            Flexible(child: HiganLabel(status)),
          ],
        ),
        const SizedBox(height: HiganSpace.m),
        Text(title, style: HiganText.body(context)),
        if (warning != null) ...[
          const SizedBox(height: 3),
          Text(
            warning,
            style: HiganText.body(context, size: 13, color: warningColor),
          ),
        ],
        const SizedBox(height: 3),
        Text(
          t.icloud.help,
          style: HiganText.body(context, size: 13, color: c.textSecondary),
        ),
      ],
    );

    return Padding(
      padding: const .only(top: HiganSpace.xxl),
      child: Container(
        padding: const .all(HiganSpace.l + 2),
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: const .all(.circular(HiganRadius.card)),
          border: Border.all(color: c.hairline),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < _narrow
              ? Column(
                  crossAxisAlignment: .start,
                  spacing: HiganSpace.l,
                  children: [text, button],
                )
              : Row(
                  spacing: HiganSpace.xl,
                  children: [
                    Expanded(child: text),
                    button,
                  ],
                ),
        ),
      ),
    );
  }
}
