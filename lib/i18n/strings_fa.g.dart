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
class TranslationsFa extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsFa({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.fa,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <fa>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	late final TranslationsFa _root = this; // ignore: unused_field

	@override 
	TranslationsFa $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsFa(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$fa common = _Translations$common$fa._(_root);
	@override late final _Translations$home$fa home = _Translations$home$fa._(_root);
	@override late final _Translations$sentry$fa sentry = _Translations$sentry$fa._(_root);
	@override late final _Translations$settings$fa settings = _Translations$settings$fa._(_root);
	@override late final _Translations$logs$fa logs = _Translations$logs$fa._(_root);
	@override late final _Translations$appInfo$fa appInfo = _Translations$appInfo$fa._(_root);
	@override late final _Translations$editor$fa editor = _Translations$editor$fa._(_root);
}

// Path: common
class _Translations$common$fa extends Translations$common$en {
	_Translations$common$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get cancel => 'لغو';
	@override String get done => 'انجام شده';
	@override String get continueBtn => 'ادامه هید';
}

// Path: home
class _Translations$home$fa extends Translations$home$en {
	_Translations$home$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override late final _Translations$home$titles$fa titles = _Translations$home$titles$fa._(_root);
	@override late final _Translations$home$tooltips$fa tooltips = _Translations$home$tooltips$fa._(_root);
	@override late final _Translations$home$create$fa create = _Translations$home$create$fa._(_root);
	@override String get welcome => 'خوش آمدید';
	@override String get invalidFormat => 'فایلی که انتخاب کرده اید پشتیبانی نمی شود. لطفاً یک فایل sbn، sbn2، sba یا pdf را انتخاب کنید.';
	@override String get createNewNote => 'برای ساخت یادداشت دکمه + را بزنید';
	@override String get backFolder => 'به پوشه قبلی برگردید';
	@override late final _Translations$home$newFolder$fa newFolder = _Translations$home$newFolder$fa._(_root);
	@override late final _Translations$home$renameNote$fa renameNote = _Translations$home$renameNote$fa._(_root);
	@override late final _Translations$home$moveNote$fa moveNote = _Translations$home$moveNote$fa._(_root);
	@override String get deleteNote => 'حذف یادداشت';
	@override late final _Translations$home$deleteNoteDialog$fa deleteNoteDialog = _Translations$home$deleteNoteDialog$fa._(_root);
	@override late final _Translations$home$renameFolder$fa renameFolder = _Translations$home$renameFolder$fa._(_root);
	@override late final _Translations$home$deleteFolder$fa deleteFolder = _Translations$home$deleteFolder$fa._(_root);
	@override late final _Translations$home$sort$fa sort = _Translations$home$sort$fa._(_root);
}

// Path: sentry
class _Translations$sentry$fa extends Translations$sentry$en {
	_Translations$sentry$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override late final _Translations$sentry$consent$fa consent = _Translations$sentry$consent$fa._(_root);
}

// Path: settings
class _Translations$settings$fa extends Translations$settings$en {
	_Translations$settings$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override late final _Translations$settings$prefCategories$fa prefCategories = _Translations$settings$prefCategories$fa._(_root);
	@override late final _Translations$settings$prefLabels$fa prefLabels = _Translations$settings$prefLabels$fa._(_root);
	@override late final _Translations$settings$prefDescriptions$fa prefDescriptions = _Translations$settings$prefDescriptions$fa._(_root);
	@override late final _Translations$settings$themeModes$fa themeModes = _Translations$settings$themeModes$fa._(_root);
	@override late final _Translations$settings$layoutSizes$fa layoutSizes = _Translations$settings$layoutSizes$fa._(_root);
	@override late final _Translations$settings$accentColorPicker$fa accentColorPicker = _Translations$settings$accentColorPicker$fa._(_root);
	@override String get systemLanguage => 'زبان سیستم';
	@override List<String> get axisDirections => [
		'بالا',
		'راست',
		'پایین',
		'چپ',
	];
	@override late final _Translations$settings$reset$fa reset = _Translations$settings$reset$fa._(_root);
	@override late final _Translations$settings$customDataDir$fa customDataDir = _Translations$settings$customDataDir$fa._(_root);
	@override String get autosaveDisabled => 'هرگز';
	@override String get shapeRecognitionDisabled => 'هرگز';
	@override String get openDataDir => 'پوشه nts را باز کنید';
}

// Path: logs
class _Translations$logs$fa extends Translations$logs$en {
	_Translations$logs$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get useTheApp => 'هنگام استفاده از برنامه ، سیاههها در اینجا ظاهر می شوند';
	@override String get logs => 'سیاههها';
	@override String get viewLogs => 'مشاهده سیاهههای مربوط';
	@override String get debuggingInfo => 'گزارش ها حاوی اطلاعات مفیدی برای اشکال زدایی و توسعه هستند';
	@override String get noLogs => 'اینجا هیچ گزارشی وجود ندارد!';
}

// Path: appInfo
class _Translations$appInfo$fa extends Translations$appInfo$en {
	_Translations$appInfo$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String licenseNotice({required Object buildYear}) => 'nts (modified from Saber)  Copyright © 2022-${buildYear}  Adil Hanney\nاین برنامه کاملاً بدون گارانتی ارائه می شود. این نرم‌افزار رایگان است و شما می‌توانید تحت شرایط خاصی آن را مجدداً توزیع کنید';
	@override String get debug => 'دیباگ';
	@override String get licenseButton => 'برای مشاهده اطلاعات بیشتر مجوز اینجا را ضربه بزنید';
	@override String get privacyPolicyButton => 'برای مشاهده سیاست حفظ حریم خصوصی اینجا را ضربه بزنید';
}

// Path: editor
class _Translations$editor$fa extends Translations$editor$en {
	_Translations$editor$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override late final _Translations$editor$toolbar$fa toolbar = _Translations$editor$toolbar$fa._(_root);
	@override late final _Translations$editor$pens$fa pens = _Translations$editor$pens$fa._(_root);
	@override late final _Translations$editor$penOptions$fa penOptions = _Translations$editor$penOptions$fa._(_root);
	@override late final _Translations$editor$colors$fa colors = _Translations$editor$colors$fa._(_root);
	@override late final _Translations$editor$imageOptions$fa imageOptions = _Translations$editor$imageOptions$fa._(_root);
	@override late final _Translations$editor$selectionBar$fa selectionBar = _Translations$editor$selectionBar$fa._(_root);
	@override late final _Translations$editor$menu$fa menu = _Translations$editor$menu$fa._(_root);
	@override late final _Translations$editor$readOnlyBanner$fa readOnlyBanner = _Translations$editor$readOnlyBanner$fa._(_root);
	@override late final _Translations$editor$versionTooNew$fa versionTooNew = _Translations$editor$versionTooNew$fa._(_root);
	@override late final _Translations$editor$quill$fa quill = _Translations$editor$quill$fa._(_root);
	@override late final _Translations$editor$hud$fa hud = _Translations$editor$hud$fa._(_root);
	@override String get pages => 'صفحات';
	@override String get untitled => 'بدون عنوان';
	@override String get needsToSaveBeforeExiting => 'در حال ذخیره تغییرات شما… می توانید با خیال راحت از ویرایشگر خارج شوید';
}

// Path: home.titles
class _Translations$home$titles$fa extends Translations$home$titles$en {
	_Translations$home$titles$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get home => 'یادداشت های اخیر';
	@override String get browse => 'مرور کردن';
	@override String get whiteboard => 'وایت برد';
	@override String get settings => 'تنظیمات';
}

// Path: home.tooltips
class _Translations$home$tooltips$fa extends Translations$home$tooltips$en {
	_Translations$home$tooltips$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get newNote => 'یادداشت جدید';
	@override String get exportNote => 'صدور یادداشت';
}

// Path: home.create
class _Translations$home$create$fa extends Translations$home$create$en {
	_Translations$home$create$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get newNote => 'یادداشت جدید';
	@override String get importNote => 'یادداشت وارد کنید';
}

// Path: home.newFolder
class _Translations$home$newFolder$fa extends Translations$home$newFolder$en {
	_Translations$home$newFolder$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get newFolder => 'پوشه جدید';
	@override String get folderName => 'نام پوشه';
	@override String get create => 'ايجاد كردن';
	@override String get folderNameEmpty => 'نام پوشه نمی تواند خالی باشد';
	@override String get folderNameContainsSlash => 'نام پوشه نمی تواند دارای اسلش باشد';
	@override String get folderNameExists => 'پوشه از قبل وجود دارد';
}

// Path: home.renameNote
class _Translations$home$renameNote$fa extends Translations$home$renameNote$en {
	_Translations$home$renameNote$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get renameNote => 'تغییر نام یادداشت';
	@override String get noteName => 'نام یادداشت';
	@override String get rename => 'تغییر نام دهید';
	@override String get noteNameEmpty => 'نام یادداشت نمی‌تواند خالی باشد';
	@override String get noteNameExists => 'یادداشتی با این نام از قبل وجود دارد';
	@override String get noteNameForbiddenCharacters => 'نام یادداشت حاوی کاراکترهای ممنوعه است';
	@override String get noteNameReserved => 'نام یادداشت رزرو شده است';
}

// Path: home.moveNote
class _Translations$home$moveNote$fa extends Translations$home$moveNote$en {
	_Translations$home$moveNote$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get moveNote => 'انتقال یادداشت';
	@override String moveNotes({required Object n}) => 'انتقال یادداشت ${n}';
	@override String moveName({required Object f}) => 'انتقال ${f}';
	@override String get move => 'انتقال';
	@override String renamedTo({required Object newName}) => 'یادداشت به ${newName} تغییر نام می یابد';
	@override String get multipleRenamedTo => 'یادداشت های زیر تغییر نام خواهند داد:';
	@override String numberRenamedTo({required Object n}) => '${n} یادداشت برای جلوگیری از تداخل نام تغییر خواهد کرد';
}

// Path: home.deleteNoteDialog
class _Translations$home$deleteNoteDialog$fa extends Translations$home$deleteNoteDialog$en {
	_Translations$home$deleteNoteDialog$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String confirmDelete({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fa'))(n,
		one: 'آیا یادداشت انتخاب شده را به طور دائم حذف کنید؟',
		other: 'آیا یادداشت‌های انتخاب شده را به طور دائم حذف کنید؟',
	);
	@override String deleteNotes({required Object n}) => 'حذف ${n} یادداشت';
	@override String deleteName({required Object f}) => 'حذف ${f}';
	@override String get delete => 'حذف';
}

// Path: home.renameFolder
class _Translations$home$renameFolder$fa extends Translations$home$renameFolder$en {
	_Translations$home$renameFolder$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get renameFolder => 'تغییر نام پوشه';
	@override String get folderName => 'نام پوشه';
	@override String get rename => 'تغییر نام';
	@override String get folderNameEmpty => 'نام پوشه نمی تواند خالی باشد';
	@override String get folderNameContainsSlash => 'نام پوشه نمی تواند دارای اسلش باشد';
	@override String get folderNameExists => 'پوشه ای با این نام از قبل وجود دارد';
}

// Path: home.deleteFolder
class _Translations$home$deleteFolder$fa extends Translations$home$deleteFolder$en {
	_Translations$home$deleteFolder$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get deleteFolder => 'پوشه را حذف کنید';
	@override String deleteName({required Object f}) => '${f} را حذف کنید';
	@override String get delete => 'حذف';
	@override String get alsoDeleteContents => 'همچنین تمام یادداشت های داخل این پوشه را حذف کنید';
}

// Path: home.sort
class _Translations$home$sort$fa extends Translations$home$sort$en {
	_Translations$home$sort$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get sortBy => 'مرتب سازی بر اساس';
	@override String get nameAToZ => 'نام (الف تا ز)';
	@override String get nameZToA => 'نام (الف تا ی)';
	@override String get lastModifiedNewToOld => 'ویرایش شده (جدیدترین اول)';
	@override String get lastModifiedOldToNew => 'ویرایش شده (قدیمی‌ترین اول)';
}

// Path: sentry.consent
class _Translations$sentry$consent$fa extends Translations$sentry$consent$en {
	_Translations$sentry$consent$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override late final _Translations$sentry$consent$description$fa description = _Translations$sentry$consent$description$fa._(_root);
	@override late final _Translations$sentry$consent$answers$fa answers = _Translations$sentry$consent$answers$fa._(_root);
	@override String get title => 'به بهبود nts کمک می کنید؟';
}

// Path: settings.prefCategories
class _Translations$settings$prefCategories$fa extends Translations$settings$prefCategories$en {
	_Translations$settings$prefCategories$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get general => 'عمومی';
	@override String get writing => 'نوشتن';
	@override String get editor => 'ویرایشگر';
	@override String get performance => 'کارایی';
	@override String get advanced => 'پیشرفته';
}

// Path: settings.prefLabels
class _Translations$settings$prefLabels$fa extends Translations$settings$prefLabels$en {
	_Translations$settings$prefLabels$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get locale => 'زبان برنامه';
	@override String get appTheme => 'تم برنامه';
	@override String get platform => 'نوع تم';
	@override String get layoutSize => 'نوع چیدمان';
	@override String get customAccentColor => 'رنگ سفارشی';
	@override String get hyperlegibleFont => 'فونت بیش از حد خوانا';
	@override String get editorToolbarAlignment => 'تراز کردن نوار ابزار ویرایشگر';
	@override String get editorToolbarShowInFullscreen => 'نوار ابزار ویرایشگر را در حالت تمام صفحه نمایش دهید';
	@override String get editorAutoInvert => 'معکوس کردن رنگ یادداشت ها در حالت تاریک';
	@override String get preferGreyscale => 'رنگ های خاکستری را در اولویت قرار دهید';
	@override String get maxImageSize => 'حداکثر اندازه تصویر';
	@override String get autoClearWhiteboardOnExit => 'پس از خروج از برنامه، وایت برد پاک شود';
	@override String get disableEraserAfterUse => 'پاک کن را به صورت خودکار غیرفعال کنید';
	@override String get hideFingerDrawingToggle => 'ضامن طراحی انگشت را پنهان کنید';
	@override String get editorPromptRename => 'از شما می خواهد که نام یادداشت های جدید را تغییر دهید';
	@override String get recentColorsDontSavePresets => 'رنگ های از پیش تعیین شده را در رنگ های اخیر ذخیره نکنید';
	@override String get recentColorsLength => 'چند رنگ اخیر برای ذخیره';
	@override String get printPageIndicators => 'چاپ نشانگرهای صفحه';
	@override String get shapeRecognitionDelay => 'تاخیر در تشخیص شکل';
	@override String get autoDisableFingerDrawingWhenStylusDetected => 'غیرفعال کردن خودکار طراحی با انگشت';
	@override String get sentry => 'گزارش خطا';
	@override String get autosave => 'خودرا';
	@override String get customDataDir => 'دایرکتوری داده های سفارشی';
	@override String get autoStraightenLines => 'صاف کردن خودکار خطوط';
}

// Path: settings.prefDescriptions
class _Translations$settings$prefDescriptions$fa extends Translations$settings$prefDescriptions$en {
	_Translations$settings$prefDescriptions$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get hyperlegibleFont => 'خوانایی را برای خوانندگان کم بینا افزایش می دهد';
	@override String get preferGreyscale => 'برای نمایشگر های e-ink';
	@override String get autoClearWhiteboardOnExit => 'همچنان با دستگاه‌های دیگر شما همگام‌سازی می‌شود';
	@override String get disableEraserAfterUse => 'پس از استفاده از پاک کن به صورت خودکار به خودکار برمی گردد';
	@override String get maxImageSize => 'تصاویر بزرگتر از این فشرده خواهند شد';
	@override late final _Translations$settings$prefDescriptions$hideFingerDrawing$fa hideFingerDrawing = _Translations$settings$prefDescriptions$hideFingerDrawing$fa._(_root);
	@override String get editorPromptRename => 'همیشه می توانید بعداً نام یادداشت ها را تغییر دهید';
	@override String get printPageIndicators => 'نمایش نشانگرهای صفحه در خروجی';
	@override String get shapeRecognitionDelay => 'به روز رسانی پیشنمایش شکل چند وقت یکبار انجام شود';
	@override late final _Translations$settings$prefDescriptions$sentry$fa sentry = _Translations$settings$prefDescriptions$sentry$fa._(_root);
	@override String get autoDisableFingerDrawingWhenStylusDetected => 'هنگامی که یک قلم شناسایی شد، نقاشی با انگشت را خاموش کنید';
	@override String get autosave => 'پس از یک تأخیر کوتاه ، یا هرگز';
	@override String get autoStraightenLines => 'خطوط بلند را بدون استفاده از قلم شکل صاف می کند';
}

// Path: settings.themeModes
class _Translations$settings$themeModes$fa extends Translations$settings$themeModes$en {
	_Translations$settings$themeModes$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get system => 'سیستم';
	@override String get light => 'روشن';
	@override String get dark => 'تاریک';
}

// Path: settings.layoutSizes
class _Translations$settings$layoutSizes$fa extends Translations$settings$layoutSizes$en {
	_Translations$settings$layoutSizes$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get auto => 'خودکار';
	@override String get phone => 'تلفن';
	@override String get tablet => 'تبلت';
}

// Path: settings.accentColorPicker
class _Translations$settings$accentColorPicker$fa extends Translations$settings$accentColorPicker$en {
	_Translations$settings$accentColorPicker$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get pickAColor => 'یک رنگ انتخاب کنید';
}

// Path: settings.reset
class _Translations$settings$reset$fa extends Translations$settings$reset$en {
	_Translations$settings$reset$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'این تنظیمات را بازنشانی می کنید؟';
	@override String get button => 'بازنشانی';
}

// Path: settings.customDataDir
class _Translations$settings$customDataDir$fa extends Translations$settings$customDataDir$en {
	_Translations$settings$customDataDir$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get unsupported => 'این ویژگی در حال حاضر فقط برای توسعه دهندگان است. استفاده از آن احتمالاً منجر به از بین رفتن داده ها خواهد شد.';
	@override String get cancel => 'لغو کنید';
	@override String get select => 'انتخاب کنید';
	@override String get mustBeEmpty => 'دایرکتوری انتخاب شده باید خالی باشد';
}

// Path: editor.toolbar
class _Translations$editor$toolbar$fa extends Translations$editor$toolbar$en {
	_Translations$editor$toolbar$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get toggleColors => 'تغییر رنگ (Ctrl C)';
	@override String get select => 'اتخاب';
	@override String get toggleEraser => 'تغییر پاک کن (Ctrl E)';
	@override String get photo => 'عکس';
	@override String get text => 'متن';
	@override String get toggleFingerDrawing => 'تغییر دادن نقاشی با انگشت (Ctrl F)';
	@override String get undo => 'واگرد';
	@override String get redo => 'برگشت';
	@override String get export => 'صدور (Ctrl Shift S)';
	@override String get exportAs => 'صدور به عنوان:';
	@override String get fullscreen => 'تغییر به تمام صفحه (F11)';
}

// Path: editor.pens
class _Translations$editor$pens$fa extends Translations$editor$pens$en {
	_Translations$editor$pens$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get fountainPen => 'خودنویس';
	@override String get ballpointPen => 'خودکار';
	@override String get highlighter => 'هایلایتر';
	@override String get pencil => 'مداد';
	@override String get shapePen => 'شکل قلم';
	@override String get laserPointer => 'اشاره گر لیزری';
}

// Path: editor.penOptions
class _Translations$editor$penOptions$fa extends Translations$editor$penOptions$en {
	_Translations$editor$penOptions$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get size => 'اندازه';
}

// Path: editor.colors
class _Translations$editor$colors$fa extends Translations$editor$colors$en {
	_Translations$editor$colors$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get colorPicker => 'انتخاب کننده رنگ';
	@override String customBrightnessHue({required Object b, required Object h}) => 'شخصی سازی ${b} ${h}';
	@override String customHue({required Object h}) => 'شخصی سازی ${h}';
	@override String get dark => 'تاریک';
	@override String get light => 'روشن';
	@override String get black => 'مشکی';
	@override String get darkGrey => 'خاکستری تیره';
	@override String get grey => 'خاکستری';
	@override String get lightGrey => 'خاکستری روشن';
	@override String get white => 'سفید';
	@override String get red => 'قرمز';
	@override String get green => 'سبز';
	@override String get cyan => 'فیروزه ای';
	@override String get blue => 'آبی';
	@override String get yellow => 'زرد';
	@override String get purple => 'بنفش';
	@override String get pink => 'صورتی';
	@override String get orange => 'نارنجی';
	@override String get pastelRed => 'قرمز پاستلی';
	@override String get pastelOrange => 'نارنجی پاستلی';
	@override String get pastelYellow => 'زرد پاستلی';
	@override String get pastelGreen => 'سبز پاستلی';
	@override String get pastelCyan => 'فیروزه ای پاستلی';
	@override String get pastelBlue => 'آبی پاستلی';
	@override String get pastelPurple => 'بنفش پاستلی';
	@override String get pastelPink => 'صورتی پاستلی';
}

// Path: editor.imageOptions
class _Translations$editor$imageOptions$fa extends Translations$editor$imageOptions$en {
	_Translations$editor$imageOptions$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'گزینه های تصویر';
	@override String get invertible => 'معکوس پذیر';
	@override String get download => 'دانلود';
	@override String get setAsBackground => 'قرار دادن به عنوان تصویر زمینه';
	@override String get removeAsBackground => 'حذف از پس زمینه';
	@override String get delete => 'حذف';
}

// Path: editor.selectionBar
class _Translations$editor$selectionBar$fa extends Translations$editor$selectionBar$en {
	_Translations$editor$selectionBar$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get delete => 'حذف';
	@override String get duplicate => 'تکراری';
}

// Path: editor.menu
class _Translations$editor$menu$fa extends Translations$editor$menu$en {
	_Translations$editor$menu$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String clearPage({required Object page, required Object totalPages}) => 'صفحه ${page}/${totalPages} را پاک کنید';
	@override String get clearAllPages => 'تمام صفحات را پاک کنید';
	@override String get insertPage => 'درج صفحه در زیر';
	@override String get duplicatePage => 'تکرار صفحه';
	@override String get deletePage => 'حذف صفحه';
	@override String get lineHeight => 'ارتفاع خط';
	@override String get backgroundImageFit => 'مناسب تصویر پس زمینه';
	@override String get backgroundPattern => 'الگوی پس زمینه';
	@override String get import => 'واردکردن';
	@override late final _Translations$editor$menu$boxFits$fa boxFits = _Translations$editor$menu$boxFits$fa._(_root);
	@override late final _Translations$editor$menu$bgPatterns$fa bgPatterns = _Translations$editor$menu$bgPatterns$fa._(_root);
	@override String get lineThickness => 'ضخامت خط';
	@override String get lineThicknessDescription => 'ضخامت خط پس زمینه';
	@override String get lineHeightDescription => 'همچنین اندازه متن را برای یادداشت های تایپ شده کنترل می کند';
}

// Path: editor.readOnlyBanner
class _Translations$editor$readOnlyBanner$fa extends Translations$editor$readOnlyBanner$en {
	_Translations$editor$readOnlyBanner$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'حالت فقط خواندنی';
	@override String get watchingServer => 'شما در حال حاضر به دنبال به روز رسانی در سرور هستید. ویرایش در این حالت غیرفعال است.';
	@override String get corrupted => 'یادداشت بارگیری نشد. ممکن است خراب باشد یا هنوز در حال دانلود باشد.';
}

// Path: editor.versionTooNew
class _Translations$editor$versionTooNew$fa extends Translations$editor$versionTooNew$en {
	_Translations$editor$versionTooNew$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'این یادداشت با استفاده از نسخه جدیدتر برنامه ویرایش شده است';
	@override String get subtitle => 'ویرایش این یادداشت ممکن است منجر به از بین رفتن برخی از اطلاعات شود. آیا می خواهید این را نادیده بگیرید و به هر حال آن را ویرایش کنید؟';
	@override String get allowEditing => 'اجازه ویرایش';
}

// Path: editor.quill
class _Translations$editor$quill$fa extends Translations$editor$quill$en {
	_Translations$editor$quill$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get typeSomething => 'اینجا چیزی تایپ کنید…';
}

// Path: editor.hud
class _Translations$editor$hud$fa extends Translations$editor$hud$en {
	_Translations$editor$hud$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get unlockZoom => 'قفل زوم را باز کنید';
	@override String get lockZoom => 'قفل زوم';
	@override String get unlockSingleFingerPan => 'تحرک تک انگشتی را فعال کنید';
	@override String get lockSingleFingerPan => 'تحرک تک انگشتی را غیرفعال کنید';
	@override String get unlockAxisAlignedPan => 'باز کردن قفل حرکت به حالت افقی یا عمودی';
	@override String get lockAxisAlignedPan => 'پانینگ را به صورت افقی یا عمودی قفل کنید';
}

// Path: sentry.consent.description
class _Translations$sentry$consent$description$fa extends Translations$sentry$consent$description$en {
	_Translations$sentry$consent$description$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override TextSpan learnMoreInPrivacyPolicy({required InlineSpanBuilder link}) => TextSpan(children: [
		const TextSpan(text: 'در لینک '),
		link('خط مشی رازداری'),
		const TextSpan(text: ' بیشتر بیاموزید.'),
	]);
	@override String get question => 'آیا دوست دارید به طور خودکار خطاهای غیر منتظره را گزارش کنید؟ این به من کمک می کند تا مسائل را سریعتر شناسایی و رفع کنم.';
	@override String get scope => 'گزارش ها ممکن است حاوی اطلاعاتی در مورد خطا و دستگاه شما باشد. من تمام تلاش خود را برای فیلتر کردن داده های شخصی کردم اما برخی ممکن است باقی بمانند.';
	@override String get currentlyOff => 'اگر رضایت دهید ، گزارش خطا پس از شروع مجدد برنامه فعال می شود.';
	@override String get currentlyOn => 'اگر رضایت را لغو کردید ، لطفاً برنامه را برای غیرفعال کردن گزارش خطا مجدداً راه اندازی کنید.';
}

// Path: sentry.consent.answers
class _Translations$sentry$consent$answers$fa extends Translations$sentry$consent$answers$en {
	_Translations$sentry$consent$answers$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get yes => 'بله';
	@override String get no => 'هیچ';
	@override String get later => 'بعداً از من بپرس';
}

// Path: settings.prefDescriptions.hideFingerDrawing
class _Translations$settings$prefDescriptions$hideFingerDrawing$fa extends Translations$settings$prefDescriptions$hideFingerDrawing$en {
	_Translations$settings$prefDescriptions$hideFingerDrawing$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get shown => 'از جابجایی تصادفی جلوگیری می کند';
	@override String get fixedOn => 'طراحی با انگشت به صورت فعال ثابت شده است';
	@override String get fixedOff => 'طراحی با انگشت به عنوان غیرفعال ثابت است';
}

// Path: settings.prefDescriptions.sentry
class _Translations$settings$prefDescriptions$sentry$fa extends Translations$settings$prefDescriptions$sentry$en {
	_Translations$settings$prefDescriptions$sentry$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get active => 'فعال';
	@override String get inactive => 'غیر فعال';
	@override String get activeUntilRestart => 'فعال باشید تا زمانی که برنامه را مجدداً راه اندازی کنید';
	@override String get inactiveUntilRestart => 'تا زمانی که برنامه را مجدداً راه اندازی کنید غیرفعال است';
}

// Path: editor.menu.boxFits
class _Translations$editor$menu$boxFits$fa extends Translations$editor$menu$boxFits$en {
	_Translations$editor$menu$boxFits$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get fill => 'کش آمدن';
	@override String get cover => 'پوشش دادن';
	@override String get contain => 'محتوی';
}

// Path: editor.menu.bgPatterns
class _Translations$editor$menu$bgPatterns$fa extends Translations$editor$menu$bgPatterns$en {
	_Translations$editor$menu$bgPatterns$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get none => 'جای خالی';
	@override String get college => 'قوانین کالج';
	@override String get collegeRtl => 'تحت حاکمیت دانشگاهی (معکوس)';
	@override String get lined => 'خط کشی شده';
	@override String get grid => 'توری';
	@override String get dots => 'نقطه ای';
	@override String get staffs => 'کارکنان';
	@override String get tablature => 'جدول بندی';
	@override String get cornell => 'کرنل';
}
