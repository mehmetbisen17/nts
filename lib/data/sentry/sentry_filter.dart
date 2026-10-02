import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nts/data/prefs.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

abstract class SentryFilter {
  /// Patterns to redact in Sentry events.
  @visibleForTesting
  static final replacements = <Pattern, String>{
    // Local file paths
    RegExp(r'[/\\][^/\\]+\.sbn2'): '/somefile.sbn2',
    // Domain names
    RegExp(r'://[a-zA-Z0-9.-]+'): '://example.com',
    // Windows user folder (see https://stackoverflow.com/a/31976060)
    RegExp(r':[/\\]Users[/\\][^<>"/\\|?*]+'): ':\\Users\\[USER]',
    // Linux user folder
    RegExp(r'/home/[^/]+'): '/home/[USER]',
    // macOS user folder
    RegExp(r'/Users/[^/]+'): '/Users/[USER]',
  };

  static FutureOr<SentryEvent?> beforeSend(SentryEvent event, Hint hint) async {
    if (stows.sentryConsent.value != .granted) {
      // The user revoked consent but hasn't restarted the app yet.
      // Return null to discard (not send) this event.
      return null;
    }

    if (event.message != null) {
      var message = event.message!.formatted;
      var messageChanged = false;

      // Redact known patterns
      for (final entry in replacements.entries) {
        if (message.contains(entry.key)) {
          message = message.replaceAll(entry.key, entry.value);
          messageChanged = true;
        }
      }

      if (messageChanged) {
        event.message = SentryMessage(message);
      }
    }
    return event;
  }
}
