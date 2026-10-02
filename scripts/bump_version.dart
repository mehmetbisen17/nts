#!/usr/bin/env dart

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/args.dart';
import 'package:intl/intl.dart';
import 'package:nts/data/nts_version.dart';
import 'package:nts/data/version.dart' as old_version_file;

final oldVersion = NtsVersion.fromName(old_version_file.buildName);
late final NtsVersion newVersion;
late final String editor;
late final bool failOnChanges;
late final bool quiet;

const dummyChangelog = 'Release_notes_will_be_added_here';

enum ErrorCodes(final int code) {
  noError(0),
  noVersionSpecified(1),
  noEditorFound(5),
  changesNeeded(10),
}

Future<void> main(List<String> args) async {
  parseArgs(args);
  await findEditor();
  await updateAllFiles();
}

void parseArgs(List<String> args) {
  final parser = ArgParser()
    ..addFlag('major', abbr: 'M', negatable: false, help: 'Bump major version')
    ..addFlag('minor', abbr: 'm', negatable: false, help: 'Bump minor version')
    ..addFlag('patch', abbr: 'p', negatable: false, help: 'Bump patch version')
    ..addFlag(
      'same',
      abbr: 's',
      negatable: false,
      help:
          'Use the existing buildNumber (currently ${old_version_file.buildNumber})',
    )
    ..addOption(
      'custom',
      abbr: 'c',
      help:
          'Use a custom buildName (e.g. ${old_version_file.buildName}) or buildNumber (e.g. ${old_version_file.buildNumber})',
    )
    ..addFlag(
      'fail-on-changes',
      abbr: 'f',
      negatable: false,
      help: 'Fail if any changes need to be made',
    )
    ..addFlag('quiet', abbr: 'q', negatable: false, help: 'Don\'t open editor')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  final results = parser.parse(args);

  failOnChanges = results.flag('fail-on-changes');
  quiet = results.flag('quiet');

  if (results.flag('help')) {
    print(parser.usage);
    exit(ErrorCodes.noError.code);
  } else if (results.flag('major')) {
    newVersion = oldVersion.bumpMajor();
  } else if (results.flag('minor')) {
    newVersion = oldVersion.bumpMinor();
  } else if (results.flag('patch')) {
    newVersion = oldVersion.bumpPatch();
  } else if (results.flag('same')) {
    newVersion = oldVersion;
  } else if (results.option('custom') != null) {
    final custom = results['custom']!;
    late final buildNumber = int.tryParse(custom);
    if (custom.contains('.')) {
      newVersion = .fromName(custom);
    } else if (buildNumber != null) {
      newVersion = .fromNumber(buildNumber);
    } else {
      print('Invalid custom version: $custom');
      print(parser.usage);
      exit(ErrorCodes.noVersionSpecified.code);
    }
  } else {
    print('No version specified');
    print(parser.usage);
    exit(ErrorCodes.noVersionSpecified.code);
  }

  print(
    'Bumping version from ${oldVersion.buildName} to ${newVersion.buildName}',
  );
}

Future<String> findEditor() async {
  if (quiet) {
    print('Will not open editor');
    return editor = 'echo';
  }

  final termProgram = Platform.environment['TERM_PROGRAM'];
  if (termProgram == 'zed') {
    print('Using Zed as editor');
    return editor = 'zed';
  } else if (termProgram == 'vscode') {
    print('Using Visual Studio Code as editor');
    return editor = 'code';
  }

  final whichCode = await Process.run('which', ['code']);
  if (whichCode.exitCode == 0) {
    print('Using Visual Studio Code as editor');
    return editor = 'code';
  }

  final env = Platform.environment['EDITOR'];
  if (env != null) {
    print('Using $editor as editor');
    return editor = env;
  }

  print('No editor found. Please set the EDITOR environment variable');
  exit(ErrorCodes.noEditorFound.code);
}

Future<void> updateAllFiles() async {
  // update windows installer
  await File('installers/desktop_inno_script.iss').replace({
    // e.g. #define MyAppVersion "0.5.5"
    RegExp(r'#define MyAppVersion .+'):
        '#define MyAppVersion "${newVersion.buildName}"',
  });

  // update windows runner
  await File('windows/runner/Runner.rc').replace({
    // e.g. #define VERSION_AS_NUMBER 0,5,5,0
    RegExp(r'#define VERSION_AS_NUMBER .+'):
        '#define VERSION_AS_NUMBER ${newVersion.buildNameWithCommas},0',
    // e.g. #define VERSION_AS_STRING "0.5.5.0"
    RegExp(r'#define VERSION_AS_STRING .+'):
        '#define VERSION_AS_STRING "${newVersion.buildName}.0"',
  });

  // update version file
  await File('lib/data/version.dart').replace({
    // e.g. const int buildNumber = 5050;
    RegExp(r'buildNumber = .+;'): 'buildNumber = ${newVersion.buildNumber};',
    // e.g. const String buildName = '0.5.5';
    RegExp(r'buildName = .+;'): "buildName = '${newVersion.buildName}';",
    // e.g. const int buildYear = 2023;
    RegExp(r'buildYear = .+;'): 'buildYear = ${DateTime.now().year};',
  });

  // update pubspec
  await File('pubspec.yaml').replace({
    // e.g. version: 5.5.0+5050
    RegExp(r'version: .+'):
        'version: ${newVersion.buildName}+${newVersion.buildNumber}',
  });

  // update snap
  await File('snap/snapcraft.yaml').replace({
    // e.g. source-tag: 'v0.5.5'
    RegExp(r"source-tag: 'v.+"): "source-tag: 'v${newVersion.buildName}'",
  });

  // update flatpak changelog
  final metainfoFile = File('flatpak/com.mehmetbisen.nts.metainfo.xml');
  final metainfoLines = await metainfoFile.readAsLines();
  final originalMetainfoLines = metainfoLines.toList();
  if (await metainfoFile.contains(newVersion.buildName)) {
    print('<release> tag already exists in flatpak file');
  } else {
    if (failOnChanges) {
      print('Failed: No release tag found at ${metainfoFile.path}');
      exit(ErrorCodes.changesNeeded.code);
    }
    print('Adding a new <release> tag to flatpak file');
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
    final releaseTag =
        '''
        <release version="${newVersion.buildName}" date="$date">
            <description>
                <ul>
                    <li>$dummyChangelog</li>
                </ul>
            </description>
        </release>''';
    final index =
        metainfoLines.indexWhere((line) => line.endsWith('<releases>')) + 1;
    metainfoLines.insert(index, releaseTag);
  }
  if (!listEquals(metainfoLines, originalMetainfoLines)) {
    if (failOnChanges) {
      print('Failed: Misc change found for ${metainfoFile.path}');
      exit(ErrorCodes.changesNeeded.code);
    }
    if (metainfoLines.last.isNotEmpty) metainfoLines.add('');
    await metainfoFile.writeAsString(metainfoLines.join('\n'));
  }

  if (!failOnChanges) {
    // Skipped if we're running a test.
    await Process.run(
      './scripts/src/fdroid_generate_pubspec_lock.sh',
      [],
      runInShell: true,
    );
  }

  print('');
  print('Make sure to update the changelog in ${metainfoFile.path}');

  // open changelog files in editor
  if (!quiet) {
    await Process.run(editor, [metainfoFile.path], runInShell: true);
  }
}

extension on File {
  Future<bool> contains(Pattern pattern) async {
    final content = await readAsString();
    return content.contains(pattern);
  }

  Future<void> replace(Map<RegExp, String> replacements) async {
    var matches = 0;
    final lines = await readAsLines();
    for (var i = 0; i < lines.length; i++) {
      for (final pattern in replacements.keys) {
        if (pattern.hasMatch(lines[i])) {
          matches++;
          final oldLine = lines[i];
          lines[i] = lines[i].replaceFirst(pattern, replacements[pattern]!);
          if (failOnChanges && lines[i] != oldLine) {
            print('Failed: Changes needed in $path');
            exit(ErrorCodes.changesNeeded.code);
          }
        }
      }
    }
    if (lines.last.isNotEmpty) lines.add('');
    await writeAsString(lines.join('\n'));

    if (matches >= replacements.length) {
      print('Updated $path with all $matches replacements');
    } else {
      print(
        'Updated $path with $matches out of ${replacements.length} '
        'replacements (${replacements.length - matches} missed)',
      );
    }
  }
}

bool listEquals<T>(List<T> list, List<T> other) {
  if (list.length != other.length) return false;
  for (var i = 0; i < list.length; i++) {
    if (list[i] != other[i]) return false;
  }
  return true;
}
