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
class TranslationsTr extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsTr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.tr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <tr>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	late final TranslationsTr _root = this; // ignore: unused_field

	@override 
	TranslationsTr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsTr(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$tr common = _Translations$common$tr._(_root);
	@override late final _Translations$home$tr home = _Translations$home$tr._(_root);
	@override late final _Translations$sentry$tr sentry = _Translations$sentry$tr._(_root);
	@override late final _Translations$settings$tr settings = _Translations$settings$tr._(_root);
	@override late final _Translations$logs$tr logs = _Translations$logs$tr._(_root);
	@override late final _Translations$appInfo$tr appInfo = _Translations$appInfo$tr._(_root);
	@override late final _Translations$editor$tr editor = _Translations$editor$tr._(_root);
}

// Path: common
class _Translations$common$tr extends Translations$common$en {
	_Translations$common$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get done => 'Tamamlandı';
	@override String get continueBtn => 'Devam';
	@override String get cancel => 'İptal';
}

// Path: home
class _Translations$home$tr extends Translations$home$en {
	_Translations$home$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override late final _Translations$home$titles$tr titles = _Translations$home$titles$tr._(_root);
	@override late final _Translations$home$tooltips$tr tooltips = _Translations$home$tooltips$tr._(_root);
	@override late final _Translations$home$create$tr create = _Translations$home$create$tr._(_root);
	@override String get welcome => 'nts\'ye hoş geldiniz';
	@override String get invalidFormat => 'Seçtiğiniz dosya desteklenmiyor. Lütfen bir .sbn, .sbn2, .sba veya .pdf dosyası seçin.';
	@override String get createNewNote => 'Yeni bir not oluşturmak için + butonuna tıklayınız';
	@override String get backFolder => 'Önceki klasöre dön';
	@override late final _Translations$home$newFolder$tr newFolder = _Translations$home$newFolder$tr._(_root);
	@override late final _Translations$home$renameNote$tr renameNote = _Translations$home$renameNote$tr._(_root);
	@override late final _Translations$home$moveNote$tr moveNote = _Translations$home$moveNote$tr._(_root);
	@override String get deleteNote => 'Notu sil';
	@override late final _Translations$home$deleteNoteDialog$tr deleteNoteDialog = _Translations$home$deleteNoteDialog$tr._(_root);
	@override late final _Translations$home$renameFolder$tr renameFolder = _Translations$home$renameFolder$tr._(_root);
	@override late final _Translations$home$deleteFolder$tr deleteFolder = _Translations$home$deleteFolder$tr._(_root);
	@override late final _Translations$home$sort$tr sort = _Translations$home$sort$tr._(_root);
}

// Path: sentry
class _Translations$sentry$tr extends Translations$sentry$en {
	_Translations$sentry$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override late final _Translations$sentry$consent$tr consent = _Translations$sentry$consent$tr._(_root);
}

// Path: settings
class _Translations$settings$tr extends Translations$settings$en {
	_Translations$settings$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override late final _Translations$settings$prefCategories$tr prefCategories = _Translations$settings$prefCategories$tr._(_root);
	@override late final _Translations$settings$prefLabels$tr prefLabels = _Translations$settings$prefLabels$tr._(_root);
	@override late final _Translations$settings$prefDescriptions$tr prefDescriptions = _Translations$settings$prefDescriptions$tr._(_root);
	@override late final _Translations$settings$themeModes$tr themeModes = _Translations$settings$themeModes$tr._(_root);
	@override late final _Translations$settings$layoutSizes$tr layoutSizes = _Translations$settings$layoutSizes$tr._(_root);
	@override late final _Translations$settings$accentColorPicker$tr accentColorPicker = _Translations$settings$accentColorPicker$tr._(_root);
	@override String get systemLanguage => 'Sistem dili';
	@override List<String> get axisDirections => [
		'Üst',
		'Sağ',
		'Aşağı',
		'Sol',
	];
	@override late final _Translations$settings$reset$tr reset = _Translations$settings$reset$tr._(_root);
	@override String get openDataDir => 'nts klasörünü aç';
	@override late final _Translations$settings$customDataDir$tr customDataDir = _Translations$settings$customDataDir$tr._(_root);
	@override String get autosaveDisabled => 'Asla';
	@override String get shapeRecognitionDisabled => 'Asla';
}

// Path: logs
class _Translations$logs$tr extends Translations$logs$en {
	_Translations$logs$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get useTheApp => 'Uygulamayı kullanırken günlükler burada görünecektir';
	@override String get logs => 'Günlükler';
	@override String get viewLogs => 'Günlükleri görüntüle';
	@override String get debuggingInfo => 'Günlükler hata ayıklama ve geliştirme için yararlı bilgiler içerir';
	@override String get noLogs => 'Burada kayıt yok!';
}

// Path: appInfo
class _Translations$appInfo$tr extends Translations$appInfo$en {
	_Translations$appInfo$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String licenseNotice({required Object buildYear}) => 'nts (modified from Saber)  Copyright © 2022-${buildYear}  Adil Hanney\nBu program hiçbir şeyi garanti etmez ve güvence vermez.\nBu program özgür (free) bir yazılımdır ve belli koşullar sağlandığında yeniden dağıtıma müsaittir.';
	@override String get debug => 'DEBUG';
	@override String get licenseButton => 'Lisans bilgisinin detaylarını görmek için buraya tıkla';
	@override String get privacyPolicyButton => 'Gizlilik Politikasını görmek için buraya tıkla';
}

// Path: editor
class _Translations$editor$tr extends Translations$editor$en {
	_Translations$editor$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override late final _Translations$editor$toolbar$tr toolbar = _Translations$editor$toolbar$tr._(_root);
	@override late final _Translations$editor$pens$tr pens = _Translations$editor$pens$tr._(_root);
	@override late final _Translations$editor$penOptions$tr penOptions = _Translations$editor$penOptions$tr._(_root);
	@override late final _Translations$editor$colors$tr colors = _Translations$editor$colors$tr._(_root);
	@override late final _Translations$editor$imageOptions$tr imageOptions = _Translations$editor$imageOptions$tr._(_root);
	@override late final _Translations$editor$selectionBar$tr selectionBar = _Translations$editor$selectionBar$tr._(_root);
	@override late final _Translations$editor$menu$tr menu = _Translations$editor$menu$tr._(_root);
	@override late final _Translations$editor$readOnlyBanner$tr readOnlyBanner = _Translations$editor$readOnlyBanner$tr._(_root);
	@override late final _Translations$editor$versionTooNew$tr versionTooNew = _Translations$editor$versionTooNew$tr._(_root);
	@override late final _Translations$editor$quill$tr quill = _Translations$editor$quill$tr._(_root);
	@override late final _Translations$editor$hud$tr hud = _Translations$editor$hud$tr._(_root);
	@override String get pages => 'Sayfalar';
	@override String get untitled => 'İsimsiz';
	@override String get needsToSaveBeforeExiting => 'Değişiklikler kaydediliyor… kayıt tamamlandığında editörden güvenli biçimde çıkabilirsiniz.';
}

// Path: home.titles
class _Translations$home$titles$tr extends Translations$home$titles$en {
	_Translations$home$titles$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get home => 'Son notlar';
	@override String get browse => 'Göz at';
	@override String get whiteboard => 'Beyaz tahta';
	@override String get settings => 'Ayarlar';
}

// Path: home.tooltips
class _Translations$home$tooltips$tr extends Translations$home$tooltips$en {
	_Translations$home$tooltips$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get newNote => 'Yeni not';
	@override String get exportNote => 'Notu dışa aktar';
}

// Path: home.create
class _Translations$home$create$tr extends Translations$home$create$en {
	_Translations$home$create$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get newNote => 'Yeni not';
	@override String get importNote => 'Notu içeri aktar';
}

// Path: home.newFolder
class _Translations$home$newFolder$tr extends Translations$home$newFolder$en {
	_Translations$home$newFolder$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get newFolder => 'Yeni klasör';
	@override String get folderName => 'Klasör adı';
	@override String get create => 'Oluştur';
	@override String get folderNameEmpty => 'Klasör adı boş bırakılamaz';
	@override String get folderNameContainsSlash => 'Klasör adı eğik çizgi işareti içeremez';
	@override String get folderNameExists => 'Bu isimde bir klasör zaten var';
}

// Path: home.renameNote
class _Translations$home$renameNote$tr extends Translations$home$renameNote$en {
	_Translations$home$renameNote$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get renameNote => 'Notu yeniden adlandır';
	@override String get noteName => 'Not adı';
	@override String get rename => 'Yeniden adlandır';
	@override String get noteNameEmpty => 'Not adı boş bırakılamaz';
	@override String get noteNameExists => 'Bu isimde bir not zaten var';
	@override String get noteNameForbiddenCharacters => 'Not adı yasak karakterler içeriyor';
	@override String get noteNameReserved => 'Not adı saklıdır';
}

// Path: home.moveNote
class _Translations$home$moveNote$tr extends Translations$home$moveNote$en {
	_Translations$home$moveNote$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get moveNote => 'Notu taşı';
	@override String moveNotes({required Object n}) => '${n} tane notu taşı';
	@override String moveName({required Object f}) => '${f} dosyasını taşı';
	@override String get move => 'Taşı';
	@override String renamedTo({required Object newName}) => 'Not ${newName} olarak yeniden adlandırılacak';
	@override String get multipleRenamedTo => 'Bu notlar yeniden adlandırılacak:';
	@override String numberRenamedTo({required Object n}) => '${n} tane not çakışma olmaması için yeniden adlandırılacak';
}

// Path: home.deleteNoteDialog
class _Translations$home$deleteNoteDialog$tr extends Translations$home$deleteNoteDialog$en {
	_Translations$home$deleteNoteDialog$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String confirmDelete({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		one: 'Seçilen notu kalıcı olarak sil?',
		other: 'Seçilen notları kalıcı olarak silin?',
	);
	@override String deleteNotes({required Object n}) => '${n} notu\'ları sil';
	@override String deleteName({required Object f}) => '${f}\'yi sil';
	@override String get delete => 'Sil';
}

// Path: home.renameFolder
class _Translations$home$renameFolder$tr extends Translations$home$renameFolder$en {
	_Translations$home$renameFolder$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get renameFolder => 'Klasörü adlandır';
	@override String get folderName => 'Klasör ismi';
	@override String get rename => 'Yeniden adlandır';
	@override String get folderNameEmpty => 'Klasör ismi boş bırakılamaz';
	@override String get folderNameContainsSlash => 'Klasör isminde slash kullanılamaz';
	@override String get folderNameExists => 'Bu isme sahip bir klasör zaten var';
}

// Path: home.deleteFolder
class _Translations$home$deleteFolder$tr extends Translations$home$deleteFolder$en {
	_Translations$home$deleteFolder$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get deleteFolder => 'Klasörü sil';
	@override String deleteName({required Object f}) => '${f} silinecek';
	@override String get delete => 'Sil';
	@override String get alsoDeleteContents => 'Bu klasördeki tüm notları da sil';
}

// Path: home.sort
class _Translations$home$sort$tr extends Translations$home$sort$en {
	_Translations$home$sort$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get sortBy => 'Sırala';
	@override String get nameAToZ => 'Adı (A-Z)';
	@override String get nameZToA => 'Adı (A\'dan Z\'ye)';
	@override String get lastModifiedNewToOld => 'Düzenlendi (En yeni ilk sırada)';
	@override String get lastModifiedOldToNew => 'Düzenlendi (En eskiden önce)';
}

// Path: sentry.consent
class _Translations$sentry$consent$tr extends Translations$sentry$consent$en {
	_Translations$sentry$consent$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override late final _Translations$sentry$consent$description$tr description = _Translations$sentry$consent$description$tr._(_root);
	@override late final _Translations$sentry$consent$answers$tr answers = _Translations$sentry$consent$answers$tr._(_root);
	@override String get title => 'nts geliştirmeye yardımcı olur mu?';
}

// Path: settings.prefCategories
class _Translations$settings$prefCategories$tr extends Translations$settings$prefCategories$en {
	_Translations$settings$prefCategories$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get general => 'Genel';
	@override String get writing => 'Yazım';
	@override String get editor => 'Editör';
	@override String get performance => 'Performans';
	@override String get advanced => 'Gelişmiş';
}

// Path: settings.prefLabels
class _Translations$settings$prefLabels$tr extends Translations$settings$prefLabels$en {
	_Translations$settings$prefLabels$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get locale => 'Uygulama dili';
	@override String get appTheme => 'Uygulama teması';
	@override String get platform => 'Tema tipi';
	@override String get layoutSize => 'Yerleşim tipi';
	@override String get customAccentColor => 'Farklı ana renk';
	@override String get hyperlegibleFont => 'Hyperlegible font';
	@override String get editorToolbarAlignment => 'Editör araç çubuğunun yerleşimi';
	@override String get editorToolbarShowInFullscreen => 'Editör araç kutusunu tam ekranda göster';
	@override String get editorAutoInvert => 'Karanlık temada notların rengini tersine çevir';
	@override String get preferGreyscale => 'Gri tonlamayı tercih et';
	@override String get maxImageSize => 'Maksimum görsel boyutu';
	@override String get autoClearWhiteboardOnExit => 'Uygulamadan çıkıldığında beyaz tahtayı temizle';
	@override String get disableEraserAfterUse => 'Silgiden kaleme geçiş';
	@override String get hideFingerDrawingToggle => 'Parmakla çizme kilidini sakla';
	@override String get editorPromptRename => 'Notları yeniden adlandırmak için uyar';
	@override String get recentColorsDontSavePresets => 'Ön tanımlı renkleri son kullanılanlara kaydetme';
	@override String get recentColorsLength => 'Kaç tane son kullanılan renk saklanacak';
	@override String get printPageIndicators => 'Sayfa belirteçlerini yazdır';
	@override String get shapeRecognitionDelay => 'Şekil tanıma gecikmesi';
	@override String get autoStraightenLines => 'Çizgileri otomatik düzleştir';
	@override String get customDataDir => 'Özel nts klasörü';
	@override String get autoDisableFingerDrawingWhenStylusDetected => 'Parmak çizimini otomatik olarak devre dışı bırak';
	@override String get sentry => 'Hata raporlama';
	@override String get autosave => 'Otomatik koruma';
}

// Path: settings.prefDescriptions
class _Translations$settings$prefDescriptions$tr extends Translations$settings$prefDescriptions$en {
	_Translations$settings$prefDescriptions$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get hyperlegibleFont => 'Atkinson Hyperlegible, görme sorunu yaşayanların okumasını kolaylaştıran bir fonttur';
	@override String get preferGreyscale => 'E-mürekkep ekranlar için';
	@override String get autoClearWhiteboardOnExit => 'Diğer cihazlarınıza senkronize edilmeye devam edecek';
	@override String get disableEraserAfterUse => 'Silgiyi kullandıktan sonra otomatik olarak kaleme geçer';
	@override String get maxImageSize => 'Bundan daha büyük görseller sıkıştırılacak';
	@override late final _Translations$settings$prefDescriptions$hideFingerDrawing$tr hideFingerDrawing = _Translations$settings$prefDescriptions$hideFingerDrawing$tr._(_root);
	@override String get editorPromptRename => 'Notlarınızı daha sonra da yeniden adlandırabilirsiniz';
	@override String get printPageIndicators => 'Çıktılarda sayfa belirteçlerini göster';
	@override String get shapeRecognitionDelay => 'Çizilen şekilleri tanımlama sıklığını belirler';
	@override String get autoStraightenLines => 'Şekil aracını kullanmadığınızda da çizgileri düzleştirir';
	@override late final _Translations$settings$prefDescriptions$sentry$tr sentry = _Translations$settings$prefDescriptions$sentry$tr._(_root);
	@override String get autoDisableFingerDrawingWhenStylusDetected => 'Bir kalem algılandığında parmakla çizimi kapatın';
	@override String get autosave => 'Kısa bir gecikmeden sonra otomatik kaydetme veya asla';
}

// Path: settings.themeModes
class _Translations$settings$themeModes$tr extends Translations$settings$themeModes$en {
	_Translations$settings$themeModes$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get system => 'Sistem teması';
	@override String get light => 'Aydınlık';
	@override String get dark => 'Karanlık';
}

// Path: settings.layoutSizes
class _Translations$settings$layoutSizes$tr extends Translations$settings$layoutSizes$en {
	_Translations$settings$layoutSizes$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Otomatik';
	@override String get phone => 'Telefon';
	@override String get tablet => 'Tablet';
}

// Path: settings.accentColorPicker
class _Translations$settings$accentColorPicker$tr extends Translations$settings$accentColorPicker$en {
	_Translations$settings$accentColorPicker$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get pickAColor => 'Bir renk seçin';
}

// Path: settings.reset
class _Translations$settings$reset$tr extends Translations$settings$reset$en {
	_Translations$settings$reset$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ayarı sıfırlamak istiyor musunuz?';
	@override String get button => 'Sıfırla';
}

// Path: settings.customDataDir
class _Translations$settings$customDataDir$tr extends Translations$settings$customDataDir$en {
	_Translations$settings$customDataDir$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get cancel => 'İptal';
	@override String get select => 'Seç';
	@override String get mustBeEmpty => 'Seçilen klasör boş olmalı';
	@override String get unsupported => 'Bu özellik şu anda yalnızca geliştiriciler içindir. Bunu kullanmak muhtemelen veri kaybına neden olacaktır.';
}

// Path: editor.toolbar
class _Translations$editor$toolbar$tr extends Translations$editor$toolbar$en {
	_Translations$editor$toolbar$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get toggleColors => 'Renklere geç (Ctrl C)';
	@override String get select => 'Seç';
	@override String get toggleEraser => 'Silgiyi aktifleştir (Ctrl E)';
	@override String get photo => 'Fotoğraf';
	@override String get text => 'Metin';
	@override String get toggleFingerDrawing => 'Parmakla çizimi aktifleştir (Ctrl F)';
	@override String get undo => 'Geri al';
	@override String get redo => 'Yeniden yap';
	@override String get export => 'Dışa aktar (Ctrl Shift S)';
	@override String get exportAs => 'Farklı formatta dışa aktar:';
	@override String get fullscreen => 'Tam ekrana geç (F11)';
}

// Path: editor.pens
class _Translations$editor$pens$tr extends Translations$editor$pens$en {
	_Translations$editor$pens$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get fountainPen => 'Dolma kalem';
	@override String get ballpointPen => 'Tükenmez kalem';
	@override String get highlighter => 'İşaretleme kalemi';
	@override String get pencil => 'Kalem';
	@override String get shapePen => 'Şekil kalemi';
	@override String get laserPointer => 'Lazer işaretçi';
}

// Path: editor.penOptions
class _Translations$editor$penOptions$tr extends Translations$editor$penOptions$en {
	_Translations$editor$penOptions$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get size => 'Boyut';
}

// Path: editor.colors
class _Translations$editor$colors$tr extends Translations$editor$colors$en {
	_Translations$editor$colors$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get colorPicker => 'Renk seçici';
	@override String customBrightnessHue({required Object b, required Object h}) => 'Seçili ${b} ${h}';
	@override String customHue({required Object h}) => 'Seçili ${h}';
	@override String get dark => 'karanlık';
	@override String get light => 'aydınlık';
	@override String get black => 'Siyah';
	@override String get darkGrey => 'Koyu gri';
	@override String get grey => 'Gri';
	@override String get lightGrey => 'Açık gri';
	@override String get white => 'Beyaz';
	@override String get red => 'Kırmızı';
	@override String get green => 'Yeşil';
	@override String get cyan => 'Turkuaz';
	@override String get blue => 'Mavi';
	@override String get yellow => 'Sarı';
	@override String get purple => 'Mor';
	@override String get pink => 'Pembe';
	@override String get orange => 'Turuncu';
	@override String get pastelRed => 'Pastel kırmızı';
	@override String get pastelOrange => 'Pastel turuncu';
	@override String get pastelYellow => 'Pastel sarı';
	@override String get pastelGreen => 'Pastel yeşil';
	@override String get pastelCyan => 'Pastel camgöbeği';
	@override String get pastelBlue => 'Pastel mavi';
	@override String get pastelPurple => 'Pastel mor';
	@override String get pastelPink => 'Pastel pembe';
}

// Path: editor.imageOptions
class _Translations$editor$imageOptions$tr extends Translations$editor$imageOptions$en {
	_Translations$editor$imageOptions$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Görüntü ayarları';
	@override String get invertible => '(Rengi) Tersine çevrilebilir';
	@override String get download => 'İndir';
	@override String get setAsBackground => 'Arkaplan olarak ayarla';
	@override String get removeAsBackground => 'Arkaplanı kaldır';
	@override String get delete => 'Sil';
}

// Path: editor.selectionBar
class _Translations$editor$selectionBar$tr extends Translations$editor$selectionBar$en {
	_Translations$editor$selectionBar$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get delete => 'Sil';
	@override String get duplicate => 'Çoğalt';
}

// Path: editor.menu
class _Translations$editor$menu$tr extends Translations$editor$menu$en {
	_Translations$editor$menu$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String clearPage({required Object page, required Object totalPages}) => '${page}/${totalPages} numaralı sayfayı temizle';
	@override String get clearAllPages => 'Tüm sayfaları temizle';
	@override String get insertPage => 'Aşağıya sayfa ekle';
	@override String get duplicatePage => 'Sayfayı çoğalt';
	@override String get deletePage => 'Sayfayı sil';
	@override String get lineHeight => 'Satır aralığı';
	@override String get lineHeightDescription => 'Klavye girişi olan notların metin boyutunu da kontrol eder';
	@override String get backgroundImageFit => 'Arkaplan görüntüsünü sığdır';
	@override String get backgroundPattern => 'Arkaplan deseni';
	@override String get import => 'İçe aktar';
	@override late final _Translations$editor$menu$boxFits$tr boxFits = _Translations$editor$menu$boxFits$tr._(_root);
	@override late final _Translations$editor$menu$bgPatterns$tr bgPatterns = _Translations$editor$menu$bgPatterns$tr._(_root);
	@override String get lineThickness => 'Çizgi kalınlığı';
	@override String get lineThicknessDescription => 'Arka plan çizgisi kalınlığı';
}

// Path: editor.readOnlyBanner
class _Translations$editor$readOnlyBanner$tr extends Translations$editor$readOnlyBanner$en {
	_Translations$editor$readOnlyBanner$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Yalnızca okunabilir mod';
	@override String get watchingServer => 'Şu anda sunucudaki güncellemeleri izliyorsunuz. Bu modda düzenleme devre dışı bırakılır.';
	@override String get corrupted => 'Not yüklenemedi. Bozulmuş veya hâlâ indiriliyor olabilir.';
}

// Path: editor.versionTooNew
class _Translations$editor$versionTooNew$tr extends Translations$editor$versionTooNew$en {
	_Translations$editor$versionTooNew$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bu not nts\'nin yeni bir versiyonunda düzenlenmiş';
	@override String get subtitle => 'Bu notu düzenlemek veri kaybına sebep olabilir. Bunu görmezden gelerek düzenlemek ister misiniz?';
	@override String get allowEditing => 'Düzenlemeye izin ver';
}

// Path: editor.quill
class _Translations$editor$quill$tr extends Translations$editor$quill$en {
	_Translations$editor$quill$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get typeSomething => 'Buraya bir şey yaz…';
}

// Path: editor.hud
class _Translations$editor$hud$tr extends Translations$editor$hud$en {
	_Translations$editor$hud$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get unlockZoom => 'Yakınlaştırma kilidini aç';
	@override String get lockZoom => 'Yakınlaştırmayı kilitle';
	@override String get unlockSingleFingerPan => 'Tek parmakla kaydırma kilidini aç';
	@override String get lockSingleFingerPan => 'Tek parmakla kaydırmayı kilitle';
	@override String get unlockAxisAlignedPan => 'Yatay ve dikey hareket kilidini aç';
	@override String get lockAxisAlignedPan => 'Yatay ve dikey hareketi kilitle';
}

// Path: sentry.consent.description
class _Translations$sentry$consent$description$tr extends Translations$sentry$consent$description$en {
	_Translations$sentry$consent$description$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get question => 'Beklenmedik hataları otomatik olarak bildirmek ister misiniz? Bu, sorunları daha hızlı tanımlamama ve düzeltmeme yardımcı olur.';
	@override String get scope => 'Raporlar hata ve cihazınız hakkında bilgi içerebilir. Kişisel verileri filtrelemek için her türlü çabayı gösterdim, ancak bazıları kalabilir.';
	@override String get currentlyOff => 'Onay verirseniz, uygulamayı yeniden başlattıktan sonra hata raporlaması etkinleştirilir.';
	@override String get currentlyOn => 'Onayı iptal ederseniz, hata raporlamasını devre dışı bırakmak için lütfen uygulamayı yeniden başlatın.';
	@override TextSpan learnMoreInPrivacyPolicy({required InlineSpanBuilder link}) => TextSpan(children: [
		link('Gizlilik Politikası'),
		const TextSpan(text: ' \'da daha fazla bilgi edinin.'),
	]);
}

// Path: sentry.consent.answers
class _Translations$sentry$consent$answers$tr extends Translations$sentry$consent$answers$en {
	_Translations$sentry$consent$answers$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get yes => 'Evet';
	@override String get no => 'HAYIR';
	@override String get later => 'Bana sonra sor';
}

// Path: settings.prefDescriptions.hideFingerDrawing
class _Translations$settings$prefDescriptions$hideFingerDrawing$tr extends Translations$settings$prefDescriptions$hideFingerDrawing$en {
	_Translations$settings$prefDescriptions$hideFingerDrawing$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get shown => 'Yanlışlıkla değiştirilmesini engeller';
	@override String get fixedOn => 'Parmakla çizim izni verildi ve sabitlendi';
	@override String get fixedOff => 'Parmakla çizim izni verilmedi ve sabitlendi';
}

// Path: settings.prefDescriptions.sentry
class _Translations$settings$prefDescriptions$sentry$tr extends Translations$settings$prefDescriptions$sentry$en {
	_Translations$settings$prefDescriptions$sentry$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get active => 'Aktif';
	@override String get inactive => 'Aktif olmayan';
	@override String get activeUntilRestart => 'Uygulamayı yeniden başlatana kadar etkin';
	@override String get inactiveUntilRestart => 'Uygulamayı yeniden başlatana kadar aktif olmayan';
}

// Path: editor.menu.boxFits
class _Translations$editor$menu$boxFits$tr extends Translations$editor$menu$boxFits$en {
	_Translations$editor$menu$boxFits$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get fill => 'Yaydır';
	@override String get cover => 'Kapla';
	@override String get contain => 'İçer';
}

// Path: editor.menu.bgPatterns
class _Translations$editor$menu$bgPatterns$tr extends Translations$editor$menu$bgPatterns$en {
	_Translations$editor$menu$bgPatterns$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get none => 'Boş';
	@override String get college => 'Std. çizgili defter';
	@override String get collegeRtl => 'Std. çizgili defter (Tersine çevrik)';
	@override String get lined => 'Çizgili';
	@override String get grid => 'Kareli';
	@override String get dots => 'Noktalı';
	@override String get staffs => 'Porte (müzik)';
	@override String get tablature => 'Nota kağıdı';
	@override String get cornell => 'Cornell not şablonu';
}
