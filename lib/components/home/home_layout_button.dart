import 'package:stow_codecs/stow_codecs.dart';

/// The old masonry/simple grid setting, kept so [stows.homeLayout] still
/// reads. The home pages now use [FolderViewMode] (gallery or list).
enum HomeLayout {
  masonryGrid,
  simpleGrid;

  static const codec = EnumCodec(values);
}
