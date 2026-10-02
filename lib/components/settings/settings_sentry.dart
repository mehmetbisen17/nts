import 'package:flutter/material.dart';
import 'package:nts/components/home/sentry_consent_dialog.dart';
import 'package:nts/components/settings/settings_row.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/sentry/sentry_init.dart';
import 'package:nts/i18n/strings.g.dart';

class const SettingsSentryConsent({super.key}) extends StatelessWidget {
  String _getSubtitle() {
    final isActive = isSentryEnabled;
    if (isActive) {
      final willStayActive = stows.sentryConsent.value == .granted;
      return willStayActive
          ? t.settings.prefDescriptions.sentry.active
          : t.settings.prefDescriptions.sentry.activeUntilRestart;
    } else {
      final willStayInactive = stows.sentryConsent.value != .granted;
      return willStayInactive
          ? t.settings.prefDescriptions.sentry.inactive
          : t.settings.prefDescriptions.sentry.inactiveUntilRestart;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = t.settings.prefLabels.sentry;
    return ValueListenableBuilder(
      valueListenable: stows.sentryConsent,
      builder: (context, consent, child) {
        final subtitle = _getSubtitle();
        return SettingsRow(
          title: title,
          subtitle: subtitle,
          modified: consent != stows.sentryConsent.defaultValue,
          showChevron: true,
          onTap: () => SentryConsentDialog.show(context),
          onLongPress: () => SentryConsentDialog.show(context),
        );
      },
    );
  }
}
