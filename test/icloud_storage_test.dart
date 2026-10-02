import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/data/prefs.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  late Directory tmp, local, cloud;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('icloud_storage_test');
    local = Directory(p.join(tmp.path, 'local'))..createSync();
    cloud = Directory(p.join(tmp.path, 'cloud'))..createSync();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  void write(Directory dir, String path, [String? content]) =>
      File(p.join(dir.path, path))
        ..createSync(recursive: true)
        ..writeAsStringSync(content ?? 'local $path');
  String? read(Directory dir, String path) {
    final file = File(p.join(dir.path, path));
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  List<String> list(Directory dir) =>
      dir
          .listSync(recursive: true)
          .map((e) => p.relative(e.path, from: dir.path))
          .toList()
        ..sort();

  test('merge moves notes and keeps both copies on collisions', () async {
    for (final path in [
      'a.sbn2',
      'a.sbn2.0',
      'a.sbn2.p',
      'b.sbn2',
      'Math/c.sbn2',
      'Math/c.sbn2.0',
      'd.sbn2',
      'e.sbn2',
      'doc.pdf',
      '.DS_Store',
      '.f.sbn2.icloud',
    ]) {
      write(local, path);
    }
    Directory(p.join(local.path, 'empty')).createSync();

    write(cloud, 'a.sbn2', 'cloud a');
    write(cloud, 'Math/c.sbn', 'cloud c'); // old format with the same name
    write(cloud, 'd.sbn2', 'cloud d');
    write(cloud, 'd (from this device).sbn2', 'cloud d2');
    write(cloud, '.e.sbn2.icloud', 'placeholder'); // e.sbn2 not downloaded
    write(cloud, 'doc.pdf', 'cloud doc');

    stows.recentFiles.value = ['/a.sbn2', '/b.sbn2'];

    await FileManager.mergeDirContents(oldDir: local, newDir: cloud);

    // nothing in the cloud was overwritten
    expect(read(cloud, 'a.sbn2'), 'cloud a');
    expect(read(cloud, 'Math/c.sbn'), 'cloud c');
    expect(read(cloud, 'd.sbn2'), 'cloud d');
    expect(read(cloud, 'd (from this device).sbn2'), 'cloud d2');
    expect(read(cloud, 'doc.pdf'), 'cloud doc');

    // renamed notes keep their assets
    expect(read(cloud, 'a (from this device).sbn2'), 'local a.sbn2');
    expect(read(cloud, 'a (from this device).sbn2.0'), 'local a.sbn2.0');
    expect(read(cloud, 'a (from this device).sbn2.p'), 'local a.sbn2.p');
    expect(read(cloud, 'b.sbn2'), 'local b.sbn2');
    expect(read(cloud, 'Math/c (from this device).sbn2'), 'local Math/c.sbn2');
    expect(
      read(cloud, 'Math/c (from this device).sbn2.0'),
      'local Math/c.sbn2.0',
    );
    expect(read(cloud, 'd (from this device 2).sbn2'), 'local d.sbn2');
    expect(read(cloud, 'e (from this device).sbn2'), 'local e.sbn2');
    expect(read(cloud, 'doc (from this device).pdf'), 'local doc.pdf');
    expect(Directory(p.join(cloud.path, 'empty')).existsSync(), true);

    // hidden files stay behind, emptied folders are removed
    expect(list(local), ['.DS_Store', '.f.sbn2.icloud']);
    expect(read(cloud, '.f.sbn2.icloud'), null);

    expect(stows.recentFiles.value, ['/a (from this device).sbn2', '/b.sbn2']);
  });

  test('merge into the same or a nested folder moves nothing', () async {
    write(local, 'a.sbn2');
    await FileManager.mergeDirContents(oldDir: local, newDir: local);
    expect(list(local), ['a.sbn2']);

    final nested = Directory(p.join(local.path, 'nested'));
    await expectLater(
      FileManager.mergeDirContents(oldDir: local, newDir: nested),
      throwsA(isA<FileSystemException>()),
    );
    expect(read(local, 'a.sbn2'), 'local a.sbn2');
  });

  test(
    'restoring the folder moves in notes written while it was unavailable',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tmp.path, // so the local folder is tmp/nts
      );
      Object? resolved = {
        'path': cloud.path,
        'bookmark': 'b2',
        'inICloud': true,
      };
      messenger.setMockMethodCallHandler(
        const MethodChannel('nts/icloud_folder'),
        (call) async => call.method == 'resolveBookmark'
            ? resolved ?? (throw PlatformException(code: 'RESOLVE_FAILED'))
            : 0,
      );
      final localNts = Directory(p.join(tmp.path, 'nts'));
      stows.icloudBookmark.value = 'b1';

      // The folder is unavailable: use the local folder, keep the bookmark
      resolved = null;
      await ICloudStorage.restoreOnStartup();
      expect(ICloudStorage.state.value, ICloudState.needsReconnect);
      expect(stows.customDataDir.value, null);
      expect(stows.icloudBookmark.value, 'b1');

      write(localNts, 'Lecture 5.sbn2');
      write(cloud, 'Lecture 4.sbn2', 'cloud 4');

      // It's back: the note written meanwhile moves in
      resolved = {'path': cloud.path, 'bookmark': 'b2', 'inICloud': true};
      await ICloudStorage.restoreOnStartup();
      expect(ICloudStorage.state.value, ICloudState.connected);
      expect(stows.customDataDir.value, cloud.path);
      expect(stows.icloudBookmark.value, 'b2');
      expect(list(cloud), ['Lecture 4.sbn2', 'Lecture 5.sbn2']);
      expect(read(cloud, 'Lecture 5.sbn2'), 'local Lecture 5.sbn2');
      expect(list(localNts), isEmpty);
    },
  );

  test('notes with assets still in iCloud are not split up', () async {
    await FileManager.init(
      documentsDirectory: cloud.path,
      shouldWatchRootDirectory: false,
    );
    for (final path in ['n.sbn2', 'n.sbn2.0', '.n.sbn2.1.icloud', 'n.sbn2.p']) {
      write(cloud, path);
    }
    final before = list(cloud);

    // Moving would leave asset 1 behind, so nothing moves
    await expectLater(
      FileManager.moveFile('/n.sbn2', '/m.sbn2'),
      throwsA(isA<FileSystemException>()),
    );
    expect(list(cloud), before);

    // Deleting also removes the placeholder
    await FileManager.deleteFile('/n.sbn2');
    expect(list(cloud), isEmpty);
  });

  test('recent notes that are only temporarily missing are kept', () async {
    await FileManager.init(
      documentsDirectory: cloud.path,
      shouldWatchRootDirectory: false,
    );
    write(cloud, 'here.sbn2');
    write(cloud, '.inICloud.sbn2.icloud');
    stows.recentFiles.value = ['/here.sbn2', '/inICloud.sbn2', '/gone.sbn2'];

    ICloudStorage.state.value = .needsReconnect;
    expect(await FileManager.getRecentlyAccessed(), ['/here']);
    expect(stows.recentFiles.value, hasLength(3));

    ICloudStorage.state.value = .connected;
    expect(await FileManager.getRecentlyAccessed(), ['/here']);
    expect(stows.recentFiles.value, ['/here.sbn2', '/inICloud.sbn2']);
  });

  test('listings ignore hidden files and iCloud placeholders', () async {
    write(cloud, 'n.sbn2');
    write(cloud, '.m.sbn2.icloud');
    write(cloud, '.DS_Store');
    write(cloud, '.hidden/x.sbn2');
    await FileManager.init(
      documentsDirectory: cloud.path,
      shouldWatchRootDirectory: false,
    );

    final children = await FileManager.getChildrenOfDirectory('/');
    expect(children!.files, ['n']);
    expect(children.directories, isEmpty);

    // a note that isn't downloaded yet still takes its name
    expect(await FileManager.suffixFilePathToMakeItUnique('/m'), '/m (2)');
  });
}
