import 'dart:io';

import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/prefs.dart';

/// Copies the notes in test/demo_notes into the notes folder
/// and makes them the recent notes.
Future<void> setupDemoFiles() async {
  const demoFiles = <String>[
    // These files will be at the top of recent files
    '/Annotate images and diagrams.sbn2',
    '/Golden ratio.sbn2',
    '/Import PDFs.sbn2',
    '/Metric Spaces Week 1.sbn2',
    '/You can type notes too!.sbn2',
  ];
  final fillerFiles = <String>[];
  await Future.wait(
    Directory('test/demo_notes/')
        .listSync()
        .whereType<File>()
        .map((file) async {
          /// The file name starting with a slash
          final fileName = file.path.substring(file.path.lastIndexOf('/'));
          if (fileName.endsWith('.sbn2') || fileName.endsWith('.sbn')) {
            if (!demoFiles.contains(fileName)) fillerFiles.add(fileName);
          }
          final bytes = await file.readAsBytes();
          final dstFile = FileManager.getFile(fileName);
          await dstFile.create(recursive: true);
          return dstFile.writeAsBytes(bytes);
        }),
  );
  stows.recentFiles.value = [...demoFiles, ...fillerFiles..sort()];
}
