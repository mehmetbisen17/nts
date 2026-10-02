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
class TranslationsZhHansCn extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsZhHansCn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zhHansCn,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <zh-Hans-CN>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	late final TranslationsZhHansCn _root = this; // ignore: unused_field

	@override 
	TranslationsZhHansCn $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsZhHansCn(meta: meta ?? this.$meta);

	// Translations
	@override late final Translations$common$zh_Hans_CN common = Translations$common$zh_Hans_CN.internal(_root);
	@override late final Translations$home$zh_Hans_CN home = Translations$home$zh_Hans_CN.internal(_root);
	@override late final Translations$sentry$zh_Hans_CN sentry = Translations$sentry$zh_Hans_CN.internal(_root);
	@override late final Translations$settings$zh_Hans_CN settings = Translations$settings$zh_Hans_CN.internal(_root);
	@override late final Translations$logs$zh_Hans_CN logs = Translations$logs$zh_Hans_CN.internal(_root);
	@override late final Translations$appInfo$zh_Hans_CN appInfo = Translations$appInfo$zh_Hans_CN.internal(_root);
	@override late final Translations$editor$zh_Hans_CN editor = Translations$editor$zh_Hans_CN.internal(_root);
}

// Path: common
class Translations$common$zh_Hans_CN extends Translations$common$en {
	Translations$common$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get done => '完成';
	@override String get continueBtn => '继续';
	@override String get cancel => '取消';
}

// Path: home
class Translations$home$zh_Hans_CN extends Translations$home$en {
	Translations$home$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override late final Translations$home$titles$zh_Hans_CN titles = Translations$home$titles$zh_Hans_CN.internal(_root);
	@override late final Translations$home$tooltips$zh_Hans_CN tooltips = Translations$home$tooltips$zh_Hans_CN.internal(_root);
	@override late final Translations$home$create$zh_Hans_CN create = Translations$home$create$zh_Hans_CN.internal(_root);
	@override String get welcome => '欢迎使用 nts';
	@override String get invalidFormat => '不支持该文件。请选择 .sbn、.sbn2、.sba 或 .pdf 文件。';
	@override String get createNewNote => '点击 + 按钮新建一个笔记';
	@override String get backFolder => '回到上一个文件夹';
	@override late final Translations$home$newFolder$zh_Hans_CN newFolder = Translations$home$newFolder$zh_Hans_CN.internal(_root);
	@override late final Translations$home$renameNote$zh_Hans_CN renameNote = Translations$home$renameNote$zh_Hans_CN.internal(_root);
	@override late final Translations$home$moveNote$zh_Hans_CN moveNote = Translations$home$moveNote$zh_Hans_CN.internal(_root);
	@override String get deleteNote => '删除笔记';
	@override late final Translations$home$deleteNoteDialog$zh_Hans_CN deleteNoteDialog = Translations$home$deleteNoteDialog$zh_Hans_CN.internal(_root);
	@override late final Translations$home$renameFolder$zh_Hans_CN renameFolder = Translations$home$renameFolder$zh_Hans_CN.internal(_root);
	@override late final Translations$home$deleteFolder$zh_Hans_CN deleteFolder = Translations$home$deleteFolder$zh_Hans_CN.internal(_root);
	@override late final Translations$home$sort$zh_Hans_CN sort = Translations$home$sort$zh_Hans_CN.internal(_root);
}

// Path: sentry
class Translations$sentry$zh_Hans_CN extends Translations$sentry$en {
	Translations$sentry$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override late final Translations$sentry$consent$zh_Hans_CN consent = Translations$sentry$consent$zh_Hans_CN.internal(_root);
}

// Path: settings
class Translations$settings$zh_Hans_CN extends Translations$settings$en {
	Translations$settings$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override late final Translations$settings$prefCategories$zh_Hans_CN prefCategories = Translations$settings$prefCategories$zh_Hans_CN.internal(_root);
	@override late final Translations$settings$prefLabels$zh_Hans_CN prefLabels = Translations$settings$prefLabels$zh_Hans_CN.internal(_root);
	@override late final Translations$settings$prefDescriptions$zh_Hans_CN prefDescriptions = Translations$settings$prefDescriptions$zh_Hans_CN.internal(_root);
	@override late final Translations$settings$themeModes$zh_Hans_CN themeModes = Translations$settings$themeModes$zh_Hans_CN.internal(_root);
	@override late final Translations$settings$layoutSizes$zh_Hans_CN layoutSizes = Translations$settings$layoutSizes$zh_Hans_CN.internal(_root);
	@override late final Translations$settings$accentColorPicker$zh_Hans_CN accentColorPicker = Translations$settings$accentColorPicker$zh_Hans_CN.internal(_root);
	@override String get systemLanguage => '系统语言';
	@override List<String> get axisDirections => [
		'上',
		'右',
		'下',
		'左',
	];
	@override late final Translations$settings$reset$zh_Hans_CN reset = Translations$settings$reset$zh_Hans_CN.internal(_root);
	@override String get openDataDir => '打开 nts 文件夹';
	@override late final Translations$settings$customDataDir$zh_Hans_CN customDataDir = Translations$settings$customDataDir$zh_Hans_CN.internal(_root);
	@override String get autosaveDisabled => '禁用';
	@override String get shapeRecognitionDisabled => '禁用';
}

// Path: logs
class Translations$logs$zh_Hans_CN extends Translations$logs$en {
	Translations$logs$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get logs => '日志';
	@override String get viewLogs => '查看日志';
	@override String get debuggingInfo => '日志包含用于调试和开发的信息';
	@override String get noLogs => '暂无日志！';
	@override String get useTheApp => '使用应用时日志将显示在此处';
}

// Path: appInfo
class Translations$appInfo$zh_Hans_CN extends Translations$appInfo$en {
	Translations$appInfo$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String licenseNotice({required Object buildYear}) => 'nts (modified from Saber)  版权所有 © 2022-${buildYear}  Adil Hanney\n本程序不附带任何担保。这是自由软件，您可以在特定条件下重新分发它。';
	@override String get debug => 'DEBUG';
	@override String get licenseButton => '点击此处查看更多许可证信息';
	@override String get privacyPolicyButton => '点击此处查看隐私政策';
}

// Path: editor
class Translations$editor$zh_Hans_CN extends Translations$editor$en {
	Translations$editor$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override late final Translations$editor$toolbar$zh_Hans_CN toolbar = Translations$editor$toolbar$zh_Hans_CN.internal(_root);
	@override late final Translations$editor$pens$zh_Hans_CN pens = Translations$editor$pens$zh_Hans_CN.internal(_root);
	@override late final Translations$editor$penOptions$zh_Hans_CN penOptions = Translations$editor$penOptions$zh_Hans_CN.internal(_root);
	@override late final Translations$editor$colors$zh_Hans_CN colors = Translations$editor$colors$zh_Hans_CN.internal(_root);
	@override late final Translations$editor$imageOptions$zh_Hans_CN imageOptions = Translations$editor$imageOptions$zh_Hans_CN.internal(_root);
	@override late final Translations$editor$selectionBar$zh_Hans_CN selectionBar = Translations$editor$selectionBar$zh_Hans_CN.internal(_root);
	@override late final Translations$editor$menu$zh_Hans_CN menu = Translations$editor$menu$zh_Hans_CN.internal(_root);
	@override late final Translations$editor$readOnlyBanner$zh_Hans_CN readOnlyBanner = Translations$editor$readOnlyBanner$zh_Hans_CN.internal(_root);
	@override late final Translations$editor$versionTooNew$zh_Hans_CN versionTooNew = Translations$editor$versionTooNew$zh_Hans_CN.internal(_root);
	@override late final Translations$editor$quill$zh_Hans_CN quill = Translations$editor$quill$zh_Hans_CN.internal(_root);
	@override late final Translations$editor$hud$zh_Hans_CN hud = Translations$editor$hud$zh_Hans_CN.internal(_root);
	@override String get pages => '页面';
	@override String get untitled => '未命名';
	@override String get needsToSaveBeforeExiting => '正在保存您的更改… 完成后您可以安全地退出编辑器';
}

// Path: home.titles
class Translations$home$titles$zh_Hans_CN extends Translations$home$titles$en {
	Translations$home$titles$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get home => '最近笔记';
	@override String get browse => '浏览';
	@override String get whiteboard => '白板';
	@override String get settings => '设置';
}

// Path: home.tooltips
class Translations$home$tooltips$zh_Hans_CN extends Translations$home$tooltips$en {
	Translations$home$tooltips$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get newNote => '新建笔记';
	@override String get exportNote => '导出笔记';
}

// Path: home.create
class Translations$home$create$zh_Hans_CN extends Translations$home$create$en {
	Translations$home$create$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get newNote => '新建笔记';
	@override String get importNote => '导入笔记';
}

// Path: home.newFolder
class Translations$home$newFolder$zh_Hans_CN extends Translations$home$newFolder$en {
	Translations$home$newFolder$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get newFolder => '新建文件夹';
	@override String get folderName => '文件夹名称';
	@override String get create => '创建';
	@override String get folderNameEmpty => '文件夹名称不能为空';
	@override String get folderNameContainsSlash => '文件夹名称不能包含斜杠';
	@override String get folderNameExists => '文件夹已存在';
}

// Path: home.renameNote
class Translations$home$renameNote$zh_Hans_CN extends Translations$home$renameNote$en {
	Translations$home$renameNote$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get renameNote => '重命名笔记';
	@override String get noteName => '笔记名称';
	@override String get rename => '重命名';
	@override String get noteNameEmpty => '笔记名称不能为空';
	@override String get noteNameExists => '此名称的笔记已经存在';
	@override String get noteNameForbiddenCharacters => '笔记名称包含禁止使用的字符';
	@override String get noteNameReserved => '保留了笔记名';
}

// Path: home.moveNote
class Translations$home$moveNote$zh_Hans_CN extends Translations$home$moveNote$en {
	Translations$home$moveNote$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get moveNote => '移动笔记';
	@override String moveNotes({required Object n}) => '移动 ${n} 个笔记';
	@override String moveName({required Object f}) => '移动 ${f}';
	@override String get move => '移动';
	@override String renamedTo({required Object newName}) => '笔记将重命名为 ${newName}';
	@override String get multipleRenamedTo => '以下笔记将被重命名：';
	@override String numberRenamedTo({required Object n}) => '${n} 个笔记将被重命名以避免冲突';
}

// Path: home.deleteNoteDialog
class Translations$home$deleteNoteDialog$zh_Hans_CN extends Translations$home$deleteNoteDialog$en {
	Translations$home$deleteNoteDialog$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String deleteNotes({required Object n}) => '删除 ${n} 个笔记';
	@override String deleteName({required Object f}) => '删除 ${f}';
	@override String confirmDelete({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(n,
		one: '是否永久删除所选笔记？',
		other: '是否永久删除所选笔记？',
	);
	@override String get delete => '删除';
}

// Path: home.renameFolder
class Translations$home$renameFolder$zh_Hans_CN extends Translations$home$renameFolder$en {
	Translations$home$renameFolder$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get renameFolder => '重命名文件夹';
	@override String get folderName => '文件夹名称';
	@override String get rename => '重命名';
	@override String get folderNameEmpty => '文件夹不能为空';
	@override String get folderNameContainsSlash => '文件夹名称不能包含斜线';
	@override String get folderNameExists => '已存在该名称的文件夹';
}

// Path: home.deleteFolder
class Translations$home$deleteFolder$zh_Hans_CN extends Translations$home$deleteFolder$en {
	Translations$home$deleteFolder$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get deleteFolder => '删除文件夹';
	@override String deleteName({required Object f}) => '删除 ${f}';
	@override String get delete => '删除';
	@override String get alsoDeleteContents => '同时删除此文件夹中的所有笔记';
}

// Path: home.sort
class Translations$home$sort$zh_Hans_CN extends Translations$home$sort$en {
	Translations$home$sort$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get sortBy => '按…排序';
	@override String get nameAToZ => '姓名（A-Z）';
	@override String get nameZToA => '姓名（从 A 到 Z）';
	@override String get lastModifiedNewToOld => '编辑（最新优先）';
	@override String get lastModifiedOldToNew => '编辑（按最旧的排序）';
}

// Path: sentry.consent
class Translations$sentry$consent$zh_Hans_CN extends Translations$sentry$consent$en {
	Translations$sentry$consent$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get title => '帮助改进 nts？';
	@override late final Translations$sentry$consent$description$zh_Hans_CN description = Translations$sentry$consent$description$zh_Hans_CN.internal(_root);
	@override late final Translations$sentry$consent$answers$zh_Hans_CN answers = Translations$sentry$consent$answers$zh_Hans_CN.internal(_root);
}

// Path: settings.prefCategories
class Translations$settings$prefCategories$zh_Hans_CN extends Translations$settings$prefCategories$en {
	Translations$settings$prefCategories$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get general => '通用';
	@override String get writing => '书写';
	@override String get editor => '编辑器';
	@override String get performance => '性能';
	@override String get advanced => '高级';
}

// Path: settings.prefLabels
class Translations$settings$prefLabels$zh_Hans_CN extends Translations$settings$prefLabels$en {
	Translations$settings$prefLabels$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get locale => '应用语言';
	@override String get appTheme => '应用主题';
	@override String get platform => '主题类型';
	@override String get layoutSize => '布局大小';
	@override String get customAccentColor => '自定义主题色';
	@override String get hyperlegibleFont => '易读字体';
	@override String get editorToolbarAlignment => '编辑工具栏对齐方式';
	@override String get editorToolbarShowInFullscreen => '在全屏模式中显示编辑菜单栏';
	@override String get editorAutoInvert => '在深色模式下使用反色笔记背景';
	@override String get preferGreyscale => '使用灰度颜色';
	@override String get maxImageSize => '最大图片大小';
	@override String get autoClearWhiteboardOnExit => '离开应用后清除白板';
	@override String get disableEraserAfterUse => '自动禁用橡皮擦';
	@override String get hideFingerDrawingToggle => '隐藏 切换手指绘图';
	@override String get autoDisableFingerDrawingWhenStylusDetected => '自动禁用手指绘图';
	@override String get editorPromptRename => '提示您重命名新笔记';
	@override String get recentColorsDontSavePresets => '不在最近使用的颜色中保存预设颜色';
	@override String get recentColorsLength => '要存储多少种最近的颜色';
	@override String get printPageIndicators => '打印页码';
	@override String get autosave => '自动保存';
	@override String get shapeRecognitionDelay => '形状识别延迟';
	@override String get autoStraightenLines => '自动拉直线';
	@override String get customDataDir => '自定义 nts 文件夹';
	@override String get sentry => '错误报告';
}

// Path: settings.prefDescriptions
class Translations$settings$prefDescriptions$zh_Hans_CN extends Translations$settings$prefDescriptions$en {
	Translations$settings$prefDescriptions$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get hyperlegibleFont => 'Atkinson Hyperlegible 字体为低视力读者提高易读性';
	@override String get preferGreyscale => '用于电子墨水显示器';
	@override String get autoClearWhiteboardOnExit => '这将会同步到您的其他设备';
	@override String get disableEraserAfterUse => '使用橡皮擦后自动切换回笔';
	@override String get maxImageSize => '更大的图片将会被压缩';
	@override late final Translations$settings$prefDescriptions$hideFingerDrawing$zh_Hans_CN hideFingerDrawing = Translations$settings$prefDescriptions$hideFingerDrawing$zh_Hans_CN.internal(_root);
	@override String get autoDisableFingerDrawingWhenStylusDetected => '当检测到手写笔时关闭手指绘图';
	@override String get editorPromptRename => '您可以总是稍后重命名笔记';
	@override String get printPageIndicators => '在导出中显示页码';
	@override String get autosave => '短暂延迟后自动保存，或永不保存';
	@override String get shapeRecognitionDelay => '形状预览更新频率';
	@override String get autoStraightenLines => '拉直长线，无需使用形状笔';
	@override late final Translations$settings$prefDescriptions$sentry$zh_Hans_CN sentry = Translations$settings$prefDescriptions$sentry$zh_Hans_CN.internal(_root);
}

// Path: settings.themeModes
class Translations$settings$themeModes$zh_Hans_CN extends Translations$settings$themeModes$en {
	Translations$settings$themeModes$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get system => '系统';
	@override String get light => '浅色';
	@override String get dark => '深色';
}

// Path: settings.layoutSizes
class Translations$settings$layoutSizes$zh_Hans_CN extends Translations$settings$layoutSizes$en {
	Translations$settings$layoutSizes$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get auto => '自动';
	@override String get phone => '手机';
	@override String get tablet => '平板';
}

// Path: settings.accentColorPicker
class Translations$settings$accentColorPicker$zh_Hans_CN extends Translations$settings$accentColorPicker$en {
	Translations$settings$accentColorPicker$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get pickAColor => '选取颜色';
}

// Path: settings.reset
class Translations$settings$reset$zh_Hans_CN extends Translations$settings$reset$en {
	Translations$settings$reset$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get title => '重置此设置？';
	@override String get button => '重置';
}

// Path: settings.customDataDir
class Translations$settings$customDataDir$zh_Hans_CN extends Translations$settings$customDataDir$en {
	Translations$settings$customDataDir$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get cancel => '取消';
	@override String get select => '选择';
	@override String get mustBeEmpty => '所选文件夹必须为空';
	@override String get unsupported => '此功能目前仅限开发者使用，可能导致数据丢失。';
}

// Path: editor.toolbar
class Translations$editor$toolbar$zh_Hans_CN extends Translations$editor$toolbar$en {
	Translations$editor$toolbar$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get toggleColors => '切换颜色 (Ctrl C)';
	@override String get select => '选择';
	@override String get toggleEraser => '切换橡皮擦 (Ctrl E)';
	@override String get photo => '照片';
	@override String get text => '文本';
	@override String get toggleFingerDrawing => '切换手指绘图 (Ctrl F)';
	@override String get undo => '撤销';
	@override String get redo => '重做';
	@override String get export => '导出 (Ctrl Shift S)';
	@override String get exportAs => '导出为：';
	@override String get fullscreen => '切换全屏 (F11)';
}

// Path: editor.pens
class Translations$editor$pens$zh_Hans_CN extends Translations$editor$pens$en {
	Translations$editor$pens$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get fountainPen => '钢笔';
	@override String get ballpointPen => '圆珠笔';
	@override String get highlighter => '荧光笔';
	@override String get pencil => '铅笔';
	@override String get shapePen => '形状笔';
	@override String get laserPointer => '激光笔';
}

// Path: editor.penOptions
class Translations$editor$penOptions$zh_Hans_CN extends Translations$editor$penOptions$en {
	Translations$editor$penOptions$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get size => '粗细';
}

// Path: editor.colors
class Translations$editor$colors$zh_Hans_CN extends Translations$editor$colors$en {
	Translations$editor$colors$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get colorPicker => '选色器';
	@override String customBrightnessHue({required Object b, required Object h}) => '自定义 ${b} ${h}';
	@override String customHue({required Object h}) => '自定义 ${h}';
	@override String get dark => '暗色';
	@override String get light => '亮色';
	@override String get black => '黑色';
	@override String get darkGrey => '深灰色';
	@override String get grey => '灰色';
	@override String get lightGrey => '浅灰色';
	@override String get white => '白色';
	@override String get red => '红色';
	@override String get green => '绿色';
	@override String get cyan => '青色';
	@override String get blue => '蓝色';
	@override String get yellow => '黄色';
	@override String get purple => '紫色';
	@override String get pink => '粉色';
	@override String get orange => '橙色';
	@override String get pastelRed => '浅红色';
	@override String get pastelOrange => '浅橙色';
	@override String get pastelYellow => '浅黄色';
	@override String get pastelGreen => '浅绿色';
	@override String get pastelCyan => '浅青色';
	@override String get pastelBlue => '浅蓝色';
	@override String get pastelPurple => '浅紫色';
	@override String get pastelPink => '浅粉色';
}

// Path: editor.imageOptions
class Translations$editor$imageOptions$zh_Hans_CN extends Translations$editor$imageOptions$en {
	Translations$editor$imageOptions$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get title => '图片选项';
	@override String get invertible => '反转颜色';
	@override String get download => '下载';
	@override String get setAsBackground => '设为背景';
	@override String get removeAsBackground => '作为背景移除';
	@override String get delete => '删除';
}

// Path: editor.selectionBar
class Translations$editor$selectionBar$zh_Hans_CN extends Translations$editor$selectionBar$en {
	Translations$editor$selectionBar$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get delete => '删除';
	@override String get duplicate => '复制';
}

// Path: editor.menu
class Translations$editor$menu$zh_Hans_CN extends Translations$editor$menu$en {
	Translations$editor$menu$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String clearPage({required Object page, required Object totalPages}) => '清除页面 ${page}/${totalPages}';
	@override String get clearAllPages => '清除全部页面';
	@override String get insertPage => '在下方插入页面';
	@override String get duplicatePage => '复制页面';
	@override String get deletePage => '删除页面';
	@override String get lineHeight => '行高';
	@override String get lineHeightDescription => '同时控制已输入的笔记的文本大小';
	@override String get lineThickness => '线条粗细';
	@override String get lineThicknessDescription => '背景线条粗细';
	@override String get backgroundImageFit => '背景图像拟合';
	@override String get backgroundPattern => '背景图案';
	@override String get import => '导入';
	@override late final Translations$editor$menu$boxFits$zh_Hans_CN boxFits = Translations$editor$menu$boxFits$zh_Hans_CN.internal(_root);
	@override late final Translations$editor$menu$bgPatterns$zh_Hans_CN bgPatterns = Translations$editor$menu$bgPatterns$zh_Hans_CN.internal(_root);
}

// Path: editor.readOnlyBanner
class Translations$editor$readOnlyBanner$zh_Hans_CN extends Translations$editor$readOnlyBanner$en {
	Translations$editor$readOnlyBanner$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get title => '只读模式';
	@override String get watchingServer => '当前正在监视服务器的更新，此模式下编辑功能已禁用。';
	@override String get corrupted => '无法加载笔记。它可能已损坏或仍在下载中。';
}

// Path: editor.versionTooNew
class Translations$editor$versionTooNew$zh_Hans_CN extends Translations$editor$versionTooNew$en {
	Translations$editor$versionTooNew$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get title => '此笔记使用新版 nts 编辑而成';
	@override String get subtitle => '编辑此笔记可能会导致某些信息丢失。您想忽略并编辑吗？';
	@override String get allowEditing => '允许编辑';
}

// Path: editor.quill
class Translations$editor$quill$zh_Hans_CN extends Translations$editor$quill$en {
	Translations$editor$quill$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get typeSomething => '在这里输入…';
}

// Path: editor.hud
class Translations$editor$hud$zh_Hans_CN extends Translations$editor$hud$en {
	Translations$editor$hud$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get unlockZoom => '解锁缩放';
	@override String get lockZoom => '锁定缩放';
	@override String get unlockSingleFingerPan => '启用单指平移';
	@override String get lockSingleFingerPan => '禁用单指平移';
	@override String get unlockAxisAlignedPan => '解锁水平或垂直平移';
	@override String get lockAxisAlignedPan => '锁定水平或垂直平移';
}

// Path: sentry.consent.description
class Translations$sentry$consent$description$zh_Hans_CN extends Translations$sentry$consent$description$en {
	Translations$sentry$consent$description$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get question => '您是否希望自动报告意外错误？这有助于我更快地发现和修复问题。';
	@override String get scope => '报告可能包含有关错误和设备的信息。我已尽力过滤个人数据，但仍可能残留部分信息。';
	@override String get currentlyOff => '若同意启用，重启应用后错误报告功能将激活。';
	@override String get currentlyOn => '若撤销同意，请重启应用以禁用错误报告功能。';
	@override TextSpan learnMoreInPrivacyPolicy({required InlineSpanBuilder link}) => TextSpan(children: [
		const TextSpan(text: '详见'),
		link('隐私政策'),
		const TextSpan(text: '。'),
	]);
}

// Path: sentry.consent.answers
class Translations$sentry$consent$answers$zh_Hans_CN extends Translations$sentry$consent$answers$en {
	Translations$sentry$consent$answers$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get yes => '同意';
	@override String get no => '拒绝';
	@override String get later => '稍后询问';
}

// Path: settings.prefDescriptions.hideFingerDrawing
class Translations$settings$prefDescriptions$hideFingerDrawing$zh_Hans_CN extends Translations$settings$prefDescriptions$hideFingerDrawing$en {
	Translations$settings$prefDescriptions$hideFingerDrawing$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get shown => '防止意外切换';
	@override String get fixedOn => '手指绘图固定为启用状态';
	@override String get fixedOff => '手指绘图固定为禁用状态';
}

// Path: settings.prefDescriptions.sentry
class Translations$settings$prefDescriptions$sentry$zh_Hans_CN extends Translations$settings$prefDescriptions$sentry$en {
	Translations$settings$prefDescriptions$sentry$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get active => '已启用';
	@override String get inactive => '已禁用';
	@override String get activeUntilRestart => '重启前保持启用';
	@override String get inactiveUntilRestart => '重启前保持禁用';
}

// Path: editor.menu.boxFits
class Translations$editor$menu$boxFits$zh_Hans_CN extends Translations$editor$menu$boxFits$en {
	Translations$editor$menu$boxFits$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get fill => '拉伸';
	@override String get cover => '覆盖';
	@override String get contain => '包含';
}

// Path: editor.menu.bgPatterns
class Translations$editor$menu$bgPatterns$zh_Hans_CN extends Translations$editor$menu$bgPatterns$en {
	Translations$editor$menu$bgPatterns$zh_Hans_CN.internal(TranslationsZhHansCn root) : this._root = root, super.internal(root);

	final TranslationsZhHansCn _root; // ignore: unused_field

	// Translations
	@override String get none => '空白';
	@override String get college => 'College-ruled';
	@override String get collegeRtl => 'College-ruled（反转）';
	@override String get lined => '横线';
	@override String get grid => '网格';
	@override String get dots => '点';
	@override String get staffs => '五线谱';
	@override String get tablature => '绘画';
	@override String get cornell => '康奈尔';
}
