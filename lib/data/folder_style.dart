import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/data/file_manager/file_manager.dart';

/// A folder's colour and emblem, to tell folders apart.
///
/// Saved as [fileName] inside the folder, so it syncs over iCloud Drive
/// and follows the folder when it's renamed or moved. (Hidden files
/// aren't listed as notes, and don't stop a folder counting as empty.)
class FolderStyle {
  const new({this.color, this.emblem});

  /// A key of [colors], or null for the plain tile.
  final String? color;

  /// A key of [emblems], or null for none.
  final String? emblem;

  static const none = FolderStyle();
  static const fileName = '.nts-folder.json';

  /// Bumped when a style is saved, so the folder list and the sidebar
  /// show it. (The hidden file isn't announced like notes are.)
  static final changed = ValueNotifier(0);
  static final log = Logger('FolderStyle');

  bool get isNone => color == null && emblem == null;

  /// Muted earth and dye colours that sit with the spider lily's red
  /// without shouting: tiles are only tinted with them.
  static const colors = <String, Color>{
    'lily': Color(0xFFB4544C),
    'persimmon': Color(0xFFB9774A),
    'ochre': Color(0xFFAD9147),
    'moss': Color(0xFF71855A),
    'teal': Color(0xFF4E8380),
    'indigo': Color(0xFF52668F),
    'wisteria': Color(0xFF7E6A9B),
    'plum': Color(0xFF9A5A78),
    'stone': Color(0xFF7F7B74),
  };

  /// Flowers first (the spider lily is drawn, not an icon), then a few
  /// subjects. Null for the spider lily.
  static const emblems = <String, IconData?>{
    'spiderLily': null,
    'lotus': Symbols.spa,
    'blossom': Symbols.local_florist,
    'bloom': Symbols.filter_vintage,
    'leaf': Symbols.eco,
    'sprout': Symbols.psychiatry,
    'moon': Symbols.bedtime,
    'star': Symbols.star,
    'book': Symbols.menu_book,
    'science': Symbols.science,
    'math': Symbols.function,
    'code': Symbols.code,
  };

  Color? get tint => colors[color];

  static String _path(String folderPath) {
    final dir = folderPath.endsWith('/') ? folderPath : '$folderPath/';
    return '${FileManager.documentsDirectory}$dir$fileName';
  }

  static Future<FolderStyle> read(String folderPath) async {
    try {
      final file = File(_path(folderPath));
      if (!file.existsSync()) return none;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return none;
      return FolderStyle(
        color: colors.containsKey(json['color']) ? json['color'] : null,
        emblem: emblems.containsKey(json['emblem']) ? json['emblem'] : null,
      );
    } catch (e) {
      log.warning('Could not read the style of $folderPath', e);
      return none;
    }
  }

  static Future<void> write(String folderPath, FolderStyle style) async {
    final file = File(_path(folderPath));
    if (style.isNone) {
      if (file.existsSync()) await file.delete();
    } else {
      await file.writeAsString(
        jsonEncode({'color': ?style.color, 'emblem': ?style.emblem}),
      );
    }
    changed.value++;
  }

  FolderStyle copyWith({
    String? Function()? color,
    String? Function()? emblem,
  }) => FolderStyle(
    color: color == null ? this.color : color(),
    emblem: emblem == null ? this.emblem : emblem(),
  );

  @override
  bool operator ==(Object other) =>
      other is FolderStyle && other.color == color && other.emblem == emblem;

  @override
  int get hashCode => Object.hash(color, emblem);
}
