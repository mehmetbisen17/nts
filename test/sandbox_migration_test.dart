import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/data/file_manager/sandbox_migration.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/icloud/icloud_storage.dart';
import 'package:nts/data/prefs.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  late Directory tmp, old, fresh;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sandbox_migration_test');
    old = Directory(p.join(tmp.path, 'container/Documents/nts'))
      ..createSync(recursive: true);
    fresh = Directory(p.join(tmp.path, 'Application Support/nts'));
    stows.macSandboxNotesCopied.value = false;
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  void write(Directory dir, String path, [String? content]) =>
      File(p.join(dir.path, path))
        ..createSync(recursive: true)
        ..writeAsStringSync(content ?? 'old $path');
  Map<String, String> contents(Directory dir) => {
    for (final file in dir.listSync(recursive: true).whereType<File>())
      p.relative(file.path, from: dir.path): file.readAsStringSync(),
  };

  test('tests never touch the real app data', () {
    expect(SandboxMigration.isUnsandboxedMac, isFalse);
  });

  test('copies the notes once, without changing the old container', () async {
    for (final path in ['a.sbn2', 'a.sbn2.0', 'Math/c.sbn2', 'doc.pdf']) {
      write(old, path);
    }
    write(fresh, 'a.sbn2', 'new a');
    final before = contents(old);

    await SandboxMigration.copyNotesBetween(old, fresh);

    expect(contents(old), before);
    expect(contents(fresh), {
      'a.sbn2': 'new a', // never overwritten
      'a (from this device).sbn2': 'old a.sbn2',
      'a (from this device).sbn2.0': 'old a.sbn2.0',
      'Math/c.sbn2': 'old Math/c.sbn2',
      'doc.pdf': 'old doc.pdf',
    });
    expect(stows.macSandboxNotesCopied.value, isTrue);

    // Only once
    write(old, 'later.sbn2');
    await SandboxMigration.copyNotesBetween(old, fresh);
    expect(File(p.join(fresh.path, 'later.sbn2')).existsSync(), isFalse);
  });

  test('an interrupted copy is finished next launch, not doubled', () async {
    for (final path in ['a.sbn2', 'a.sbn2.0', 'b.sbn2', 'c.sbn2']) {
      write(old, path);
    }
    // The last launch copied a and b's picture, then was quit
    write(fresh, 'a.sbn2', 'old a.sbn2');
    write(fresh, 'a.sbn2.0', 'old a.sbn2.0');
    write(fresh, 'b.sbn2.0', 'old b.sbn2.0');

    await SandboxMigration.copyNotesBetween(old, fresh);
    expect(contents(fresh), {
      'a.sbn2': 'old a.sbn2',
      'a.sbn2.0': 'old a.sbn2.0',
      'b.sbn2.0': 'old b.sbn2.0',
      'b.sbn2': 'old b.sbn2',
      'c.sbn2': 'old c.sbn2',
    });
    expect(stows.macSandboxNotesCopied.value, isTrue);
  });

  test(
    'a file that can\'t be read doesn\'t make it copy every launch',
    () async {
      write(old, 'a.sbn2');
      write(old, 'locked.sbn2');
      final locked = File(p.join(old.path, 'locked.sbn2'));
      await Process.run('chmod', ['000', locked.path]);
      addTearDown(() => Process.run('chmod', ['644', locked.path]));

      await SandboxMigration.copyNotesBetween(old, fresh);
      expect(contents(fresh), {'a.sbn2': 'old a.sbn2'});
      expect(stows.macSandboxNotesCopied.value, isTrue);
      expect(locked.existsSync(), isTrue, reason: 'left in the old folder');
    },
  );

  test('tries again next launch if the old notes can\'t be seen', () async {
    old.deleteSync(recursive: true);
    await SandboxMigration.copyNotesBetween(old, fresh);
    expect(stows.macSandboxNotesCopied.value, isFalse);
    expect(fresh.existsSync(), isFalse);
  });

  group('iCloud folder whose bookmark doesn\'t resolve', () {
    late Directory cloud;
    setUp(() {
      cloud = Directory(p.join(tmp.path, 'cloud'))..createSync();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tmp.path, // so the local folder is tmp/nts
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('nts/icloud_folder'),
        (call) async => call.method == 'resolveBookmark'
            ? throw PlatformException(code: 'RESOLVE_FAILED')
            : 0,
      );
      stows.icloudBookmark.value = 'old bookmark';
    });

    test('uses the saved path if it can be read and written', () async {
      stows.customDataDir.value = cloud.path;
      await ICloudStorage.restoreOnStartup();
      expect(ICloudStorage.state.value, ICloudState.connected);
      expect(ICloudStorage.folderPath, cloud.path);
      expect(stows.customDataDir.value, cloud.path);
      expect(stows.icloudBookmark.value, 'old bookmark');
      expect(cloud.listSync(), isEmpty); // the write check cleaned up
    });

    test('needs reconnecting if the path doesn\'t work either', () async {
      // e.g. sandboxed on iPad, where the path alone isn't accessible
      stows.customDataDir.value = p.join(tmp.path, 'missing');
      await ICloudStorage.restoreOnStartup();
      expect(ICloudStorage.state.value, ICloudState.needsReconnect);
      expect(stows.customDataDir.value, isNull);
      expect(stows.icloudBookmark.value, 'old bookmark');
    });
  });
}
