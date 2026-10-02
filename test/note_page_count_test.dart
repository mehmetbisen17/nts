import 'dart:io';

import 'package:bson/bson.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nts/components/home/preview_card.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/pages/editor/editor.dart';

void main() {
  test('countSbnPages counts up to the last non-empty page', () {
    final bytes = BsonCodec.serialize({
      'v': 19,
      'ni': 0,
      'b': 0xFFFFFFFF,
      'p': 'none',
      'z': [
        {
          'w': 1000.0,
          'h': 1400.0,
          's': [
            {'x': 1},
          ],
        },
        {'w': 1000.0, 'h': 1400.0},
        {
          'w': 1000.0,
          'h': 1400.0,
          'q': [
            {'insert': 'hi\n'},
          ],
        },
        {'w': 1000.0, 'h': 1400.0}, // the editor's trailing empty page
      ],
      'c': 2,
    }).byteList;
    expect(countSbnPages(bytes), 3);
    expect(countSbnPages(bytes.sublist(0, bytes.length ~/ 2)), isNull);
  });

  test('countSbnPages agrees with the editor on real notes', () async {
    FlavorConfig.setup();
    FileManager.documentsDirectory = 'test/demo_notes';
    for (final file in Directory('test/demo_notes').listSync()) {
      if (!file.path.endsWith(Editor.extension)) continue;
      final path = file.path.substring(
        'test/demo_notes'.length,
        file.path.length - Editor.extension.length,
      );
      final bytes = (file as File).readAsBytesSync();
      final coreInfo = await EditorCoreInfo.loadFromFileContents(
        bsonBytes: bytes,
        path: path,
        onlyFirstPage: false,
      );
      var pages = coreInfo.pages.length;
      while (pages > 1 && coreInfo.pages[pages - 1].isEmpty) {
        pages--;
      }
      expect(countSbnPages(bytes), pages, reason: path);
    }
  });
}
