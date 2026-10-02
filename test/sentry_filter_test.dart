import 'package:flutter_test/flutter_test.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/data/sentry/sentry_filter.dart';
import 'package:nts/data/sentry/sentry_init.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('Sentry filter:', () {
    const localFile = '/path/to/somenote.sbn2';

    FlavorConfig.setup();
    setUp(() {
      stows.sentryConsent.value = .granted;
    });

    test('Filter is used', () {
      final options = SentryFlutterOptions();
      populateSentryOptions(options);
      expect(options.beforeSend, SentryFilter.beforeSend);
    });

    test('Returns null if consent is not granted', () async {
      stows.sentryConsent.value = .denied;

      final originalEvent = SentryEvent(
        message: SentryMessage('User revoked consent'),
      );
      final filteredEvent = await SentryFilter.beforeSend(
        originalEvent,
        Hint(),
      );
      expect(filteredEvent, isNull);
    });

    test('Redacts local file paths', () async {
      final originalEvent = SentryEvent(
        message: SentryMessage('Local file path: $localFile'),
      );
      final filteredEvent = await SentryFilter.beforeSend(
        originalEvent,
        Hint(),
      );
      expect(
        filteredEvent?.message?.formatted,
        'Local file path: /path/to/somefile.sbn2',
      );
    });

    test('Redacts local file paths (Windows)', () async {
      final originalEvent = SentryEvent(
        message: SentryMessage('Local file path: \\path\\to\\secrets.sbn2'),
      );
      final filteredEvent = await SentryFilter.beforeSend(
        originalEvent,
        Hint(),
      );
      expect(
        filteredEvent?.message?.formatted,
        'Local file path: \\path\\to/somefile.sbn2',
      );
    });

    test('Redacts local asset paths', () async {
      final originalEvent = SentryEvent(
        message: SentryMessage('Asset: $localFile.0'),
      );
      final filteredEvent = await SentryFilter.beforeSend(
        originalEvent,
        Hint(),
      );
      expect(
        filteredEvent?.message?.formatted,
        'Asset: /path/to/somefile.sbn2.0',
      );
    });

    test('Redacts domain names', () async {
      final originalEvent = SentryEvent(
        message: SentryMessage('Domain: https://john.doe/nc/index.php/#/'),
      );
      final filteredEvent = await SentryFilter.beforeSend(
        originalEvent,
        Hint(),
      );
      expect(
        filteredEvent?.message?.formatted,
        'Domain: https://example.com/nc/index.php/#/',
      );
    });

    test('Redacts Windows user folder', () async {
      final originalEvent = SentryEvent(
        message: SentryMessage('C:\\Users\\bill\\Documents\\nts'),
      );
      final filteredEvent = await SentryFilter.beforeSend(
        originalEvent,
        Hint(),
      );
      expect(
        filteredEvent?.message?.formatted,
        'C:\\Users\\[USER]\\Documents\\nts',
      );
    });

    test('Redacts Linux user folder', () async {
      final originalEvent = SentryEvent(
        message: SentryMessage('/home/linus/Documents/nts'),
      );
      final filteredEvent = await SentryFilter.beforeSend(
        originalEvent,
        Hint(),
      );
      expect(filteredEvent?.message?.formatted, '/home/[USER]/Documents/nts');
    });

    test('Redacts macOS user folder', () async {
      final originalEvent = SentryEvent(
        message: SentryMessage('/Users/steve/Documents/nts'),
      );
      final filteredEvent = await SentryFilter.beforeSend(
        originalEvent,
        Hint(),
      );
      expect(filteredEvent?.message?.formatted, '/Users/[USER]/Documents/nts');
    });
  });
}
