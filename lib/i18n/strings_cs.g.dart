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
class TranslationsCs extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsCs({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.cs,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <cs>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	late final TranslationsCs _root = this; // ignore: unused_field

	@override 
	TranslationsCs $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsCs(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$cs common = _Translations$common$cs._(_root);
	@override late final _Translations$home$cs home = _Translations$home$cs._(_root);
	@override late final _Translations$sentry$cs sentry = _Translations$sentry$cs._(_root);
	@override late final _Translations$settings$cs settings = _Translations$settings$cs._(_root);
	@override late final _Translations$logs$cs logs = _Translations$logs$cs._(_root);
	@override late final _Translations$appInfo$cs appInfo = _Translations$appInfo$cs._(_root);
	@override late final _Translations$editor$cs editor = _Translations$editor$cs._(_root);
}

// Path: common
class _Translations$common$cs extends Translations$common$en {
	_Translations$common$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get done => 'Dokončit';
	@override String get continueBtn => 'Pokračovat';
	@override String get cancel => 'Zrušit';
}

// Path: home
class _Translations$home$cs extends Translations$home$en {
	_Translations$home$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$home$titles$cs titles = _Translations$home$titles$cs._(_root);
	@override late final _Translations$home$tooltips$cs tooltips = _Translations$home$tooltips$cs._(_root);
	@override late final _Translations$home$create$cs create = _Translations$home$create$cs._(_root);
	@override String get welcome => 'Vítejte v aplikaci nts';
	@override String get invalidFormat => 'Vybrali jste nepodporovaný soubor. Vyberte prosím soubor s příponou .sbn, .sbn2, .sba nebo .pdf.';
	@override String get createNewNote => 'Pro přidání nové poznámky klepněte na tlačítko +';
	@override String get backFolder => 'Přejít do předchozí složky';
	@override late final _Translations$home$newFolder$cs newFolder = _Translations$home$newFolder$cs._(_root);
	@override late final _Translations$home$renameNote$cs renameNote = _Translations$home$renameNote$cs._(_root);
	@override late final _Translations$home$moveNote$cs moveNote = _Translations$home$moveNote$cs._(_root);
	@override String get deleteNote => 'Odstranit poznámku';
	@override late final _Translations$home$deleteNoteDialog$cs deleteNoteDialog = _Translations$home$deleteNoteDialog$cs._(_root);
	@override late final _Translations$home$renameFolder$cs renameFolder = _Translations$home$renameFolder$cs._(_root);
	@override late final _Translations$home$deleteFolder$cs deleteFolder = _Translations$home$deleteFolder$cs._(_root);
	@override late final _Translations$home$sort$cs sort = _Translations$home$sort$cs._(_root);
}

// Path: sentry
class _Translations$sentry$cs extends Translations$sentry$en {
	_Translations$sentry$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$sentry$consent$cs consent = _Translations$sentry$consent$cs._(_root);
}

// Path: settings
class _Translations$settings$cs extends Translations$settings$en {
	_Translations$settings$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$settings$prefCategories$cs prefCategories = _Translations$settings$prefCategories$cs._(_root);
	@override late final _Translations$settings$prefLabels$cs prefLabels = _Translations$settings$prefLabels$cs._(_root);
	@override late final _Translations$settings$prefDescriptions$cs prefDescriptions = _Translations$settings$prefDescriptions$cs._(_root);
	@override late final _Translations$settings$themeModes$cs themeModes = _Translations$settings$themeModes$cs._(_root);
	@override late final _Translations$settings$layoutSizes$cs layoutSizes = _Translations$settings$layoutSizes$cs._(_root);
	@override late final _Translations$settings$accentColorPicker$cs accentColorPicker = _Translations$settings$accentColorPicker$cs._(_root);
	@override String get systemLanguage => 'Zvolit automaticky';
	@override List<String> get axisDirections => [
		'Nahoře',
		'Vpravo',
		'Dole',
		'Vlevo',
	];
	@override late final _Translations$settings$reset$cs reset = _Translations$settings$reset$cs._(_root);
	@override String get openDataDir => 'Otevřít složku aplikace nts';
	@override late final _Translations$settings$customDataDir$cs customDataDir = _Translations$settings$customDataDir$cs._(_root);
	@override String get autosaveDisabled => 'Nikdy';
	@override String get shapeRecognitionDisabled => 'Nikdy';
}

// Path: logs
class _Translations$logs$cs extends Translations$logs$en {
	_Translations$logs$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get logs => 'Logy';
	@override String get viewLogs => 'Zobrazit logy';
	@override String get debuggingInfo => 'Logy obsahují informace užitečné pro ladění a vývoj';
	@override String get noLogs => 'Nejsou k dispozici žádné logy!';
	@override String get useTheApp => 'Jakmile aplikaci začnete používat, logy se zobrazí na tomto místě';
}

// Path: appInfo
class _Translations$appInfo$cs extends Translations$appInfo$en {
	_Translations$appInfo$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String licenseNotice({required Object buildYear}) => 'nts (modified from Saber)  Copyright © 2022-${buildYear}  Adil Hanney\nTento program je poskytován bez jakékoliv záruky. Jedná se o software poskytovaný zdarma, který je možné šířit při splnění určitých podmínek.';
	@override String get debug => 'LADÍCÍ VERZE';
	@override String get licenseButton => 'Klepněte sem pro zobrazení podrobnějších licenčních informací';
	@override String get privacyPolicyButton => 'Klepněte sem pro zobrazení zásad ochrany osobních údajů';
}

// Path: editor
class _Translations$editor$cs extends Translations$editor$en {
	_Translations$editor$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$editor$toolbar$cs toolbar = _Translations$editor$toolbar$cs._(_root);
	@override late final _Translations$editor$pens$cs pens = _Translations$editor$pens$cs._(_root);
	@override late final _Translations$editor$penOptions$cs penOptions = _Translations$editor$penOptions$cs._(_root);
	@override late final _Translations$editor$colors$cs colors = _Translations$editor$colors$cs._(_root);
	@override late final _Translations$editor$imageOptions$cs imageOptions = _Translations$editor$imageOptions$cs._(_root);
	@override late final _Translations$editor$selectionBar$cs selectionBar = _Translations$editor$selectionBar$cs._(_root);
	@override late final _Translations$editor$menu$cs menu = _Translations$editor$menu$cs._(_root);
	@override late final _Translations$editor$readOnlyBanner$cs readOnlyBanner = _Translations$editor$readOnlyBanner$cs._(_root);
	@override late final _Translations$editor$versionTooNew$cs versionTooNew = _Translations$editor$versionTooNew$cs._(_root);
	@override late final _Translations$editor$quill$cs quill = _Translations$editor$quill$cs._(_root);
	@override late final _Translations$editor$hud$cs hud = _Translations$editor$hud$cs._(_root);
	@override String get pages => 'Stránky';
	@override String get untitled => 'Nepojmenovaná poznámka';
	@override String get needsToSaveBeforeExiting => 'Ukládání změn… Po skončení této operace můžete editor bezpečně opustit';
}

// Path: home.titles
class _Translations$home$titles$cs extends Translations$home$titles$en {
	_Translations$home$titles$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get home => 'Poslední poznámky';
	@override String get browse => 'Procházet poznámky';
	@override String get whiteboard => 'Tabule';
	@override String get settings => 'Nastavení';
}

// Path: home.tooltips
class _Translations$home$tooltips$cs extends Translations$home$tooltips$en {
	_Translations$home$tooltips$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get newNote => 'Nová poznámka';
	@override String get exportNote => 'Exportovat poznámku';
}

// Path: home.create
class _Translations$home$create$cs extends Translations$home$create$en {
	_Translations$home$create$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get newNote => 'Nová poznámka';
	@override String get importNote => 'Import poznámky';
}

// Path: home.newFolder
class _Translations$home$newFolder$cs extends Translations$home$newFolder$en {
	_Translations$home$newFolder$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get newFolder => 'Nová složka';
	@override String get folderName => 'Název složky';
	@override String get create => 'Vytvořit';
	@override String get folderNameEmpty => 'Název složky nemůže být prázdný';
	@override String get folderNameContainsSlash => 'Název složky nemůže obsahovat lomítko';
	@override String get folderNameExists => 'Složka s tímto názvem již existuje';
}

// Path: home.renameNote
class _Translations$home$renameNote$cs extends Translations$home$renameNote$en {
	_Translations$home$renameNote$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get renameNote => 'Přejmenovat poznámku';
	@override String get noteName => 'Nový název poznámky';
	@override String get rename => 'Přejmenovat';
	@override String get noteNameEmpty => 'Název poznámky nemůže být prázdný';
	@override String get noteNameExists => 'Poznámka s tímto názvem již existuje';
	@override String get noteNameForbiddenCharacters => 'Zadaný název poznámky obsahuje nepovolené znaky';
	@override String get noteNameReserved => 'Tento název poznámky je rezervovaný pro účely aplikace';
}

// Path: home.moveNote
class _Translations$home$moveNote$cs extends Translations$home$moveNote$en {
	_Translations$home$moveNote$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get moveNote => 'Přesunout poznámku';
	@override String moveNotes({required Object n}) => 'Přesunout ${n} poznámek';
	@override String moveName({required Object f}) => 'Přesun poznámky ${f}';
	@override String get move => 'Přesunout';
	@override String renamedTo({required Object newName}) => 'Poznámka bude přejmenována na ${newName}';
	@override String get multipleRenamedTo => 'Následující poznámky budou přejmenovány:';
	@override String numberRenamedTo({required Object n}) => '${n} poznámek bude přejmenováno';
}

// Path: home.deleteNoteDialog
class _Translations$home$deleteNoteDialog$cs extends Translations$home$deleteNoteDialog$en {
	_Translations$home$deleteNoteDialog$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String deleteNotes({required Object n}) => 'Odstranit ${n} poznámek';
	@override String deleteName({required Object f}) => 'Odstranit poznámku ${f}';
	@override String confirmDelete({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(n,
		one: 'Přejete si trvale odstranit zvolenou poznámku?',
		other: 'Přejete si trvale odstranit zvolené poznámky?',
	);
	@override String get delete => 'Odstranit';
}

// Path: home.renameFolder
class _Translations$home$renameFolder$cs extends Translations$home$renameFolder$en {
	_Translations$home$renameFolder$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get renameFolder => 'Přejmenovat složku';
	@override String get folderName => 'Název složky';
	@override String get rename => 'Přejmenovat';
	@override String get folderNameEmpty => 'Název složky nemůže být prázdný';
	@override String get folderNameContainsSlash => 'Název složky nemůže obsahovat lomítko';
	@override String get folderNameExists => 'Složka s tímto názvem již existuje';
}

// Path: home.deleteFolder
class _Translations$home$deleteFolder$cs extends Translations$home$deleteFolder$en {
	_Translations$home$deleteFolder$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get deleteFolder => 'Odstranit složku';
	@override String deleteName({required Object f}) => 'Odstranění složky ${f}';
	@override String get delete => 'Odstranit';
	@override String get alsoDeleteContents => 'Se složkou odstranit i obsažené poznámky';
}

// Path: home.sort
class _Translations$home$sort$cs extends Translations$home$sort$en {
	_Translations$home$sort$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get sortBy => 'Řazení podle';
	@override String get nameAToZ => 'Názvu (A–Z)';
	@override String get nameZToA => 'Názvu (Z–A)';
	@override String get lastModifiedNewToOld => 'Změny (nejprve novější)';
	@override String get lastModifiedOldToNew => 'Změny (nejprve starší)';
}

// Path: sentry.consent
class _Translations$sentry$consent$cs extends Translations$sentry$consent$en {
	_Translations$sentry$consent$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Chcete pomoct vylepšit aplikaci nts?';
	@override late final _Translations$sentry$consent$description$cs description = _Translations$sentry$consent$description$cs._(_root);
	@override late final _Translations$sentry$consent$answers$cs answers = _Translations$sentry$consent$answers$cs._(_root);
}

// Path: settings.prefCategories
class _Translations$settings$prefCategories$cs extends Translations$settings$prefCategories$en {
	_Translations$settings$prefCategories$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get general => 'Obecné';
	@override String get writing => 'Psaní';
	@override String get editor => 'Editor';
	@override String get performance => 'Výkon';
	@override String get advanced => 'Pokročilé';
}

// Path: settings.prefLabels
class _Translations$settings$prefLabels$cs extends Translations$settings$prefLabels$en {
	_Translations$settings$prefLabels$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get locale => 'Jazyk';
	@override String get appTheme => 'Barva motivu';
	@override String get platform => 'Motiv';
	@override String get layoutSize => 'Rozvržení uživatelského rozhraní';
	@override String get customAccentColor => 'Vlastní barevný odstín';
	@override String get hyperlegibleFont => 'Lépe čitelný font';
	@override String get editorToolbarAlignment => 'Umístění nabídky editoru';
	@override String get editorToolbarShowInFullscreen => 'Zobrazovat nabídku editoru v režimu celé obrazovky';
	@override String get editorAutoInvert => 'V tmavém režimu invertovat poznámky';
	@override String get preferGreyscale => 'Preferovat černobílé barvy';
	@override String get maxImageSize => 'Maximální velikost obrázku';
	@override String get autoClearWhiteboardOnExit => 'Smazat tabuli po opuštění aplikace';
	@override String get disableEraserAfterUse => 'Automaticky vypínat gumu';
	@override String get hideFingerDrawingToggle => 'Skrýt přepínač pro kreslení prstem';
	@override String get autoDisableFingerDrawingWhenStylusDetected => 'Automaticky vypínat kreslení prstem';
	@override String get editorPromptRename => 'Vybízet k přejmenování nových poznámek';
	@override String get recentColorsDontSavePresets => 'Neukládat přednastavené barvy mezi naposledy použité barvy';
	@override String get recentColorsLength => 'Kolik naposledy použitých barev se má ukládat';
	@override String get printPageIndicators => 'Tisknout čísla stránek';
	@override String get autosave => 'Automatické ukládání';
	@override String get shapeRecognitionDelay => 'Zpoždění rozpoznávání tvarů';
	@override String get autoStraightenLines => 'Automaticky narovnávat čáry';
	@override String get customDataDir => 'Vlastní umístění složky aplikace nts';
	@override String get sentry => 'Hlášení chyb';
}

// Path: settings.prefDescriptions
class _Translations$settings$prefDescriptions$cs extends Translations$settings$prefDescriptions$en {
	_Translations$settings$prefDescriptions$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get hyperlegibleFont => 'Font Atkinson Hyperlegible zvyšuje čitelnost pro čtenáře se slabým zrakem';
	@override String get preferGreyscale => 'Pro elektronické čtečky knih s e-ink displejem';
	@override String get autoClearWhiteboardOnExit => 'Bude synchronizováno do dalších zařízení';
	@override String get disableEraserAfterUse => 'Po použití gumy automaticky přepnout zpět na pero';
	@override String get maxImageSize => 'Na větší obrázky bude aplikována komprese';
	@override late final _Translations$settings$prefDescriptions$hideFingerDrawing$cs hideFingerDrawing = _Translations$settings$prefDescriptions$hideFingerDrawing$cs._(_root);
	@override String get autoDisableFingerDrawingWhenStylusDetected => 'Kreslení prstem se vypne, pokud je detekován stylus';
	@override String get editorPromptRename => 'Poznámky můžete vždy přejmenovat i později';
	@override String get printPageIndicators => 'V exportech budou zobrazena čísla stránek';
	@override String get autosave => 'Poznámky se budou automaticky ukládat po krátké prodlevě, nebo nikdy';
	@override String get shapeRecognitionDelay => 'Jak často aktualizovat náhled tvaru';
	@override String get autoStraightenLines => 'Automaticky narovná dlouhé čáry, aniž by bylo nutné využít tvarové pero';
	@override late final _Translations$settings$prefDescriptions$sentry$cs sentry = _Translations$settings$prefDescriptions$sentry$cs._(_root);
}

// Path: settings.themeModes
class _Translations$settings$themeModes$cs extends Translations$settings$themeModes$en {
	_Translations$settings$themeModes$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get system => 'Systémový';
	@override String get light => 'Světlý';
	@override String get dark => 'Tmavý';
}

// Path: settings.layoutSizes
class _Translations$settings$layoutSizes$cs extends Translations$settings$layoutSizes$en {
	_Translations$settings$layoutSizes$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automatické';
	@override String get phone => 'Telefon';
	@override String get tablet => 'Tablet';
}

// Path: settings.accentColorPicker
class _Translations$settings$accentColorPicker$cs extends Translations$settings$accentColorPicker$en {
	_Translations$settings$accentColorPicker$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get pickAColor => 'Výběr vlastní barvy';
}

// Path: settings.reset
class _Translations$settings$reset$cs extends Translations$settings$reset$en {
	_Translations$settings$reset$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Chcete resetovat tuto volbu?';
	@override String get button => 'Resetovat';
}

// Path: settings.customDataDir
class _Translations$settings$customDataDir$cs extends Translations$settings$customDataDir$en {
	_Translations$settings$customDataDir$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get cancel => 'Zrušit';
	@override String get select => 'Zvolit';
	@override String get mustBeEmpty => 'Zvolená složka musí být prázdná';
	@override String get unsupported => 'Tato funkce je v současné době pouze pro vývojáře. Její využití pravděpodobně povede ke ztrátě dat.';
}

// Path: editor.toolbar
class _Translations$editor$toolbar$cs extends Translations$editor$toolbar$en {
	_Translations$editor$toolbar$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get toggleColors => 'Změnit barvu (Ctrl C)';
	@override String get select => 'Výběr';
	@override String get toggleEraser => 'Guma (Ctrl E)';
	@override String get photo => 'Obrázek';
	@override String get text => 'Text';
	@override String get toggleFingerDrawing => 'Možnost kreslení prstem (Ctrl F)';
	@override String get undo => 'Zpět';
	@override String get redo => 'Obnovit';
	@override String get export => 'Exportovat (Ctrl Shift S)';
	@override String get exportAs => 'Exportovat jako:';
	@override String get fullscreen => 'Režim celé obrazovky (F11)';
}

// Path: editor.pens
class _Translations$editor$pens$cs extends Translations$editor$pens$en {
	_Translations$editor$pens$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get fountainPen => 'Plnící pero';
	@override String get ballpointPen => 'Kuličkové pero';
	@override String get highlighter => 'Zvýrazňovač';
	@override String get pencil => 'Tužka';
	@override String get shapePen => 'Pero pro kreslení tvarů';
	@override String get laserPointer => 'Laserové ukazovátko';
}

// Path: editor.penOptions
class _Translations$editor$penOptions$cs extends Translations$editor$penOptions$en {
	_Translations$editor$penOptions$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get size => 'Velikost';
}

// Path: editor.colors
class _Translations$editor$colors$cs extends Translations$editor$colors$en {
	_Translations$editor$colors$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get colorPicker => 'Zvolit vlastní barvu';
	@override String customBrightnessHue({required Object b, required Object h}) => 'Vlastní ${b} ${h}';
	@override String customHue({required Object h}) => 'Vlastní ${h}';
	@override String get dark => 'tmavě';
	@override String get light => 'světle';
	@override String get black => 'Černá';
	@override String get darkGrey => 'Tmavě šedá';
	@override String get grey => 'Šedá';
	@override String get lightGrey => 'Světle šedá';
	@override String get white => 'Bílá';
	@override String get red => 'Červená';
	@override String get green => 'Zelená';
	@override String get cyan => 'Azurová';
	@override String get blue => 'Modrá';
	@override String get yellow => 'Žlutá';
	@override String get purple => 'Purpurová';
	@override String get pink => 'Růžová';
	@override String get orange => 'Oranžová';
	@override String get pastelRed => 'Pastelová červená';
	@override String get pastelOrange => 'Pastelová oranžová';
	@override String get pastelYellow => 'Pastelová žlutá';
	@override String get pastelGreen => 'Pastelová zelená';
	@override String get pastelCyan => 'Pastelová azurová';
	@override String get pastelBlue => 'Pastelová modrá';
	@override String get pastelPurple => 'Pastelová purpurová';
	@override String get pastelPink => 'Pastelová růžová';
}

// Path: editor.imageOptions
class _Translations$editor$imageOptions$cs extends Translations$editor$imageOptions$en {
	_Translations$editor$imageOptions$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Možnosti obrázku';
	@override String get invertible => 'Invertovat podle motivu';
	@override String get download => 'Stáhnout';
	@override String get setAsBackground => 'Nastavit na pozadí';
	@override String get removeAsBackground => 'Odstranit obrázek z pozadí';
	@override String get delete => 'Odstranit';
}

// Path: editor.selectionBar
class _Translations$editor$selectionBar$cs extends Translations$editor$selectionBar$en {
	_Translations$editor$selectionBar$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get delete => 'Odstranit';
	@override String get duplicate => 'Duplikovat';
}

// Path: editor.menu
class _Translations$editor$menu$cs extends Translations$editor$menu$en {
	_Translations$editor$menu$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String clearPage({required Object page, required Object totalPages}) => 'Smazat obsah stránky ${page}/${totalPages}';
	@override String get clearAllPages => 'Smazat všechny stránky';
	@override String get insertPage => 'Přidat stránku za tuto';
	@override String get duplicatePage => 'Duplikovat stránku';
	@override String get deletePage => 'Odstranit stránku';
	@override String get lineHeight => 'Výška řádku';
	@override String get lineHeightDescription => 'Ovlivňuje také velikost textu psaných poznámek';
	@override String get lineThickness => 'Tloušťka linek';
	@override String get lineThicknessDescription => 'Tloušťka čar ve vzoru na pozadí';
	@override String get backgroundImageFit => 'Přizpůsobení obrázku na pozadí';
	@override String get backgroundPattern => 'Vzor na pozadí';
	@override String get import => 'Importovat';
	@override late final _Translations$editor$menu$boxFits$cs boxFits = _Translations$editor$menu$boxFits$cs._(_root);
	@override late final _Translations$editor$menu$bgPatterns$cs bgPatterns = _Translations$editor$menu$bgPatterns$cs._(_root);
}

// Path: editor.readOnlyBanner
class _Translations$editor$readOnlyBanner$cs extends Translations$editor$readOnlyBanner$en {
	_Translations$editor$readOnlyBanner$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Otevřít v režimu pouze pro čtení';
	@override String get watchingServer => 'Aktuálně máte zapnuté sledování změn ze serveru. V tomto módu jsou vypnuté úpravy.';
	@override String get corrupted => 'Poznámku se nepodařilo načíst. Buď se ještě stahuje, nebo může být poškozená.';
}

// Path: editor.versionTooNew
class _Translations$editor$versionTooNew$cs extends Translations$editor$versionTooNew$en {
	_Translations$editor$versionTooNew$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tato poznámka byla upravena v novější verzi aplikace nts';
	@override String get subtitle => 'Úpravou této poznámky můžete přijít o některé informace. Přejete tuto skutečnost ignorovat a přesto pokračovat k úpravě poznámky?';
	@override String get allowEditing => 'Povolit úpravy';
}

// Path: editor.quill
class _Translations$editor$quill$cs extends Translations$editor$quill$en {
	_Translations$editor$quill$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get typeSomething => 'Něco sem napište…';
}

// Path: editor.hud
class _Translations$editor$hud$cs extends Translations$editor$hud$en {
	_Translations$editor$hud$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get unlockZoom => 'Odemknout přibližování';
	@override String get lockZoom => 'Zamknout přibližování';
	@override String get unlockSingleFingerPan => 'Odemknout posouvání jedním prsem';
	@override String get lockSingleFingerPan => 'Zamknout posouvání jedním prsem';
	@override String get unlockAxisAlignedPan => 'Odemknout horizontální a vertikální posouvání';
	@override String get lockAxisAlignedPan => 'Zamknout horizontální a vertikální posouvání';
}

// Path: sentry.consent.description
class _Translations$sentry$consent$description$cs extends Translations$sentry$consent$description$en {
	_Translations$sentry$consent$description$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get question => 'Chtěli byste automaticky nahlašovat neočekávané chyby? Pomohlo by mi to s rychlejší identifikací a opravou.';
	@override String get scope => 'Hlášení mohou obsahovat informace o chybě a vašem zařízení. Dělal jsem, co bylo v mých silách, abych odfiltroval osobní data, ale i tak mohou některá zůstat.';
	@override String get currentlyOff => 'Nahlašování chyb se v případě udělení souhlasu zapne po restartu aplikace.';
	@override String get currentlyOn => 'Po odvolání souhlasu prosím restartujte aplikaci, abyste nahlašování chyb vypnuli.';
	@override TextSpan learnMoreInPrivacyPolicy({required InlineSpanBuilder link}) => TextSpan(children: [
		const TextSpan(text: 'Více se dozvíte v '),
		link('Zásadách ochrany osobních údajů'),
		const TextSpan(text: ' (anglicky).'),
	]);
}

// Path: sentry.consent.answers
class _Translations$sentry$consent$answers$cs extends Translations$sentry$consent$answers$en {
	_Translations$sentry$consent$answers$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get yes => 'Ano';
	@override String get no => 'Ne';
	@override String get later => 'Odložit na později';
}

// Path: settings.prefDescriptions.hideFingerDrawing
class _Translations$settings$prefDescriptions$hideFingerDrawing$cs extends Translations$settings$prefDescriptions$hideFingerDrawing$en {
	_Translations$settings$prefDescriptions$hideFingerDrawing$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get shown => 'Zabraňuje nechtěnému přepnutí';
	@override String get fixedOn => 'Kreslení prstem je napevno zapnuté';
	@override String get fixedOff => 'Kreslení prstem je napevno vypnuté';
}

// Path: settings.prefDescriptions.sentry
class _Translations$settings$prefDescriptions$sentry$cs extends Translations$settings$prefDescriptions$sentry$en {
	_Translations$settings$prefDescriptions$sentry$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get active => 'Aktivní';
	@override String get inactive => 'Neaktivní';
	@override String get activeUntilRestart => 'Aktivní, dokud nerestartujete aplikaci';
	@override String get inactiveUntilRestart => 'Neaktivní, dokud nerestartujete aplikaci';
}

// Path: editor.menu.boxFits
class _Translations$editor$menu$boxFits$cs extends Translations$editor$menu$boxFits$en {
	_Translations$editor$menu$boxFits$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get fill => 'Roztáhnout';
	@override String get cover => 'Vyplnit';
	@override String get contain => 'Přizpůsobit';
}

// Path: editor.menu.bgPatterns
class _Translations$editor$menu$bgPatterns$cs extends Translations$editor$menu$bgPatterns$en {
	_Translations$editor$menu$bgPatterns$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get none => 'Žádný';
	@override String get college => 'Linky s okrajem';
	@override String get collegeRtl => 'Linky s okrajem (obráceně)';
	@override String get lined => 'Linky';
	@override String get grid => 'Čtverečky';
	@override String get dots => 'Tečkovaná mřížka';
	@override String get staffs => 'Notová osnova';
	@override String get tablature => 'Tabulatura';
	@override String get cornell => 'Cornellova metoda';
}
