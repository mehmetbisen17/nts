import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/is_this_a_test.dart';
import 'package:nts/data/prefs.dart';
import 'package:path/path.dart' as p;

/// The Mac app ran in the App Sandbox until it started running Claude Code.
/// Unsandboxed, its data lives outside the old container
/// (`~/Library/Containers/<bundle id>/Data`), so it's copied out once:
/// the settings natively before Flutter starts (`SandboxMigration` in
/// macos/Runner/MainFlutterWindow.swift), the local notes by [copyNotes].
/// The old container is never changed.
abstract final class SandboxMigration {
  static final log = Logger('SandboxMigration');

  static const _bundleId = 'com.mehmetbisen.nts';

  /// Whether this is the Mac app, running without the App Sandbox.
  static final isUnsandboxedMac =
      Platform.isMacOS &&
      !isThisATest &&
      !Platform.environment.containsKey('APP_SANDBOX_CONTAINER_ID');

  /// Where the sandboxed app kept its local notes.
  static String get oldNotesDirectory => p.join(
    Platform.environment['HOME'] ?? '',
    'Library/Containers/$_bundleId/Data/Documents/nts',
  );

  /// Copies the old container's local notes into
  /// [FileManager.getDefaultDocumentsDirectory], once. Call before
  /// [FileManager.init].
  static Future<void> copyNotes() async {
    if (!isUnsandboxedMac) return;
    await copyNotesBetween(
      Directory(oldNotesDirectory),
      Directory(await FileManager.getDefaultDocumentsDirectory()),
    );
  }

  /// Copies [oldDir] into [newDir] like [FileManager.mergeDirContents]
  /// (nothing is overwritten: a taken name gets " (from this device)"),
  /// then remembers it's done. If it's stopped (e.g. the app is quit),
  /// fails, or [oldDir] can't be seen (missing, or macOS didn't allow
  /// access), it's tried again next launch, skipping what was copied.
  ///
  /// Files that can't be read are left out (and logged) rather than tried
  /// every launch: the copied rest may have moved on (e.g. into the iCloud
  /// folder), and would be copied again beside itself.
  @visibleForTesting
  static Future<void> copyNotesBetween(
    Directory oldDir,
    Directory newDir,
  ) async {
    await stows.macSandboxNotesCopied.waitUntilRead();
    if (stows.macSandboxNotesCopied.value) return;
    if (!oldDir.existsSync()) return;
    try {
      final failed = await FileManager.mergeDirContents(
        oldDir: oldDir,
        newDir: newDir,
        copy: true,
      );
      stows.macSandboxNotesCopied.value = true;
      if (failed.isEmpty) {
        log.info('Copied the notes from ${oldDir.path} to ${newDir.path}');
      } else {
        log.severe(
          'Copied the notes from ${oldDir.path} to ${newDir.path}, except '
          '${failed.length} that couldn\'t be read (still in the old '
          'folder): ${failed.join(', ')}',
        );
      }
    } on Exception catch (e, st) {
      log.severe('Failed to copy the notes out of the old sandbox', e, st);
    }
  }
}
