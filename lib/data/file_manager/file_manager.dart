import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:logging/logging.dart';
import 'package:nts/components/home/sort_button.dart';
import 'package:nts/data/file_manager/sandbox_migration.dart';
import 'package:nts/data/folder_style.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:nts/pages/editor/editor.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';

/// A collection of cross-platform utility functions for working with a virtual file system.
class FileManager {
  // disable constructor
  new _();

  static final log = Logger('FileManager');

  /// This isn't final because isolates sometimes init multiple times.
  /// Realistically, this value never changes.
  static late String documentsDirectory;

  static final fileWriteStream = StreamController<FileOperation>.broadcast();

  // TODO(adil192): Implement or remove this
  static String _sanitisePath(String path) => File(path).path;

  /// A regex that matches the file names/paths of asset files,
  /// including previews, e.g. `mynote.sbn2.1`.
  static final assetFileRegex = RegExp(r'\.sbn2?\.[\dp]+$');

  /// Forbidden names for files and directories (on any/all platforms).
  /// These patterns match the base name only (not the full path).
  /// Source: https://stackoverflow.com/a/31976060/
  static List<(String, RegExp)> _getForbiddenFilenamePatterns() => [
    (
      t.home.renameNote.noteNameForbiddenCharacters,
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
    ),
    (
      t.home.renameNote.noteNameReserved,
      RegExp(
        r'^((con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?)|\.+$',
        caseSensitive: false,
      ),
    ),
  ];
  static String? validateFilename(String filename) {
    if (filename.isEmpty) return t.home.renameNote.noteNameEmpty;
    for (final (error, regexp) in _getForbiddenFilenamePatterns()) {
      if (regexp.hasMatch(filename)) return error;
    }
    return null;
  }

  static Future<void> init({
    String? documentsDirectory,
    bool shouldWatchRootDirectory = true,
  }) async {
    FileManager.documentsDirectory =
        documentsDirectory ?? await getDocumentsDirectory();

    if (shouldWatchRootDirectory) unawaited(watchRootDirectory());
  }

  static Future<String> getDocumentsDirectory() async =>
      stows.customDataDir.value ?? await getDefaultDocumentsDirectory();

  /// The local notes folder, named after the app ("nts").
  ///
  /// The unsandboxed Mac app keeps it in Application Support, like it was in
  /// its sandbox container: ~/Documents would ask for permission (again
  /// after every ad-hoc signed rebuild) and may be synced by iCloud.
  static Future<String> getDefaultDocumentsDirectory() async {
    final parent = SandboxMigration.isUnsandboxedMac
        ? await getApplicationSupportDirectory()
        : await getApplicationDocumentsDirectory();
    return '${parent.path}/nts';
  }

  static Future<void> migrateDataDir() async {
    final oldDir = Directory(documentsDirectory);
    final newDir = Directory(await getDocumentsDirectory());
    if (oldDir.path == newDir.path) return;
    log.info('Migrating data directory from $oldDir to $newDir');

    late final oldDirEmpty = oldDir.existsSync()
        ? oldDir.listSync().isEmpty
        : true;
    late final newDirEmpty = newDir.existsSync()
        ? newDir.listSync().isEmpty
        : true;

    if (!oldDirEmpty && !newDirEmpty) {
      log.severe('New and old data directory aren\'t empty, can\'t migrate');
      return;
    }

    documentsDirectory = newDir.path;
    if (oldDirEmpty) {
      log.fine('Old data directory is empty or missing, nothing to migrate');
    } else {
      await moveDirContents(oldDir: oldDir, newDir: newDir);
      await oldDir.delete(recursive: true);
    }
  }

  static Future<void> moveDirContents({
    required Directory oldDir,
    required Directory newDir,
  }) async {
    await newDir.create(recursive: true);

    await for (final entity in oldDir.list(recursive: true)) {
      // Get the path under oldDir and map it into newDir.
      final relative = p.relative(entity.path, from: oldDir.path);
      final targetPath = p.join(newDir.path, relative);

      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
        continue;
      }

      if (entity is File) {
        // Ensure parent exists
        await entity.parent.create(recursive: true);

        try {
          await entity.rename(targetPath);
        } on FileSystemException catch (e) {
          // Cross device move, eg. private to public on android
          const exdev = 18;
          if (e.osError?.errorCode == exdev) {
            await entity.copy(targetPath);
            await entity.delete();
          } else {
            rethrow;
          }
        }
      }
    }
  }

  /// Moves everything in [oldDir] into [newDir] without overwriting anything.
  ///
  /// If a name is already taken in [newDir], the moved note keeps both copies
  /// by getting a " (from this device)" suffix, together with its assets:
  /// `a.sbn2`, `a.sbn2.0`, `a.sbn2.p` become `a (from this device).sbn2`, ...
  ///
  /// Hidden files (e.g. iCloud placeholders like `.a.sbn2.icloud`) stay in
  /// [oldDir]. A file only leaves [oldDir] by a rename, or by being deleted
  /// after it was fully copied. Throws on the first file that can't be moved,
  /// leaving the rest in [oldDir].
  ///
  /// With [copy], files are copied instead and [oldDir] is left as it was.
  /// A copy can be repeated: files already in [newDir] under the same name
  /// with the same bytes (e.g. from an interrupted copy) are skipped, not
  /// copied again under another name. A file that can't be copied is
  /// skipped too, and returned.
  static Future<List<String>> mergeDirContents({
    required Directory oldDir,
    required Directory newDir,
    bool copy = false,
  }) async {
    if (!oldDir.existsSync()) return const [];
    await newDir.create(recursive: true);
    final oldPath = oldDir.resolveSymbolicLinksSync();
    final newPath = newDir.resolveSymbolicLinksSync();
    if (FileSystemEntity.identicalSync(oldPath, newPath)) return const [];
    if (p.isWithin(oldPath, newPath) || p.isWithin(newPath, oldPath)) {
      throw FileSystemException(
        'The new folder can\'t be inside the old one or vice versa',
        newPath,
      );
    }

    final dirs = <String>[], otherFiles = <String>[], styles = <String>[];
    // Note name (e.g. `dir/a`) -> its files' suffixes (`.sbn2`, `.sbn2.0`...)
    final notes = <String, List<String>>{};
    await for (final entity in Directory(
      oldPath,
    ).list(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: oldPath);
      if (p.basename(relative) == FolderStyle.fileName) {
        styles.add(relative);
        continue;
      }
      if (p.split(relative).any((part) => part.startsWith('.'))) continue;
      if (entity is Directory) {
        dirs.add(relative);
      } else if (_noteFileRegex.firstMatch(relative) case final match?) {
        final name = match.group(1)!;
        (notes[name] ??= []).add(relative.substring(name.length));
      } else {
        otherFiles.add(relative);
      }
    }

    for (final dir in dirs) {
      await Directory(p.join(newPath, dir)).create(recursive: true);
    }
    final failed = <String>[];
    Future<void> merge(
      String name,
      List<String> suffixes, {
      required bool isNote,
    }) async {
      try {
        await _mergeFiles(
          oldPath,
          newPath,
          name,
          suffixes,
          isNote: isNote,
          copy: copy,
        );
      } on FileSystemException catch (e) {
        if (!copy) rethrow;
        log.warning('Couldn\'t copy $name: $e');
        failed.add(name);
      }
    }

    for (final MapEntry(key: name, value: suffixes) in notes.entries) {
      await merge(name, suffixes, isNote: true);
    }
    for (final file in otherFiles) {
      final name = p.withoutExtension(file);
      await merge(name, [file.substring(name.length)], isNote: false);
    }
    // Folder colours and icons; a folder already styled keeps its own.
    for (final style in styles) {
      final from = File(p.join(oldPath, style)), to = p.join(newPath, style);
      try {
        if (_existsOrInICloud(to)) {
          if (!copy) await from.delete();
        } else {
          await _moveOrCopyFile(from, to, copy: copy);
        }
      } on FileSystemException catch (e) {
        log.warning('Couldn\'t merge $style: $e');
      }
    }
    if (copy) return failed;

    // Remove the emptied folders, deepest first.
    // A non-recursive delete fails (and is skipped) if anything is left.
    dirs.sort((a, b) => b.length.compareTo(a.length));
    for (final dir in dirs) {
      try {
        await Directory(p.join(oldPath, dir)).delete();
      } on FileSystemException {
        // not empty, e.g. a hidden file was left behind
      }
    }
    return const [];
  }

  /// Matches a note or one of its assets, e.g. `a.sbn2` or `a.sbn2.0`.
  /// Group 1 is the note name without the extension.
  static final _noteFileRegex = RegExp(r'^(.*)\.sbn2?(\.[\dp]+)?$');

  /// Moves `oldPath/name{suffix}` for each of [suffixes] into [newPath],
  /// renaming [name] if any of them (or, for notes, any note with that name)
  /// already exists there.
  static Future<void> _mergeFiles(
    String oldPath,
    String newPath,
    String name,
    List<String> suffixes, {
    required bool isNote,
    bool copy = false,
  }) async {
    bool isTaken(String newName) => [
      for (final suffix in suffixes) '$newName$suffix',
      if (isNote) ...[
        '$newName${Editor.extension}',
        '$newName${Editor.extensionOldJson}',
      ],
    ].any((relative) => _existsOrInICloud(p.join(newPath, relative)));

    if (copy) {
      final all = suffixes;
      suffixes = [
        for (final suffix in all)
          if (!_sameBytes(
            p.join(oldPath, '$name$suffix'),
            p.join(newPath, '$name$suffix'),
          ))
            suffix,
      ];
      if (suffixes.isEmpty) return; // copied before
      // Copied in part before (the note itself goes last): the rest under
      // the same name, unless another note has it
      if (isTaken(name)) suffixes = all;
    }

    var newName = name;
    for (var i = 1; isTaken(newName); i++) {
      newName = '$name (from this device${i == 1 ? '' : ' $i'})';
    }

    // The note itself moves last: if this is interrupted, [newPath] has no
    // note with this name yet, so a retry moves the rest under the same name.
    for (final suffix in suffixes.sortedBy<num>(
      (suffix) => assetFileRegex.hasMatch(suffix) ? 0 : 1,
    )) {
      await _moveOrCopyFile(
        File(p.join(oldPath, '$name$suffix')),
        p.join(newPath, '$newName$suffix'),
        copy: copy,
      );
      if (newName != name) {
        await _renameReferences('/$name$suffix', '/$newName$suffix');
      }
    }
  }

  static bool _sameBytes(String a, String b) {
    final (fileA, fileB) = (File(a), File(b));
    if (!fileB.existsSync() || fileA.lengthSync() != fileB.lengthSync()) {
      return false;
    }
    return const ListEquality<int>().equals(
      fileA.readAsBytesSync(),
      fileB.readAsBytesSync(),
    );
  }

  static bool _existsOrInICloud(String path) =>
      FileSystemEntity.typeSync(path, followLinks: false) !=
          FileSystemEntityType.notFound ||
      File(iCloudPlaceholderPath(path)).existsSync();

  /// iOS stands in for iCloud files that aren't downloaded yet with hidden
  /// placeholders, e.g. `dir/.a.sbn2.icloud` for `dir/a.sbn2`.
  static String iCloudPlaceholderPath(String path) =>
      p.join(p.dirname(path), '.${p.basename(path)}.icloud');

  /// Moves (or with [copy], copies) [file] to [newPath], which must not
  /// exist yet.
  static Future<void> _moveOrCopyFile(
    File file,
    String newPath, {
    bool copy = false,
  }) async {
    await Directory(p.dirname(newPath)).create(recursive: true);
    if (!copy) {
      try {
        await file.rename(newPath);
        return;
      } on FileSystemException {
        // e.g. across volumes: copy, and only delete the original once copied
      }
    }
    final copied = await file.copy(newPath);
    if (copied.lengthSync() != file.lengthSync()) {
      await copied.delete();
      throw FileSystemException('Failed to copy file', file.path);
    }
    if (!copy) await file.delete();
  }

  /// Switches the app to [newDirectory], which should already contain
  /// the notes (see [mergeDirContents]).
  static Future<void> changeDocumentsDirectory(String newDirectory) async {
    documentsDirectory = newDirectory;
    await watchRootDirectory();
    await broadcastRescan();
  }

  /// Makes file lists reload, e.g. after iCloud downloaded new files.
  /// Sends one event per folder since some listeners only refresh
  /// for events inside the folder they show.
  static Future<void> broadcastRescan() async {
    final rootDir = getRootDirectory();
    if (!rootDir.existsSync()) return;
    broadcastFileWrite(.write, '/');
    await for (final entity in rootDir.list(recursive: true)) {
      if (entity is! Directory) continue;
      final path = entity.path.substring(documentsDirectory.length);
      if (path.split('/').any((part) => part.startsWith('.'))) continue;
      broadcastFileWrite(.write, path);
    }
  }

  static StreamSubscription<FileSystemEvent>? _rootDirectoryWatcher;

  @visibleForTesting
  static Future<void> watchRootDirectory() async {
    unawaited(_rootDirectoryWatcher?.cancel());
    _rootDirectoryWatcher = null;
    final rootDir = Directory(documentsDirectory);
    await rootDir.create(recursive: true);
    if (Platform.isIOS) return;
    _rootDirectoryWatcher = rootDir.watch(recursive: true).listen((event) {
      // e.g. `.DS_Store` or iCloud's temporary files
      if (p.basename(event.path).startsWith('.')) return;
      final FileOperationType type = switch (event.type) {
        FileSystemEvent.delete => .delete,
        FileSystemEvent.create => .write,
        FileSystemEvent.modify => .write,
        FileSystemEvent.move => .write,
        _ =>
          kDebugMode
              ? throw UnimplementedError(
                  'Unhandled FileSystemEvent type: ${event.type}',
                )
              : .write,
      };
      final String path = event.path
          .replaceAll('\\', '/')
          // The path may or may not be relative,
          // so remove the root directory path to make sure it's relative.
          .replaceFirst(documentsDirectory, '');
      broadcastFileWrite(type, path);
    });
  }

  @visibleForTesting
  static void broadcastFileWrite(FileOperationType type, String path) async {
    if (!fileWriteStream.hasListener) return;

    // remove extension
    if (path.endsWith(Editor.extension)) {
      path = path.substring(0, path.length - Editor.extension.length);
    } else if (path.endsWith(Editor.extensionOldJson)) {
      path = path.substring(0, path.length - Editor.extensionOldJson.length);
    }

    fileWriteStream.add(FileOperation(type, path));
  }

  /// Returns the contents of the file at [filePath].
  static Future<Uint8List?> readFile(String filePath, {int retries = 3}) async {
    filePath = _sanitisePath(filePath);

    Uint8List? result;
    final file = getFile(filePath);
    if (file.existsSync()) {
      result = await file.readAsBytes();
      if (result.isEmpty) result = null;
    } else {
      retries = 0; // don't retry if the file doesn't exist
    }

    // If result is null, try again in case the file was locked.
    if (result == null && retries > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      return readFile(filePath, retries: retries - 1);
    }
    return result;
  }

  /// Whether getFile should just return File(filePath)
  /// instead of prefixing with the documents directory.
  /// This is useful for testing when test files
  /// aren't in the documents directory.
  @visibleForTesting
  static var shouldUseRawFilePath = false;

  static File getFile(String filePath) {
    if (shouldUseRawFilePath) {
      return File(filePath);
    } else {
      assert(
        filePath.startsWith('/'),
        'Expected filePath to start with a slash, got $filePath',
      );
      return File(documentsDirectory + filePath);
    }
  }

  static Directory getRootDirectory() => Directory(documentsDirectory);

  /// Writes [toWrite] to [filePath].
  static Future<void> writeFile(
    String filePath,
    List<int> toWrite, {
    bool awaitWrite = false,
  }) async {
    filePath = _sanitisePath(filePath);
    log.fine('Writing to $filePath');

    await _saveFileAsRecentlyAccessed(filePath);

    final file = getFile(filePath);
    await _createFileDirectory(filePath);
    Future writeFuture = Future.wait([
      file.writeAsBytes(toWrite),
      // if we're using a new format, also delete the old file
      if (filePath.endsWith(Editor.extension))
        getFile(
          '${filePath.substring(0, filePath.length - Editor.extension.length)}'
          '${Editor.extensionOldJson}',
        ).delete()
        // ignore if the file doesn't exist
        .catchError((_) => File(''), test: (e) => e is PathNotFoundException),
    ]);

    void afterWrite() {
      broadcastFileWrite(FileOperationType.write, filePath);
      if (filePath.endsWith(Editor.extension)) {
        _removeReferences(
          '${filePath.substring(0, filePath.length - Editor.extension.length)}'
          '${Editor.extensionOldJson}',
        );
      }
    }

    writeFuture = writeFuture.then((_) => afterWrite());
    if (awaitWrite) await writeFuture;
  }

  static Future<void> createFolder(String folderPath) async {
    folderPath = _sanitisePath(folderPath);

    final dir = Directory(documentsDirectory + folderPath);
    await dir.create(recursive: true);
  }

  static Future exportFile(
    String fileName,
    Uint8List bytes, {
    bool isImage = false,
    required BuildContext context,
  }) async {
    File? tempFile;
    Future<File> getTempFile() async {
      final tempFolder = (await getTemporaryDirectory()).path;
      final file = File('$tempFolder/$fileName');
      await file.writeAsBytes(bytes);
      return file;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      if (isImage) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        final saved =
            await _requestPhotosPermission() &&
            (await SaverGallery.saveImage(
              Uint8List.fromList(bytes),
              fileName: fileName,
              // An album needs full Photos access on iOS; saving into the
              // library only needs the add-only access we ask for
              albumPath: Platform.isIOS ? null : 'nts',
              skipIfExists: true,
            )).isSuccess;
        if (!saved) {
          messenger?.showSnackBar(
            SnackBar(content: Text(t.common.savePhotoFailed)),
          );
        }
      } else {
        // share file
        tempFile = await getTempFile();
        if (Platform.isIOS || Platform.isMacOS) {
          if (!context.mounted) return;
          final box = context.findRenderObject() as RenderBox;
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(tempFile.path)],
              // iOS requires a sharePositionOrigin for the share sheet to appear
              sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
            ),
          );
        } else {
          await SharePlus.instance.share(
            ShareParams(files: [XFile(tempFile.path)]),
          );
        }
      }
    } else {
      // desktop, open save-as dialog
      await FilePicker.saveFile(
        fileName: fileName,
        initialDirectory: (await getDownloadsDirectory())?.path,
        type: FileType.custom,
        allowedExtensions: [fileName.split('.').last],
        bytes: bytes,
      );
    }

    // delete temp file if it isn't null
    await tempFile?.delete();
  }

  static Future<bool> _requestPhotosPermission() async {
    if (Platform.isIOS) {
      return await Permission.photosAddOnly.request().isGranted;
    } else if (!Platform.isAndroid) {
      return true;
    }

    final sdkInt = await DeviceInfoPlugin().androidInfo.then(
      (info) => info.version.sdkInt,
    );
    if (sdkInt > 33) {
      return await Permission.photos.request().isGranted;
    } else {
      return await Permission.storage.request().isGranted;
    }
  }

  /// Moves a file from [fromPath] to [toPath], returning its final path.
  ///
  /// If a file already exists at [toPath], [fromPath] will be suffixed with
  /// a number e.g. "file (1)". If [replaceExistingFile] is true, the existing
  /// file will be overwritten instead.
  ///
  /// If [replaceExistingFile] is true but the file is a reserved file name,
  /// the filename will be suffixed with a number instead
  /// (like if [replaceExistingFile] was false).
  static Future<String> moveFile(
    String fromPath,
    String toPath, {
    bool replaceExistingFile = false,
    bool alsoMoveAssets = true,
  }) async {
    fromPath = _sanitisePath(fromPath);
    toPath = _sanitisePath(toPath);

    if (!toPath.contains('/')) {
      // if toPath is a relative path
      toPath = fromPath.substring(0, fromPath.lastIndexOf('/') + 1) + toPath;
    }

    if (!replaceExistingFile || Editor.isReservedPath(toPath)) {
      toPath = await suffixFilePathToMakeItUnique(
        toPath,
        currentPath: fromPath,
      );
    }

    if (fromPath == toPath) return toPath;

    // Find the assets first: a note must never be moved without some of them
    final assets = alsoMoveAssets && !assetFileRegex.hasMatch(fromPath)
        ? _findAssets(fromPath)
        : const <String>[];
    if (assets.any((asset) => !doesFileExist('$fromPath.$asset'))) {
      // An asset is only an iCloud placeholder, which can't be moved
      unawaited(ICloudStorage.refresh());
      throw FileSystemException(t.icloud.stillDownloading, fromPath);
    }

    final fromFile = getFile(fromPath);
    final toFile = getFile(toPath);
    await _createFileDirectory(toPath);
    if (fromFile.existsSync()) {
      await fromFile.rename(toFile.path);
    } else {
      log.warning('Tried to move non-existent file from $fromPath to $toPath');
    }

    _renameReferences(fromPath, toPath);
    broadcastFileWrite(FileOperationType.delete, fromPath);
    broadcastFileWrite(FileOperationType.write, toPath);

    await Future.wait([
      for (final asset in assets)
        moveFile(
          '$fromPath.$asset',
          '$toPath.$asset',
          replaceExistingFile: replaceExistingFile,
        ),
    ]);

    return toPath;
  }

  static Future deleteFile(
    String filePath, {
    bool alsoDeleteAssets = true,
  }) async {
    filePath = _sanitisePath(filePath);

    final file = getFile(filePath);
    if (!file.existsSync()) return;
    await file.delete();

    _removeReferences(filePath);
    broadcastFileWrite(FileOperationType.delete, filePath);

    if (alsoDeleteAssets && !assetFileRegex.hasMatch(filePath)) {
      await Future.wait([
        for (final asset in _findAssets(filePath)) ...[
          deleteFile('$filePath.$asset', alsoDeleteAssets: false),
          // or its placeholder if iCloud hasn't downloaded it yet
          deleteFile(
            iCloudPlaceholderPath('$filePath.$asset'),
            alsoDeleteAssets: false,
          ),
        ],
      ]);
    }
  }

  /// The asset suffixes (`0`, `1`, ..., `p`) of the note at [filePath],
  /// including assets that iCloud hasn't downloaded yet.
  static List<String> _findAssets(String filePath) {
    bool exists(String asset) =>
        doesFileExist('$filePath.$asset') ||
        doesFileExist(iCloudPlaceholderPath('$filePath.$asset'));
    return [for (var i = 0; exists('$i'); i++) '$i', if (exists('p')) 'p'];
  }

  static Future removeUnusedAssets(
    String filePath, {
    required int numAssets,
  }) async {
    final futures = <Future>[];

    for (int assetNumber = numAssets; true; assetNumber++) {
      final assetPath = '$filePath.$assetNumber';
      if (getFile(assetPath).existsSync()) {
        futures.add(deleteFile(assetPath));
      } else {
        break;
      }
    }

    await Future.wait(futures);
  }

  static Future renameDirectory(String directoryPath, String newName) async {
    directoryPath = _sanitisePath(directoryPath);

    final directory = Directory(documentsDirectory + directoryPath);
    if (!directory.existsSync()) return;

    /// recursively find children of [directory] for [_renameReferences]
    final List<String> children = [];
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        children.add(entity.path.substring(directory.path.length));
      }
    }

    final String newPath =
        directoryPath.substring(0, directoryPath.lastIndexOf('/') + 1) +
        newName;
    await directory.rename(documentsDirectory + newPath);

    for (final child in children) {
      _renameReferences(directoryPath + child, newPath + child);
      broadcastFileWrite(FileOperationType.delete, directoryPath + child);
      broadcastFileWrite(FileOperationType.write, newPath + child);
    }
  }

  static Future deleteDirectory(
    String directoryPath, [
    bool recursive = true,
  ]) async {
    directoryPath = _sanitisePath(directoryPath);

    final directory = Directory(documentsDirectory + directoryPath);
    if (!directory.existsSync()) return;

    if (recursive) {
      // call [deleteFile] on all files that are descendants of the directory
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          await deleteFile(entity.path.substring(documentsDirectory.length));
        }
      }
    }

    await directory.delete(recursive: recursive);
  }

  /// Gets the children of a directory, separated into
  /// [DirectoryChildren.directories] and [DirectoryChildren.files].
  ///
  /// If [includeExtensions] is false (default), the extension will be removed
  /// from the file names. We use this to get all notes in a directory.
  ///
  /// If [includeAssets] is true, assets and previews will be included.
  /// We use this for syncing.
  ///
  /// Note: [includeAssets] can't be true without [includeExtension],
  /// since otherwise we wouldn't be able to tell the difference between notes
  /// and assets.
  static Future<DirectoryChildren?> getChildrenOfDirectory(
    String directory, {
    bool includeExtensions = false,
    bool includeAssets = false,
    SortMetric sortMetric = .nameAToZ,
  }) async {
    assert(
      !includeAssets || includeExtensions,
      'includeAssets can\'t be true without includeExtensions',
    );

    directory = _sanitisePath(directory);
    if (!directory.endsWith('/')) directory += '/';

    final List<String> directories = [], files = [];

    final dir = Directory(documentsDirectory + directory);
    if (!dir.existsSync()) return null;

    final int directoryPrefixLength = directory.endsWith('/')
        ? directory.length
        : directory.length + 1; // +1 for the trailing slash
    final allChildren = await dir
        .list()
        .map((FileSystemEntity entity) {
          final filePath = entity.path.substring(documentsDirectory.length);

          // skip hidden files, e.g. iCloud placeholders like `.a.sbn2.icloud`
          if (p.basename(filePath).startsWith('.')) return null;

          // directories don't need any further processing
          if (entity is Directory) return filePath;

          // filter out reserved files
          if (Editor.isReservedPath(filePath)) return null;

          late final isSbn2 = filePath.endsWith(Editor.extension);
          late final isSbn1 = filePath.endsWith(Editor.extensionOldJson);

          if (!includeExtensions) {
            if (isSbn2) {
              return filePath.substring(
                0,
                filePath.length - Editor.extension.length,
              );
            } else if (isSbn1) {
              return filePath.substring(
                0,
                filePath.length - Editor.extensionOldJson.length,
              );
            } else {
              return null; // filePath is name of some asset
            }
          } else if (!includeAssets) {
            final isAsset = !isSbn2 && !isSbn1;
            if (isAsset) return null;
          }

          return filePath;
        })
        .where((String? file) => file != null)
        // remove parent folder
        .map((file) => file!.substring(directoryPrefixLength))
        .toList();

    for (final child in allChildren) {
      if (FileManager.isDirectory(directory + child) &&
          !directories.contains(child)) {
        directories.add(child);
      } else if (!includeAssets && assetFileRegex.hasMatch(child)) {
        // if the file is an asset, don't add it to the list of files
      } else {
        files.add(child);
      }
    }

    switch (sortMetric) {
      case .nameAToZ:
        directories.sort();
        files.sort();
      case .nameZToA:
        directories.sort((child, other) => -child.compareTo(other));
        files.sort((child, other) => -child.compareTo(other));
      case .lastModifiedNewToOld:
        directories.sort();
        files.sortByCompare(
          (child) => lastModified(directory + child + Editor.extension),
          (date, other) => -date.compareTo(other),
        );
      case .lastModifiedOldToNew:
        directories.sort();
        files.sortBy(
          (child) => lastModified(directory + child + Editor.extension),
        );
    }

    return DirectoryChildren(directories, files);
  }

  /// Returns a list of all files recursively in the root directory.
  ///
  /// See [getChildrenOfDirectory] for more information on the parameters.
  static Future<List<String>> getAllFiles({
    bool includeExtensions = false,
    bool includeAssets = false,
  }) async {
    final allFiles = <String>[];
    final directories = <String>['/'];

    while (directories.isNotEmpty) {
      final directory = directories.removeLast();
      final children = await getChildrenOfDirectory(
        directory,
        includeExtensions: includeExtensions,
        includeAssets: includeAssets,
      );
      if (children == null) continue;

      for (final file in children.files) {
        allFiles.add('$directory$file');
      }
      for (final childDirectory in children.directories) {
        directories.add('$directory$childDirectory/');
      }
    }

    return allFiles;
  }

  static Future<List<String>> getRecentlyAccessed() async {
    if (!stows.recentFiles.loaded) await stows.recentFiles.waitUntilRead();
    // Delete entries for files that have been deleted outside of the app,
    // but not for files that are only missing because the notes folder
    // needs reconnecting or iCloud hasn't downloaded them yet.
    final canForget = ICloudStorage.state.value != .needsReconnect;
    for (final file in stows.recentFiles.value.toList()) {
      if (canForget &&
          !doesFileExist(file) &&
          !doesFileExist(iCloudPlaceholderPath(file))) {
        _removeReferences(file);
      }
    }
    return stows.recentFiles.value
        .where(doesFileExist)
        .map((String filePath) {
          if (filePath.endsWith(Editor.extension)) {
            return filePath.substring(
              0,
              filePath.length - Editor.extension.length,
            );
          } else if (filePath.endsWith(Editor.extensionOldJson)) {
            return filePath.substring(
              0,
              filePath.length - Editor.extensionOldJson.length,
            );
          } else {
            return filePath;
          }
        })
        .where(
          (String file) => !Editor.isReservedPath(file),
        ) // filter out reserved file names
        .toList();
  }

  /// Returns whether the [filePath] is a directory or file.
  /// Behaviour is undefined if [filePath] is not a valid path.
  static bool isDirectory(String filePath) {
    filePath = _sanitisePath(filePath);
    final directory = Directory(documentsDirectory + filePath);
    return directory.existsSync();
  }

  static bool doesFileExist(String filePath) {
    filePath = _sanitisePath(filePath);
    final file = getFile(filePath);
    return file.existsSync();
  }

  static DateTime lastModified(String filePath) {
    filePath = _sanitisePath(filePath);
    final file = getFile(filePath);
    if (!file.existsSync()) return DateTime(2023);
    return file.lastModifiedSync();
  }

  static Future<String> newFilePath([String parentPath = '/']) async {
    assert(parentPath.endsWith('/'));

    final DateTime now = DateTime.now();
    // Include the time so notes made offline on different devices
    // don't get the same name, which iCloud Drive would split up.
    final String filePath =
        '$parentPath${DateFormat("yy-MM-dd HH.mm.ss").format(now)} '
        '${t.editor.untitled}';

    return await suffixFilePathToMakeItUnique(filePath);
  }

  /// Returns a unique file path by appending a number to the end of the [filePath].
  /// e.g. "/Untitled" -> "/Untitled (2)"
  ///
  /// Providing a [currentPath] means that e.g. "/Untitled (2)" being renamed
  /// to "/Untitled" will be returned as "/Untitled (2)" not "/Untitled (3)".
  ///
  /// If [currentPath] is provided, it must
  /// end with [Editor.extension] or [Editor.extensionOldJson].
  static Future<String> suffixFilePathToMakeItUnique(
    String filePath, {
    String? intendedExtension,
    String? currentPath,
  }) async {
    String newFilePath = filePath;
    bool hasExtension = false;

    if (filePath.endsWith(Editor.extension)) {
      filePath = filePath.substring(
        0,
        filePath.length - Editor.extension.length,
      );
      newFilePath = filePath;
      hasExtension = true;
      intendedExtension ??= Editor.extension;
    } else if (filePath.endsWith(Editor.extensionOldJson)) {
      filePath = filePath.substring(
        0,
        filePath.length - Editor.extensionOldJson.length,
      );
      newFilePath = filePath;
      hasExtension = true;
      intendedExtension ??= Editor.extensionOldJson;
    } else {
      intendedExtension ??= Editor.extension;
    }

    // A note that iCloud hasn't downloaded yet also takes the name
    bool isTaken(String path) =>
        doesFileExist(path) || doesFileExist(iCloudPlaceholderPath(path));

    int i = 1;
    while (true) {
      if (!isTaken(newFilePath + Editor.extension) &&
          !isTaken(newFilePath + Editor.extensionOldJson))
        break;
      if (newFilePath + Editor.extension == currentPath) break;
      if (newFilePath + Editor.extensionOldJson == currentPath) break;
      i++;
      newFilePath = '$filePath ($i)';
    }

    return newFilePath + (hasExtension ? intendedExtension : '');
  }

  /// Imports a file from a sharing intent.
  ///
  /// [parentDir], if provided, must start and end with a slash.
  ///
  /// [extension], if provided, must start with a dot.
  /// If not provided, it will be inferred from the [path].
  ///
  /// Returns the file path of the imported file.
  static Future<String?> importFile(
    String path,
    String? parentDir, {
    String? extension,
    bool awaitWrite = true,
  }) async {
    assert(
      parentDir == null || parentDir.startsWith('/') && parentDir.endsWith('/'),
    );

    if (extension == null) {
      extension = '.${path.split('.').last}';
      assert(extension.length > 1);
    } else {
      assert(extension.startsWith('.')); // extension must start with a dot
    }

    /// The file name without its extension
    String fileName = path.split(RegExp(r'[\\/]')).last;
    fileName = fileName.substring(0, fileName.lastIndexOf('.'));
    final String importedPath;

    final writeFutures = <Future>[];

    if (extension.toLowerCase() == '.sba') {
      final inputStream = InputFileStream(path);
      final archive = ZipDecoder().decodeStream(inputStream);

      final mainFile = archive.files.cast<ArchiveFile?>().firstWhere(
        (file) =>
            file!.name.toLowerCase().endsWith('sbn') ||
            file.name.toLowerCase().endsWith('sbn2'),
        orElse: () => null,
      );
      if (mainFile == null) {
        log.severe('Failed to find main note in sba: $path');
        return null;
      }
      final mainFileExtension = '.${mainFile.name.split('.').last}'
          .toLowerCase();
      importedPath = await suffixFilePathToMakeItUnique(
        '${parentDir ?? '/'}$fileName',
        intendedExtension: mainFileExtension,
      );
      final mainFileContents = () {
        final output = OutputMemoryStream();
        mainFile.writeContent(output);
        return output.getBytes();
      }();
      writeFutures.add(
        writeFile(
          importedPath + mainFileExtension,
          mainFileContents,
          awaitWrite: awaitWrite,
        ),
      );

      // now import assets
      for (final file in archive.files) {
        if (!file.isFile) continue;
        if (file == mainFile) continue;

        final extension = file.name.split('.').last;
        final assetNumber = int.tryParse(extension);
        if (assetNumber == null) continue;
        if (assetNumber < 0) continue;

        final assetBytes = () {
          final output = OutputMemoryStream();
          file.writeContent(output);
          return output.getBytes();
        }();
        writeFutures.add(
          writeFile(
            '$importedPath$mainFileExtension.$assetNumber',
            assetBytes,
            awaitWrite: awaitWrite,
          ),
        );
      }
    } else {
      // import sbn or sbn2
      final file = File(path);
      final fileContents = await file.readAsBytes();
      importedPath = await suffixFilePathToMakeItUnique(
        '${parentDir ?? '/'}$fileName',
        intendedExtension: extension.toLowerCase(),
      );
      writeFutures.add(
        writeFile(
          importedPath + extension.toLowerCase(),
          fileContents,
          awaitWrite: awaitWrite,
        ),
      );
    }

    await Future.wait(writeFutures);

    return importedPath;
  }

  /// Creates the parent directories of filePath if they don't exist.
  static Future _createFileDirectory(String filePath) async {
    assert(filePath.contains('/'), 'filePath must be a path, not a file name');
    final parentDirectory = filePath.substring(0, filePath.lastIndexOf('/'));
    await Directory(documentsDirectory + parentDirectory)
        .create(recursive: true);
  }

  static Future _renameReferences(String fromPath, String toPath) async {
    // rename file in recently accessed
    bool replaced = false;
    for (int i = 0; i < stows.recentFiles.value.length; i++) {
      if (stows.recentFiles.value[i] != fromPath) continue;
      if (!replaced) {
        stows.recentFiles.value[i] = toPath;
        replaced = true;
      } else {
        stows.recentFiles.value.removeAt(i);
      }
    }
    stows.recentFiles.notifyListeners();
  }

  static Future _removeReferences(String filePath) async {
    // remove file from recently accessed
    for (int i = 0; i < stows.recentFiles.value.length; i++) {
      if (stows.recentFiles.value[i] != filePath) continue;
      stows.recentFiles.value.removeAt(i);
    }
    stows.recentFiles.notifyListeners();
  }

  static Future _saveFileAsRecentlyAccessed(String filePath) async {
    // don't add assets to recently accessed
    if (assetFileRegex.hasMatch(filePath)) return;

    stows.recentFiles.value.remove(filePath);
    stows.recentFiles.value.insert(0, filePath);
    if (stows.recentFiles.value.length > maxRecentlyAccessedFiles)
      stows.recentFiles.value.removeLast();

    stows.recentFiles.notifyListeners();
  }

  static const maxRecentlyAccessedFiles = 30;
}

class DirectoryChildren {
  final List<String> directories;
  final List<String> files;

  new(this.directories, this.files);

  bool onlyOneChild() => directories.length + files.length <= 1;

  bool get isEmpty => directories.isEmpty && files.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

enum FileOperationType { write, delete }

class FileOperation {
  final FileOperationType type;
  final String filePath;

  const new(this.type, this.filePath);
}
