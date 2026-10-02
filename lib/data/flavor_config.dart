class FlavorConfig {
  new _();

  static late String _flavor;
  static String get flavor => _flavor;

  static late String _appStore;
  static String get appStore => _appStore;

  static void setup({String flavor = '', String appStore = ''}) {
    _flavor = flavor;
    _appStore = appStore;
  }

  static void setupFromEnvironment() => setup(
    flavor: const String.fromEnvironment('FLAVOR'),
    appStore: const String.fromEnvironment('APP_STORE'),
  );
}
