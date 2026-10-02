import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/home/grid_folders.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/folder_style.dart';

void main() {
  test('a folder keeps its colour and icon in a hidden file', () async {
    FlavorConfig.setup();
    final root = Directory.systemTemp.createTempSync('folderStyle');
    addTearDown(() => root.deleteSync(recursive: true));
    FileManager.documentsDirectory = root.path;
    Directory('${root.path}/School').createSync();

    expect(await FolderStyle.read('/School'), FolderStyle.none);

    const style = FolderStyle(color: 'moss', emblem: 'spiderLily');
    await FolderStyle.write('/School', style);
    expect(await FolderStyle.read('/School/'), style);

    // It isn't a note, so the folder still counts as empty
    final info = await FolderInfo.load('/School');
    expect(info.notes, 0);
    expect(info.style, style);

    // Unknown values (e.g. from a newer app) are ignored
    File('${root.path}/School/${FolderStyle.fileName}')
        .writeAsStringSync('{"color": "neon", "emblem": "lotus"}');
    expect(
      await FolderStyle.read('/School'),
      const FolderStyle(emblem: 'lotus'),
    );

    await FolderStyle.write('/School', FolderStyle.none);
    expect(
      File('${root.path}/School/${FolderStyle.fileName}').existsSync(),
      isFalse,
    );
  });
}
