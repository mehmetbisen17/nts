import 'package:flutter_test/flutter_test.dart';
import 'package:nts/data/flavor_config.dart';
import 'package:nts/data/prefs.dart';

void main() {
  test('FolderViewMode remembers each folder, defaults to gallery', () {
    FlavorConfig.setup();
    addTearDown(() => stows.folderViewModes.value = const {});

    expect(FolderViewMode.of('/Maths'), FolderViewMode.gallery);

    FolderViewMode.set('/Maths/', .list);
    expect(FolderViewMode.of('/Maths'), FolderViewMode.list);
    expect(FolderViewMode.of('/Physics'), FolderViewMode.gallery);

    FolderViewMode.set('', .list);
    expect(FolderViewMode.of('/'), FolderViewMode.list);

    FolderViewMode.set(FolderViewMode.recentKey, .list);
    FolderViewMode.set('/Maths', .gallery);
    expect(stows.folderViewModes.value, {'/': 'list', '@recent': 'list'});
  });
}
