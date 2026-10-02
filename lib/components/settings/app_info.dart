import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/is_this_a_test.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/version.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

class const AppInfo({super.key}) extends StatelessWidget {
  static final Uri sponsorUrl = Uri.parse(
    'https://github.com/sponsors/adil192',
  );
  static final Uri privacyPolicyUrl = Uri.parse(
    'https://saber.adil.hanney.org/privacy-policy/',
  );
  static final Uri licenseUrl = Uri.parse(
    'https://github.com/saber-notes/saber/blob/main/LICENSE.md',
  );
  static final Uri releasesUrl = Uri.parse(
    'https://github.com/saber-notes/saber/releases',
  );

  static String get info => [
    // Tests use static values to improve reducibility
    if (isThisATest) 'v1.35.1' else 'v$buildName',
    if (FlavorConfig.flavor.isNotEmpty) FlavorConfig.flavor,
    if (kDebugMode && !isThisATest) t.appInfo.debug,
    if (isThisATest) '(135010)' else '($buildNumber)',
  ].join(' ');

  /// A mono readout, e.g. "NTS · V1.35.1 (135010)". Tap for the about dialog.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showAboutDialog(context),
      borderRadius: const .all(.circular(4)),
      child: Padding(
        padding: const .symmetric(vertical: 4),
        child: ValueListenableBuilder(
          valueListenable: stows.locale,
          builder: (context, _, _) => HiganLabel('nts · $info'),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) => showAboutDialog(
    context: context,
    applicationVersion: info,
    applicationIcon: Image.asset('assets/icon/icon.png', width: 50, height: 50),
    applicationLegalese: t.appInfo.licenseNotice(buildYear: buildYear),
    children: [
      const SizedBox(height: 10),
      if (!Platform.isIOS && !Platform.isMacOS)
        // Apple rejected the app for having donations not through the App Store
        TextButton(
          onPressed: () => launchUrl(sponsorUrl),
          child: SizedBox(
            width: double.infinity,
            child: Text(t.appInfo.sponsorButton),
          ),
        ),
      TextButton(
        onPressed: () => launchUrl(licenseUrl),
        child: SizedBox(
          width: double.infinity,
          child: Text(t.appInfo.licenseButton),
        ),
      ),
      TextButton(
        onPressed: () => launchUrl(privacyPolicyUrl),
        child: SizedBox(
          width: double.infinity,
          child: Text(t.appInfo.privacyPolicyButton),
        ),
      ),
    ],
  );
}
