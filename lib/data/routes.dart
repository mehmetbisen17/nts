import 'package:nts/data/editor/page.dart';
import 'package:nts/pages/home/home.dart';
import 'package:path_to_regexp/path_to_regexp.dart';

// workaround to assign strings as enum values
abstract class RoutePaths {
  static const home = '$prefixOfHome/:subpage';
  static const edit = '/edit';
  static const logs = '/logs';

  static const prefixOfHome = '/home';

  static String editFilePath(String filePath) {
    return '$edit?path=${Uri.encodeQueryComponent(filePath)}';
  }

  /// A new note of [type] at [filePath] (or, if null, a new file at
  /// the root).
  static String editNew(String? filePath, NoteType type) => Uri(
    path: edit,
    queryParameters: {'path': ?filePath, 'type': type.id},
  ).toString();

  static String editImportPdf(String filePath, String pdfPath) {
    return '$edit'
        '?path=${Uri.encodeQueryComponent(filePath)}'
        '&pdfPath=${Uri.encodeQueryComponent(pdfPath)}';
  }
}

abstract class HomeRoutes {
  static String browseFilePath(String? filePath) {
    var path = routes[1].path;
    if (filePath != '/' && filePath != '' && filePath != null) {
      path += '?path=${Uri.encodeQueryComponent(filePath)}';
    }
    return path;
  }

  static final PathFunction _homeFunction = pathToFunction(RoutePaths.home);

  static List<HomeRoute> get routes => [
    for (final subpage in HomePage.subpages)
      HomeRoute._(_homeFunction({'subpage': subpage})),
  ];
}

class const HomeRoute._(final String path);
