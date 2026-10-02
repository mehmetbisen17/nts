///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsRu extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsRu({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ru,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <ru>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	late final TranslationsRu _root = this; // ignore: unused_field

	@override 
	TranslationsRu $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsRu(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$ru common = _Translations$common$ru._(_root);
	@override late final _Translations$home$ru home = _Translations$home$ru._(_root);
	@override late final _Translations$sentry$ru sentry = _Translations$sentry$ru._(_root);
	@override late final _Translations$settings$ru settings = _Translations$settings$ru._(_root);
	@override late final _Translations$logs$ru logs = _Translations$logs$ru._(_root);
	@override late final _Translations$appInfo$ru appInfo = _Translations$appInfo$ru._(_root);
	@override late final _Translations$editor$ru editor = _Translations$editor$ru._(_root);
}

// Path: common
class _Translations$common$ru extends Translations$common$en {
	_Translations$common$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get done => 'Готово';
	@override String get continueBtn => 'Продолжить';
	@override String get cancel => 'Отмена';
}

// Path: home
class _Translations$home$ru extends Translations$home$en {
	_Translations$home$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _Translations$home$titles$ru titles = _Translations$home$titles$ru._(_root);
	@override late final _Translations$home$tooltips$ru tooltips = _Translations$home$tooltips$ru._(_root);
	@override late final _Translations$home$create$ru create = _Translations$home$create$ru._(_root);
	@override String get welcome => 'Приветствуем в nts';
	@override String get invalidFormat => 'Выбранный вами файл не поддерживается. Выберите файл .sbn, .sbn2, .sba или .pdf.';
	@override String get createNewNote => 'Нажмите кнопку «+» чтобы создать новую заметку';
	@override String get backFolder => 'Вернуться к предыдущей папке';
	@override late final _Translations$home$newFolder$ru newFolder = _Translations$home$newFolder$ru._(_root);
	@override late final _Translations$home$renameNote$ru renameNote = _Translations$home$renameNote$ru._(_root);
	@override late final _Translations$home$moveNote$ru moveNote = _Translations$home$moveNote$ru._(_root);
	@override String get deleteNote => 'Удалить заметку';
	@override late final _Translations$home$deleteNoteDialog$ru deleteNoteDialog = _Translations$home$deleteNoteDialog$ru._(_root);
	@override late final _Translations$home$renameFolder$ru renameFolder = _Translations$home$renameFolder$ru._(_root);
	@override late final _Translations$home$deleteFolder$ru deleteFolder = _Translations$home$deleteFolder$ru._(_root);
	@override late final _Translations$home$sort$ru sort = _Translations$home$sort$ru._(_root);
}

// Path: sentry
class _Translations$sentry$ru extends Translations$sentry$en {
	_Translations$sentry$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _Translations$sentry$consent$ru consent = _Translations$sentry$consent$ru._(_root);
}

// Path: settings
class _Translations$settings$ru extends Translations$settings$en {
	_Translations$settings$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _Translations$settings$prefCategories$ru prefCategories = _Translations$settings$prefCategories$ru._(_root);
	@override late final _Translations$settings$prefLabels$ru prefLabels = _Translations$settings$prefLabels$ru._(_root);
	@override late final _Translations$settings$prefDescriptions$ru prefDescriptions = _Translations$settings$prefDescriptions$ru._(_root);
	@override late final _Translations$settings$themeModes$ru themeModes = _Translations$settings$themeModes$ru._(_root);
	@override late final _Translations$settings$layoutSizes$ru layoutSizes = _Translations$settings$layoutSizes$ru._(_root);
	@override late final _Translations$settings$accentColorPicker$ru accentColorPicker = _Translations$settings$accentColorPicker$ru._(_root);
	@override String get systemLanguage => 'Язык системы';
	@override List<String> get axisDirections => [
		'Сверху',
		'Справа',
		'Снизу',
		'Слева',
	];
	@override late final _Translations$settings$reset$ru reset = _Translations$settings$reset$ru._(_root);
	@override String get openDataDir => 'Открыть папку nts';
	@override late final _Translations$settings$customDataDir$ru customDataDir = _Translations$settings$customDataDir$ru._(_root);
	@override String get autosaveDisabled => 'Никогда';
	@override String get shapeRecognitionDisabled => 'Никогда';
}

// Path: logs
class _Translations$logs$ru extends Translations$logs$en {
	_Translations$logs$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get logs => 'Жерналы';
	@override String get viewLogs => 'Просмотр журналов';
	@override String get debuggingInfo => 'Журналы содержат информацию, полезную для отладки и разработки';
	@override String get noLogs => 'Здесь нет журналов!';
	@override String get useTheApp => 'Журналы будут отображаться по мере использования приложения';
}

// Path: appInfo
class _Translations$appInfo$ru extends Translations$appInfo$en {
	_Translations$appInfo$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String licenseNotice({required Object buildYear}) => 'nts (modified from Saber)  Copyright © 2022-${buildYear}  Adil Hanney\nЭта программа поставляется без каких-либо гарантий. Это бесплатное программное обеспечение, и вы можете распространять его при определенных условиях.';
	@override String get debug => 'ОТЛАДКА';
	@override String get licenseButton => 'Просмотрите дополнительную информацию о лицензии';
	@override String get privacyPolicyButton => 'Просмотр политики конфиденциальности';
}

// Path: editor
class _Translations$editor$ru extends Translations$editor$en {
	_Translations$editor$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _Translations$editor$toolbar$ru toolbar = _Translations$editor$toolbar$ru._(_root);
	@override late final _Translations$editor$pens$ru pens = _Translations$editor$pens$ru._(_root);
	@override late final _Translations$editor$penOptions$ru penOptions = _Translations$editor$penOptions$ru._(_root);
	@override late final _Translations$editor$colors$ru colors = _Translations$editor$colors$ru._(_root);
	@override late final _Translations$editor$imageOptions$ru imageOptions = _Translations$editor$imageOptions$ru._(_root);
	@override late final _Translations$editor$selectionBar$ru selectionBar = _Translations$editor$selectionBar$ru._(_root);
	@override late final _Translations$editor$menu$ru menu = _Translations$editor$menu$ru._(_root);
	@override late final _Translations$editor$readOnlyBanner$ru readOnlyBanner = _Translations$editor$readOnlyBanner$ru._(_root);
	@override late final _Translations$editor$versionTooNew$ru versionTooNew = _Translations$editor$versionTooNew$ru._(_root);
	@override late final _Translations$editor$quill$ru quill = _Translations$editor$quill$ru._(_root);
	@override late final _Translations$editor$hud$ru hud = _Translations$editor$hud$ru._(_root);
	@override String get pages => 'Листы';
	@override String get untitled => 'Без названия';
	@override String get needsToSaveBeforeExiting => 'Сохраните Ваши изменения… Вы можете безопасно выйти из редактора, когда это будет сделано';
}

// Path: home.titles
class _Translations$home$titles$ru extends Translations$home$titles$en {
	_Translations$home$titles$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get home => 'Недавние заметки';
	@override String get browse => 'Обзор';
	@override String get whiteboard => 'Чистый лист';
	@override String get settings => 'Настройки';
}

// Path: home.tooltips
class _Translations$home$tooltips$ru extends Translations$home$tooltips$en {
	_Translations$home$tooltips$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get newNote => 'Новая заметка';
	@override String get exportNote => 'Экспортировать заметку';
}

// Path: home.create
class _Translations$home$create$ru extends Translations$home$create$en {
	_Translations$home$create$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get newNote => 'Новая заметка';
	@override String get importNote => 'Импорт заметки';
}

// Path: home.newFolder
class _Translations$home$newFolder$ru extends Translations$home$newFolder$en {
	_Translations$home$newFolder$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get newFolder => 'Новая папка';
	@override String get folderName => 'Имя папки';
	@override String get create => 'Создать';
	@override String get folderNameEmpty => 'Имя папки не может быть пустым';
	@override String get folderNameContainsSlash => 'Имя папки не должно содержать косую черту';
	@override String get folderNameExists => 'Папка уже существует';
}

// Path: home.renameNote
class _Translations$home$renameNote$ru extends Translations$home$renameNote$en {
	_Translations$home$renameNote$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get renameNote => 'Переименовать заметку';
	@override String get noteName => 'Название заметки';
	@override String get rename => 'Переименовать';
	@override String get noteNameEmpty => 'Название заметки не может быть пустым';
	@override String get noteNameExists => 'Заметка с таким названием уже существует';
	@override String get noteNameForbiddenCharacters => 'Название заметки содержит запрёщенные символы';
	@override String get noteNameReserved => 'Название заметки зарезервировано';
}

// Path: home.moveNote
class _Translations$home$moveNote$ru extends Translations$home$moveNote$en {
	_Translations$home$moveNote$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get moveNote => 'Переместить заметку';
	@override String moveNotes({required Object n}) => 'Переместить ${n} заметок';
	@override String moveName({required Object f}) => 'Переместить ${f}';
	@override String get move => 'Перемещение';
	@override String renamedTo({required Object newName}) => 'Заметка будет переименована в ${newName}';
	@override String get multipleRenamedTo => 'Следующие заметки будут переименованы:';
	@override String numberRenamedTo({required Object n}) => '${n} заметок будут переименованы, чтобы избежать конфликтов';
}

// Path: home.deleteNoteDialog
class _Translations$home$deleteNoteDialog$ru extends Translations$home$deleteNoteDialog$en {
	_Translations$home$deleteNoteDialog$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String confirmDelete({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: 'Постоянно удалить выбранную заметку?',
		other: 'Постоянно удалить выбранные заметки?',
	);
	@override String deleteNotes({required Object n}) => 'Удалить ${n} заметок';
	@override String deleteName({required Object f}) => 'Удалить ${f}';
	@override String get delete => 'Удалить';
}

// Path: home.renameFolder
class _Translations$home$renameFolder$ru extends Translations$home$renameFolder$en {
	_Translations$home$renameFolder$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get renameFolder => 'Переименовать папку';
	@override String get folderName => 'Имя папки';
	@override String get rename => 'Переименовать';
	@override String get folderNameEmpty => 'Имя папки не может быть пустым';
	@override String get folderNameContainsSlash => 'Имя папки не может содержать косую черту';
	@override String get folderNameExists => 'Папка с таким названием уже существует';
}

// Path: home.deleteFolder
class _Translations$home$deleteFolder$ru extends Translations$home$deleteFolder$en {
	_Translations$home$deleteFolder$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get deleteFolder => 'Удалить папку';
	@override String deleteName({required Object f}) => 'Удалить ${f}';
	@override String get delete => 'Удалить';
	@override String get alsoDeleteContents => 'Также, удалить все заметки в этой папке';
}

// Path: home.sort
class _Translations$home$sort$ru extends Translations$home$sort$en {
	_Translations$home$sort$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get sortBy => 'Сортировать по';
	@override String get nameAToZ => 'Имя (от А до Я)';
	@override String get nameZToA => 'Имя (по алфавиту от А до Я)';
	@override String get lastModifiedNewToOld => 'Отредактировано (Новое в начале)';
	@override String get lastModifiedOldToNew => 'Отредактировано (По убыванию возраста)';
}

// Path: sentry.consent
class _Translations$sentry$consent$ru extends Translations$sentry$consent$en {
	_Translations$sentry$consent$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Поможете улучшить nts?';
	@override late final _Translations$sentry$consent$description$ru description = _Translations$sentry$consent$description$ru._(_root);
	@override late final _Translations$sentry$consent$answers$ru answers = _Translations$sentry$consent$answers$ru._(_root);
}

// Path: settings.prefCategories
class _Translations$settings$prefCategories$ru extends Translations$settings$prefCategories$en {
	_Translations$settings$prefCategories$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get general => 'Общие';
	@override String get writing => 'Письмо';
	@override String get editor => 'Редактор';
	@override String get performance => 'Производительность';
	@override String get advanced => 'Дополнительно';
}

// Path: settings.prefLabels
class _Translations$settings$prefLabels$ru extends Translations$settings$prefLabels$en {
	_Translations$settings$prefLabels$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get locale => 'Язык приложения';
	@override String get appTheme => 'Тема оформления';
	@override String get platform => 'Тип темы';
	@override String get layoutSize => 'Размер макета';
	@override String get customAccentColor => 'Свой цвет акцента';
	@override String get hyperlegibleFont => 'Гипер разборчивый шрифт';
	@override String get editorToolbarAlignment => 'Панель инструментов редактора';
	@override String get editorToolbarShowInFullscreen => 'Показывать инструменты в полноэкранном режиме';
	@override String get editorAutoInvert => 'Инвертировать заметки в тёмном режиме';
	@override String get preferGreyscale => 'Предпочтение оттенкам серого';
	@override String get maxImageSize => 'Макс. размер изображения';
	@override String get autoClearWhiteboardOnExit => 'Очищать лист при выходе из приложения';
	@override String get disableEraserAfterUse => 'Автоотключение ластика';
	@override String get hideFingerDrawingToggle => 'Скрыть переключатель «Рисование пальцем»';
	@override String get autoDisableFingerDrawingWhenStylusDetected => 'Автоотключение рисования пальцем';
	@override String get editorPromptRename => 'Предлагать переименовывать новые заметки';
	@override String get recentColorsDontSavePresets => 'Не сохранять предустановленные цвета в последних цветах';
	@override String get recentColorsLength => 'Количество последних сохраняемых цветов';
	@override String get printPageIndicators => 'Печатать номера страниц';
	@override String get autosave => 'Автосохранение';
	@override String get shapeRecognitionDelay => 'Задержка распознавания формы';
	@override String get autoStraightenLines => 'Автоматическое выпрямление линий';
	@override String get customDataDir => 'Свой каталог nts';
	@override String get sentry => 'Сообщить об ошибке';
}

// Path: settings.prefDescriptions
class _Translations$settings$prefDescriptions$ru extends Translations$settings$prefDescriptions$en {
	_Translations$settings$prefDescriptions$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get hyperlegibleFont => 'Шрифт Atkinson Hyperlegible повышает разборчивость для читателей с плохим зрением';
	@override String get preferGreyscale => 'Для e-ink экранов';
	@override String get autoClearWhiteboardOnExit => 'Это будет синхронизировано с другими вашими устройствами';
	@override String get disableEraserAfterUse => 'Автоматически переключается на перо после использования ластика';
	@override String get maxImageSize => 'Большие изображения будут сжаты';
	@override late final _Translations$settings$prefDescriptions$hideFingerDrawing$ru hideFingerDrawing = _Translations$settings$prefDescriptions$hideFingerDrawing$ru._(_root);
	@override String get autoDisableFingerDrawingWhenStylusDetected => 'Отключение рисования пальцем при обнаружении пера';
	@override String get editorPromptRename => 'Вы всегда можете переименовать заметки позже';
	@override String get printPageIndicators => 'Показывать номера страниц при экспорте';
	@override String get autosave => 'Автосохранение с задержкой';
	@override String get shapeRecognitionDelay => 'Как часто обновлять предварительный просмотр формы';
	@override String get autoStraightenLines => 'Выпрямляет длинные линии без использования фигурного пера';
	@override late final _Translations$settings$prefDescriptions$sentry$ru sentry = _Translations$settings$prefDescriptions$sentry$ru._(_root);
}

// Path: settings.themeModes
class _Translations$settings$themeModes$ru extends Translations$settings$themeModes$en {
	_Translations$settings$themeModes$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get system => 'Системная';
	@override String get light => 'Светлая';
	@override String get dark => 'Тёмная';
}

// Path: settings.layoutSizes
class _Translations$settings$layoutSizes$ru extends Translations$settings$layoutSizes$en {
	_Translations$settings$layoutSizes$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Авто';
	@override String get phone => 'Телефон';
	@override String get tablet => 'Планшет';
}

// Path: settings.accentColorPicker
class _Translations$settings$accentColorPicker$ru extends Translations$settings$accentColorPicker$en {
	_Translations$settings$accentColorPicker$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get pickAColor => 'Выбери цвет';
}

// Path: settings.reset
class _Translations$settings$reset$ru extends Translations$settings$reset$en {
	_Translations$settings$reset$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Сбросить эту настройку?';
	@override String get button => 'Сбросить';
}

// Path: settings.customDataDir
class _Translations$settings$customDataDir$ru extends Translations$settings$customDataDir$en {
	_Translations$settings$customDataDir$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get cancel => 'Отмена';
	@override String get select => 'Выбрать';
	@override String get mustBeEmpty => 'Выбранный каталог должен быть пустым';
	@override String get unsupported => 'В настоящее время эта функция доступна только разработчикам. Её использование, скорее всего, приведёт к потере данных.';
}

// Path: editor.toolbar
class _Translations$editor$toolbar$ru extends Translations$editor$toolbar$en {
	_Translations$editor$toolbar$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get toggleColors => 'Выбор цвета (Ctrl C)';
	@override String get select => 'Выделение';
	@override String get toggleEraser => 'Ластик (Ctrl E)';
	@override String get photo => 'Фото';
	@override String get text => 'Текст';
	@override String get toggleFingerDrawing => 'Рисование пальцем (Ctrl F)';
	@override String get undo => 'Отменить';
	@override String get redo => 'Вернуть';
	@override String get export => 'Экспорт (Ctrl Shift S)';
	@override String get exportAs => 'Сохранить как:';
	@override String get fullscreen => 'Полноэкранный режим (F11)';
}

// Path: editor.pens
class _Translations$editor$pens$ru extends Translations$editor$pens$en {
	_Translations$editor$pens$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get fountainPen => 'Перьевая ручка';
	@override String get ballpointPen => 'Шариковая ручка';
	@override String get highlighter => 'Маркер';
	@override String get pencil => 'Карандаш';
	@override String get shapePen => 'Вид ручки';
	@override String get laserPointer => 'Лазерная указка';
}

// Path: editor.penOptions
class _Translations$editor$penOptions$ru extends Translations$editor$penOptions$en {
	_Translations$editor$penOptions$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get size => 'Размер';
}

// Path: editor.colors
class _Translations$editor$colors$ru extends Translations$editor$colors$en {
	_Translations$editor$colors$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get colorPicker => 'Выбор цвета';
	@override String customBrightnessHue({required Object b, required Object h}) => 'Свой ${b} ${h}';
	@override String customHue({required Object h}) => 'Свой ${h}';
	@override String get dark => 'тёмный';
	@override String get light => 'светлый';
	@override String get black => 'Чёрный';
	@override String get darkGrey => 'Тёмно-серый';
	@override String get grey => 'Серый';
	@override String get lightGrey => 'Светло-серый';
	@override String get white => 'Белый';
	@override String get red => 'Красный';
	@override String get green => 'Зелёный';
	@override String get cyan => 'Голубой';
	@override String get blue => 'Синий';
	@override String get yellow => 'Жёлтый';
	@override String get purple => 'Фиолетовый';
	@override String get pink => 'Розовый';
	@override String get orange => 'Оранжевый';
	@override String get pastelRed => 'Пастельный красный';
	@override String get pastelOrange => 'Пастельный оранжевый';
	@override String get pastelYellow => 'Пастельный жёлтый';
	@override String get pastelGreen => 'Пастельный зелёный';
	@override String get pastelCyan => 'Пастельный голубой';
	@override String get pastelBlue => 'Пастельный синий';
	@override String get pastelPurple => 'Пастельный фиолетовый';
	@override String get pastelPink => 'Пастельный розовый';
}

// Path: editor.imageOptions
class _Translations$editor$imageOptions$ru extends Translations$editor$imageOptions$en {
	_Translations$editor$imageOptions$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Параметры изображения';
	@override String get invertible => 'Инвертировать';
	@override String get download => 'Сохранить';
	@override String get setAsBackground => 'Сделать фоном';
	@override String get removeAsBackground => 'Удалить фон';
	@override String get delete => 'Удалить';
}

// Path: editor.selectionBar
class _Translations$editor$selectionBar$ru extends Translations$editor$selectionBar$en {
	_Translations$editor$selectionBar$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get delete => 'Удалить';
	@override String get duplicate => 'Дублировать';
}

// Path: editor.menu
class _Translations$editor$menu$ru extends Translations$editor$menu$en {
	_Translations$editor$menu$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String clearPage({required Object page, required Object totalPages}) => 'Очистить лист ${page}/${totalPages}';
	@override String get clearAllPages => 'Очистить все листы';
	@override String get insertPage => 'Вставить страницу ниже';
	@override String get duplicatePage => 'Дубликат страницы';
	@override String get deletePage => 'Удалить страницу';
	@override String get lineHeight => 'Высота строки';
	@override String get lineHeightDescription => 'Также управляет размером текста для напечатанных заметок';
	@override String get lineThickness => 'Толщина линии';
	@override String get lineThicknessDescription => 'Толщина фоновой линии';
	@override String get backgroundImageFit => 'Фоновое изображение';
	@override String get backgroundPattern => 'Фоновый шаблон';
	@override String get import => 'Импорт';
	@override late final _Translations$editor$menu$boxFits$ru boxFits = _Translations$editor$menu$boxFits$ru._(_root);
	@override late final _Translations$editor$menu$bgPatterns$ru bgPatterns = _Translations$editor$menu$bgPatterns$ru._(_root);
}

// Path: editor.readOnlyBanner
class _Translations$editor$readOnlyBanner$ru extends Translations$editor$readOnlyBanner$en {
	_Translations$editor$readOnlyBanner$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Режим «Только чтение»';
	@override String get watchingServer => 'В данный момент вы следите за обновлениями на сервере. В этом режиме редактирование отключено.';
	@override String get corrupted => 'Не удалось загрузить заметку. Возможно, она повреждена или все еще загружается.';
}

// Path: editor.versionTooNew
class _Translations$editor$versionTooNew$ru extends Translations$editor$versionTooNew$en {
	_Translations$editor$versionTooNew$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Эта заметка была отредактирована в более новой версии nts.';
	@override String get subtitle => 'Редактирование этой заметки может привести к потере некоторой информации. Вы хотите проигнорировать это и начать редактирование?';
	@override String get allowEditing => 'Разрешить редактирование';
}

// Path: editor.quill
class _Translations$editor$quill$ru extends Translations$editor$quill$en {
	_Translations$editor$quill$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get typeSomething => 'Напишите что-нибудь здесь…';
}

// Path: editor.hud
class _Translations$editor$hud$ru extends Translations$editor$hud$en {
	_Translations$editor$hud$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get unlockZoom => 'Разблок. увеличение';
	@override String get lockZoom => 'Блок. увеличения';
	@override String get unlockSingleFingerPan => 'Разрешить панораму одним пальцем';
	@override String get lockSingleFingerPan => 'Запретить панораму одним пальцем';
	@override String get unlockAxisAlignedPan => 'Разблокировать панораму по горизонтали или вертикали';
	@override String get lockAxisAlignedPan => 'Блокировать панораму по горизонтали или вертикали';
}

// Path: sentry.consent.description
class _Translations$sentry$consent$description$ru extends Translations$sentry$consent$description$en {
	_Translations$sentry$consent$description$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get question => 'Хотели бы вы автоматически сообщать о непредвиденных ошибках? Это помогает мне быстрее выявлять и устранять неполадки.';
	@override String get scope => 'В отчётах может содержаться информация об ошибке и вашем устройстве. Я приложил все усилия, чтобы отфильтровать личные данные, но некоторые из них могут остаться.';
	@override String get currentlyOff => 'Если вы дадите согласие, то после перезапуска приложения будут включены отчёты об ошибках.';
	@override String get currentlyOn => 'Если вы отзовёте свое согласие, пожалуйста, перезапустите приложение, чтобы отключить отчёты об ошибках.';
	@override TextSpan learnMoreInPrivacyPolicy({required InlineSpanBuilder link}) => TextSpan(children: [
		const TextSpan(text: 'Узнайте больше в разделе '),
		link('privacy policy'),
		const TextSpan(text: '.'),
	]);
}

// Path: sentry.consent.answers
class _Translations$sentry$consent$answers$ru extends Translations$sentry$consent$answers$en {
	_Translations$sentry$consent$answers$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get yes => 'Да';
	@override String get no => 'Нет';
	@override String get later => 'Спросить позже';
}

// Path: settings.prefDescriptions.hideFingerDrawing
class _Translations$settings$prefDescriptions$hideFingerDrawing$ru extends Translations$settings$prefDescriptions$hideFingerDrawing$en {
	_Translations$settings$prefDescriptions$hideFingerDrawing$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get shown => 'Предотвращать случайное переключение';
	@override String get fixedOn => '«Рисование пальцем» зафиксировано как включенное';
	@override String get fixedOff => '«Рисование пальцем» зафиксировано как выключенное';
}

// Path: settings.prefDescriptions.sentry
class _Translations$settings$prefDescriptions$sentry$ru extends Translations$settings$prefDescriptions$sentry$en {
	_Translations$settings$prefDescriptions$sentry$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get active => 'Активно';
	@override String get inactive => 'Неактивно';
	@override String get activeUntilRestart => 'Активно до тех пор, пока вы не перезапустите приложение';
	@override String get inactiveUntilRestart => 'Неактивно до тех пор, пока вы не перезапустите приложение';
}

// Path: editor.menu.boxFits
class _Translations$editor$menu$boxFits$ru extends Translations$editor$menu$boxFits$en {
	_Translations$editor$menu$boxFits$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get fill => 'Растянуть';
	@override String get cover => 'Обрезать';
	@override String get contain => 'Вместить';
}

// Path: editor.menu.bgPatterns
class _Translations$editor$menu$bgPatterns$ru extends Translations$editor$menu$bgPatterns$en {
	_Translations$editor$menu$bgPatterns$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get none => 'Пустой';
	@override String get college => 'Школьная тетрадь';
	@override String get collegeRtl => 'Школьная тетрадь (Поворот)';
	@override String get lined => 'Линии';
	@override String get grid => 'Сетка';
	@override String get dots => 'Точки';
	@override String get staffs => 'Персональный';
	@override String get tablature => 'Табулатура';
	@override String get cornell => 'Корнелл';
}
