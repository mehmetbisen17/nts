import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/data/nts_links.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/sentry/sentry_init.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

class const SentryConsentDialog({super.key}) extends StatelessWidget {
  static Future<void> showIfNeeded(BuildContext context) async {
    // Don't ask on FOSS builds
    if (!isSentryAvailable) return;

    // Don't ask if consent is already known
    assert(
      stows.sentryConsent.loaded,
      'Sentry consent should be loaded in initSentry',
    );
    if (stows.sentryConsent.value != .unknown) return;

    // Show the dialog
    await show(context);
  }

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const SentryConsentDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return AlertDialog(
      title: Text(t.sentry.consent.title),
      scrollable: true,
      content: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: t.sentry.consent.description.question),
            const TextSpan(text: '\n\n'),
            TextSpan(text: t.sentry.consent.description.scope),
            const TextSpan(text: '\n\n'),
            TextSpan(
              text: isSentryEnabled
                  ? t.sentry.consent.description.currentlyOn
                  : t.sentry.consent.description.currentlyOff,
            ),
            const TextSpan(text: '\n\n'),
            t.sentry.consent.description.learnMoreInPrivacyPolicy(
              link: (text) => TextSpan(
                text: text,
                style: TextStyle(
                  color: c.text,
                  decoration: .underline,
                  decorationColor: c.textTertiary,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    launchUrl(Uri.parse(privacyPolicyUrl));
                  },
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (stows.sentryConsent.value == .unknown)
          TextButton(
            onPressed: () {
              stows.sentryConsent.value = .unknown;
              Navigator.of(context).pop();
            },
            child: Text(t.sentry.consent.answers.later),
          ),
        OutlinedButton(
          onPressed: () {
            stows.sentryConsent.value = .denied;
            Navigator.of(context).pop();
          },
          child: Text(t.sentry.consent.answers.no),
        ),
        FilledButton(
          onPressed: () {
            stows.sentryConsent.value = .granted;
            Navigator.of(context).pop();
          },
          child: Text(t.sentry.consent.answers.yes),
        ),
      ],
    );
  }
}
