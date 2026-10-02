@TestOn('linux || mac-os || windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nts/data/nts_version.dart';
import 'package:nts/data/version.dart';

const dummyChangelog = 'Release_notes_will_be_added_here';

void main() {
  test('Does bump_version.dart find changes needed?', () async {
    final result = await Process.run('dart', [
      './scripts/bump_version.dart',
      '--custom',
      buildNumber.toString(),
      '--fail-on-changes',
      '--quiet',
    ], runInShell: true);
    printOnFailure(result.stdout);
    printOnFailure(result.stderr);

    final exitCode = result.exitCode;
    if (exitCode != 0 && exitCode != 10) {
      throw Exception('Unexpected exit code: $exitCode');
    }
    expect(
      exitCode,
      isNot(equals(10)),
      reason:
          'Changes needed to be made. '
          'Please re-run `./scripts/bump_version.dart`',
    );
  });

  test('Check for dummy text in changelogs', () async {
    final flatpakMetadata = File('flatpak/com.mehmetbisen.nts.metainfo.xml');
    expect(flatpakMetadata.existsSync(), true);
    final flatpakMetadataContents = await flatpakMetadata.readAsString();
    expect(
      flatpakMetadataContents,
      isNot(contains(dummyChangelog)),
      reason: 'Dummy text found in Flatpak changelog',
    );
  });

  test('Check that metainfo <release> tags are in the right place', () async {
    final flatpakMetadata = File('flatpak/com.mehmetbisen.nts.metainfo.xml');
    expect(flatpakMetadata.existsSync(), true);
    final flatpakMetadataContents = await flatpakMetadata.readAsString();

    final releaseParentTag = flatpakMetadataContents.indexOf('<releases');
    expect(
      releaseParentTag,
      isNot(-1),
      reason: 'No <releases> tag found in Flatpak metainfo',
    );
    final releaseTag = flatpakMetadataContents.indexOf('<release ');
    expect(
      releaseTag,
      isNot(-1),
      reason: 'No <release> tag found in Flatpak metainfo',
    );

    expect(
      releaseTag,
      greaterThan(releaseParentTag),
      reason: '<release> tag is not inside <releases> tag',
    );
  });

  test('Test that buildNumber parses to buildName', () {
    final fromNumber = NtsVersion.fromNumber(buildNumber);
    final fromName = NtsVersion.fromName(buildName);

    expect(
      fromNumber.buildNumberWithoutRevision,
      fromName.buildNumberWithoutRevision,
    );

    expect(fromNumber.buildName, fromName.buildName);
  });

  group('NtsVersion class', () {
    test('getters', () {
      final version = NtsVersion.fromNumber(127018);
      expect(version.buildName, '1.27.1');
      expect(version.buildNameWithCommas, '1,27,1');
      expect(version.buildNumber, 127018);
      expect(version.buildNumberWithoutRevision, 127010);
      expect(version.copyWith(revision: 5).buildNumber, 127015);
    });
    test('Equality', () {
      final version = NtsVersion.fromNumber(127018);

      final sameVersion = NtsVersion.fromNumber(127018);
      expect(version == sameVersion, true);
      final sameVersionRevised = NtsVersion.fromNumber(127019);
      expect(version == sameVersionRevised, true);

      final previousVersion = NtsVersion.fromNumber(127000);
      expect(version == previousVersion, false);
      final nextVersion = NtsVersion.fromNumber(127020);
      expect(version == nextVersion, false);
    });
    test('Object overrides', () {
      final version = NtsVersion.fromNumber(127018);
      expect(version.toString(), '1.27.1');
      expect(version.hashCode, Object.hash(1, 27, 1));
    });
    test('bumpMajor', () {
      final version = NtsVersion.fromNumber(127018);
      final bumped = version.bumpMajor();
      expect(bumped.buildName, '2.0.0');
    });
    test('bumpMinor', () {
      final version = NtsVersion.fromNumber(127018);
      final bumped = version.bumpMinor();
      expect(bumped.buildName, '1.28.0');
    });
    test('bumpPatch', () {
      final version = NtsVersion.fromNumber(127018);
      final bumped = version.bumpPatch();
      expect(bumped.buildName, '1.27.2');
    });
  });
}
