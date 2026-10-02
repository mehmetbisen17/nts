import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/prefs.dart';
import 'package:path/path.dart' as p;

enum ICloudState { unsupported, notConnected, connected, needsReconnect }

enum ICloudConnectResult { connected, connectedNotICloud, cancelled, failed }

/// Stores the notes in a folder the user picked (e.g. in iCloud Drive),
/// which iCloud Drive then syncs between devices.
///
/// Without iCloud entitlements, the folder is remembered with a
/// security-scoped bookmark ([Stows.icloudBookmark]) that is resolved on
/// every launch; its path is then used as [FileManager.documentsDirectory].
abstract class ICloudStorage {
  static final log = Logger('ICloudStorage');

  static const _channel = MethodChannel('nts/icloud_folder');

  static bool get isSupported => Platform.isIOS || Platform.isMacOS;

  static final state = ValueNotifier(
    isSupported ? ICloudState.notConnected : ICloudState.unsupported,
  );

  static String? _folderPath;
  static String? get folderPath => _folderPath;

  static var _folderIsInICloud = false;
  static bool get folderIsInICloud => _folderIsInICloud;

  /// E.g. "iCloud Drive › nts"
  static String? get folderDisplayName {
    final path = _folderPath;
    if (path == null) return null;
    final parts = p.split(path);
    final cloudDocs = parts.lastIndexOf('com~apple~CloudDocs');
    return parts
        .skip(max(0, max(cloudDocs, parts.length - 2)))
        .map((part) => part == 'com~apple~CloudDocs' ? 'iCloud Drive' : part)
        .join(' › ');
  }

  /// A human-readable message for the last failure.
  static String? lastError;

  /// Resolves the saved folder so [FileManager.init] uses it.
  /// Must be called before [FileManager.init].
  static Future<void> restoreOnStartup() async {
    if (!isSupported) {
      state.value = .unsupported;
      return;
    }
    await Future.wait([
      stows.icloudBookmark.waitUntilRead(),
      stows.customDataDir.waitUntilRead(),
      // [FileManager.mergeDirContents] renames recent files
      stows.recentFiles.waitUntilRead(),
    ]);
    if (stows.icloudBookmark.value.isEmpty) {
      state.value = .notConnected;
      return;
    }

    try {
      final folder = await _resolveFolder();
      // A trashed folder still resolves, but notes there would be lost
      // when the Trash is emptied.
      final path = folder['path']! as String;
      if (p.split(path).contains('.Trash')) {
        throw FileSystemException('The folder is in the Trash', path);
      }
      // Notes written while the folder was unavailable (needsReconnect)
      // went to the local folder: move them in so they aren't left behind.
      // This never overwrites anything, and usually there's nothing to move.
      await FileManager.mergeDirContents(
        oldDir: Directory(await FileManager.getDefaultDocumentsDirectory()),
        newDir: Directory(path),
      );
      _setFolder(folder);
      stows.icloudBookmark.value = folder['bookmark']! as String;
      // The path can change between launches, so always use the fresh one
      stows.customDataDir.value = _folderPath;
      state.value = .connected;
    } catch (e, st) {
      log.severe('Failed to resolve the notes folder: $e', e, st);
      lastError = 'Couldn\'t open your notes folder (${_describe(e)}).';
      // Use the notes stored on this device for now. The bookmark is kept:
      // reconnecting, or the next launch that can open the folder, moves
      // these notes into it.
      stows.customDataDir.value = null;
      state.value = .needsReconnect;
    }
  }

  /// The saved folder, from its bookmark. If that fails but the saved path
  /// can still be read and written, that path: the unsandboxed Mac app
  /// doesn't need the bookmark's permission (e.g. one made by the old
  /// sandboxed app, or before a rebuild). Sandboxed (iPad), the path alone
  /// isn't accessible, so the bookmark's error is thrown.
  static Future<Map<String, Object?>> _resolveFolder() async {
    try {
      return (await _channel.invokeMapMethod<String, Object?>(
        'resolveBookmark',
        {'bookmark': stows.icloudBookmark.value},
      ))!;
    } catch (e) {
      final path = stows.customDataDir.value;
      if (path == null || !_canReadAndWrite(path)) rethrow;
      log.warning('Couldn\'t resolve the bookmark, using the saved path: $e');
      return {
        'path': path,
        'bookmark': stows.icloudBookmark.value,
        'inICloud': path.contains('/Mobile Documents/'),
      };
    }
  }

  static bool _canReadAndWrite(String path) {
    try {
      Directory(path).listSync();
      final probe = File(p.join(path, '.nts-access-check'))..createSync();
      probe.deleteSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Lets the user pick a folder (e.g. in iCloud Drive), moves the notes
  /// into it, and stores all notes there from now on.
  static Future<ICloudConnectResult> connect() async {
    if (!isSupported) return .failed;
    lastError = null;
    try {
      final folder = await _channel.invokeMapMethod<String, Object?>(
        'pickFolder',
      );
      if (folder == null) return .cancelled;
      final newPath = folder['path']! as String;

      // Notes already in an iCloud folder stay there (they're synced and
      // could be placeholders that can't be moved), others are moved in.
      if (!(state.value == .connected && _folderIsInICloud)) {
        await FileManager.mergeDirContents(
          oldDir: Directory(FileManager.documentsDirectory),
          newDir: Directory(newPath),
        );
      }

      stows.icloudBookmark.value = folder['bookmark']! as String;
      _setFolder(folder);
      await FileManager.changeDocumentsDirectory(newPath);
      // documentsDirectory already matches, so this doesn't migrate anything
      stows.customDataDir.value = newPath;
      state.value = .connected;
      unawaited(refresh());
      return _folderIsInICloud ? .connected : .connectedNotICloud;
    } catch (e, st) {
      log.severe('Failed to connect the notes folder: $e', e, st);
      lastError =
          'Couldn\'t use this folder (${_describe(e)}). '
          'Nothing was deleted: any notes already moved are in the new '
          'folder, so try again to move the rest.';
      return .failed;
    }
  }

  /// Asks iCloud to download the folder's files and rescans the file lists.
  static Future<void> refresh() async {
    final path = _folderPath;
    if (path == null || state.value != .connected) return;

    var requested = 0;
    try {
      requested =
          await _channel.invokeMethod<int>('startDownloads', {'path': path}) ??
          0;
    } catch (e, st) {
      log.warning('Failed to start iCloud downloads: $e', e, st);
    }
    await FileManager.broadcastRescan();

    if (requested <= 0) return;
    // Give iCloud a moment to download, then look again.
    // ponytail: one fixed delay; the next resume or refresh picks up the rest
    await Future.delayed(const Duration(seconds: 5));
    if (_folderPath == path) await FileManager.broadcastRescan();
  }

  static void _setFolder(Map<String, Object?> folder) {
    _folderPath = folder['path']! as String;
    _folderIsInICloud = folder['inICloud'] == true;
  }

  static String _describe(Object e) => switch (e) {
    PlatformException(:final message?) => message,
    PlatformException(:final code) => code,
    FileSystemException(:final message, :final path?) => '$message: $path',
    _ => '$e',
  };
}
