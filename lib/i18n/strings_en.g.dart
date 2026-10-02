///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  );

	/// Metadata for the translations of <en>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$common$en common = Translations$common$en.internal(_root);
	late final Translations$home$en home = Translations$home$en.internal(_root);
	late final Translations$sentry$en sentry = Translations$sentry$en.internal(_root);
	late final Translations$settings$en settings = Translations$settings$en.internal(_root);
	late final Translations$icloud$en icloud = Translations$icloud$en.internal(_root);
	late final Translations$logs$en logs = Translations$logs$en.internal(_root);
	late final Translations$login$en login = Translations$login$en.internal(_root);
	late final Translations$profile$en profile = Translations$profile$en.internal(_root);
	late final Translations$appInfo$en appInfo = Translations$appInfo$en.internal(_root);
	late final Translations$update$en update = Translations$update$en.internal(_root);
	late final Translations$editor$en editor = Translations$editor$en.internal(_root);
	late final Translations$higan$en higan = Translations$higan$en.internal(_root);
	late final Translations$ai$en ai = Translations$ai$en.internal(_root);
}

// Path: common
class Translations$common$en {
	Translations$common$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Done'
	String get done => 'Done';

	/// en: 'Continue'
	String get continueBtn => 'Continue';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Couldn't save the image to Photos. Allow nts to add photos in Settings.'
	String get savePhotoFailed => 'Couldn\'t save the image to Photos. Allow nts to add photos in Settings.';
}

// Path: home
class Translations$home$en {
	Translations$home$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$home$titles$en titles = Translations$home$titles$en.internal(_root);
	late final Translations$home$tooltips$en tooltips = Translations$home$tooltips$en.internal(_root);
	late final Translations$home$create$en create = Translations$home$create$en.internal(_root);

	/// en: 'Welcome to nts'
	String get welcome => 'Welcome to nts';

	/// en: 'The file you selected is not supported. Please select an sbn, sbn2, sba, or pdf file.'
	String get invalidFormat => 'The file you selected is not supported. Please select an sbn, sbn2, sba, or pdf file.';

	/// en: 'Tap the + button to create a new note'
	String get createNewNote => 'Tap the + button to create a new note';

	/// en: 'Go back to the previous folder'
	String get backFolder => 'Go back to the previous folder';

	late final Translations$home$newFolder$en newFolder = Translations$home$newFolder$en.internal(_root);
	late final Translations$home$renameNote$en renameNote = Translations$home$renameNote$en.internal(_root);
	late final Translations$home$moveNote$en moveNote = Translations$home$moveNote$en.internal(_root);

	/// en: 'Delete note'
	String get deleteNote => 'Delete note';

	late final Translations$home$deleteNoteDialog$en deleteNoteDialog = Translations$home$deleteNoteDialog$en.internal(_root);
	late final Translations$home$renameFolder$en renameFolder = Translations$home$renameFolder$en.internal(_root);
	late final Translations$home$deleteFolder$en deleteFolder = Translations$home$deleteFolder$en.internal(_root);
	late final Translations$home$sort$en sort = Translations$home$sort$en.internal(_root);
	late final Translations$home$menu$en menu = Translations$home$menu$en.internal(_root);
}

// Path: sentry
class Translations$sentry$en {
	Translations$sentry$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$sentry$consent$en consent = Translations$sentry$consent$en.internal(_root);
}

// Path: settings
class Translations$settings$en {
	Translations$settings$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$settings$prefCategories$en prefCategories = Translations$settings$prefCategories$en.internal(_root);
	late final Translations$settings$prefLabels$en prefLabels = Translations$settings$prefLabels$en.internal(_root);
	late final Translations$settings$prefDescriptions$en prefDescriptions = Translations$settings$prefDescriptions$en.internal(_root);
	late final Translations$settings$themeModes$en themeModes = Translations$settings$themeModes$en.internal(_root);
	late final Translations$settings$layoutSizes$en layoutSizes = Translations$settings$layoutSizes$en.internal(_root);
	late final Translations$settings$accentColorPicker$en accentColorPicker = Translations$settings$accentColorPicker$en.internal(_root);

	/// en: 'Auto'
	String get systemLanguage => 'Auto';

	List<String> get axisDirections => [
		'Top',
		'Right',
		'Bottom',
		'Left',
	];
	late final Translations$settings$reset$en reset = Translations$settings$reset$en.internal(_root);

	/// en: 'Resync everything'
	String get resyncEverything => 'Resync everything';

	/// en: 'Open nts folder'
	String get openDataDir => 'Open nts folder';

	late final Translations$settings$customDataDir$en customDataDir = Translations$settings$customDataDir$en.internal(_root);

	/// en: 'Never'
	String get autosaveDisabled => 'Never';

	/// en: 'Never'
	String get shapeRecognitionDisabled => 'Never';
}

// Path: icloud
class Translations$icloud$en {
	Translations$icloud$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'iCloud'
	String get title => 'iCloud';

	/// en: 'Connect iCloud'
	String get connectICloud => 'Connect iCloud';

	/// en: 'Connect'
	String get connect => 'Connect';

	/// en: 'Change folder'
	String get changeFolder => 'Change folder';

	/// en: 'Reconnect'
	String get reconnect => 'Reconnect';

	/// en: 'Refresh from iCloud'
	String get refresh => 'Refresh from iCloud';

	/// en: 'Saving to $folder'
	String savingTo({required Object folder}) => 'Saving to ${folder}';

	/// en: 'This folder isn't in iCloud Drive, so it won't sync'
	String get notInICloud => 'This folder isn\'t in iCloud Drive, so it won\'t sync';

	/// en: 'Not connected — notes are only on this device'
	String get notConnected => 'Not connected — notes are only on this device';

	/// en: 'Reconnect your iCloud folder'
	String get needsReconnect => 'Reconnect your iCloud folder';

	/// en: 'Pick or create a folder in iCloud Drive (for example 'nts'). Use the same folder on your Mac and iPad.'
	String get help => 'Pick or create a folder in iCloud Drive (for example \'nts\'). Use the same folder on your Mac and iPad.';

	/// en: 'Connect iCloud to sync notes between your devices'
	String get banner => 'Connect iCloud to sync notes between your devices';

	/// en: 'Connected. Your notes now save to iCloud Drive.'
	String get connected => 'Connected. Your notes now save to iCloud Drive.';

	/// en: 'Connected, but this folder isn't in iCloud Drive, so your notes won't sync.'
	String get connectedNotICloud => 'Connected, but this folder isn\'t in iCloud Drive, so your notes won\'t sync.';

	/// en: 'Couldn't connect to the iCloud folder.'
	String get failed => 'Couldn\'t connect to the iCloud folder.';

	/// en: 'This note is still downloading from iCloud. Try again in a moment.'
	String get stillDownloading => 'This note is still downloading from iCloud. Try again in a moment.';

	/// en: 'This note was changed on another device, so your changes were saved as '$name'.'
	String savedAsCopy({required Object name}) => 'This note was changed on another device, so your changes were saved as \'${name}\'.';
}

// Path: logs
class Translations$logs$en {
	Translations$logs$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Logs'
	String get logs => 'Logs';

	/// en: 'View logs'
	String get viewLogs => 'View logs';

	/// en: 'Logs contain information useful for debugging and development'
	String get debuggingInfo => 'Logs contain information useful for debugging and development';

	/// en: 'No logs yet'
	String get noLogs => 'No logs yet';

	/// en: 'Logs will appear here as you use the app'
	String get useTheApp => 'Logs will appear here as you use the app';
}

// Path: login
class Translations$login$en {
	Translations$login$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Login'
	String get title => 'Login';

	late final Translations$login$form$en form = Translations$login$form$en.internal(_root);

	/// en: 'Don't have an account yet? ${linkToSignup(Sign up now)}!'
	TextSpan signup({required InlineSpanBuilder linkToSignup}) => TextSpan(children: [
		const TextSpan(text: 'Don\'t have an account yet? '),
		linkToSignup('Sign up now'),
		const TextSpan(text: '!'),
	]);

	/// en: 'Not you? ${undoLogin(Choose another account)}.'
	TextSpan notYou({required InlineSpanBuilder undoLogin}) => TextSpan(children: [
		const TextSpan(text: 'Not you? '),
		undoLogin('Choose another account'),
		const TextSpan(text: '.'),
	]);

	late final Translations$login$status$en status = Translations$login$status$en.internal(_root);
	late final Translations$login$ncLoginStep$en ncLoginStep = Translations$login$ncLoginStep$en.internal(_root);
	late final Translations$login$encLoginStep$en encLoginStep = Translations$login$encLoginStep$en.internal(_root);
}

// Path: profile
class Translations$profile$en {
	Translations$profile$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'My profile'
	String get title => 'My profile';

	/// en: 'Log out'
	String get logout => 'Log out';

	/// en: 'You're using $used of $total ($percent%)'
	String quotaUsage({required Object used, required Object total, required Object percent}) => 'You\'re using ${used} of ${total} (${percent}%)';

	/// en: 'You're using $used'
	String quotaUsageUncapped({required Object used}) => 'You\'re using ${used}';

	/// en: 'Connected to'
	String get connectedTo => 'Connected to';

	late final Translations$profile$quickLinks$en quickLinks = Translations$profile$quickLinks$en.internal(_root);

	/// en: 'Frequently asked questions'
	String get faqTitle => 'Frequently asked questions';

	List<dynamic> get faq => [
		Translations$profile$faq$0$en.internal(_root),
		Translations$profile$faq$1$en.internal(_root),
		Translations$profile$faq$2$en.internal(_root),
		Translations$profile$faq$3$en.internal(_root),
	];
}

// Path: appInfo
class Translations$appInfo$en {
	Translations$appInfo$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'nts (modified from Saber) Copyright © 2022-$buildYear Adil Hanney This program comes with absolutely no warranty. This is free software, and you are welcome to redistribute it under certain conditions.'
	String licenseNotice({required Object buildYear}) => 'nts (modified from Saber)  Copyright © 2022-${buildYear}  Adil Hanney\nThis program comes with absolutely no warranty. This is free software, and you are welcome to redistribute it under certain conditions.';

	/// en: 'DEBUG'
	String get debug => 'DEBUG';

	/// en: 'Tap here to sponsor me or buy more storage'
	String get sponsorButton => 'Tap here to sponsor me or buy more storage';

	/// en: 'Tap here to view more license information'
	String get licenseButton => 'Tap here to view more license information';

	/// en: 'Tap here to view the privacy policy'
	String get privacyPolicyButton => 'Tap here to view the privacy policy';
}

// Path: update
class Translations$update$en {
	Translations$update$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Update available'
	String get updateAvailable => 'Update available';

	/// en: 'A new version of the app is available:'
	String get updateAvailableDescription => 'A new version of the app is available:';

	/// en: 'Update'
	String get update => 'Update';

	/// en: 'The download isn't available yet for your platform. Please check back shortly.'
	String get downloadNotAvailableYet => 'The download isn\'t available yet for your platform. Please check back shortly.';
}

// Path: editor
class Translations$editor$en {
	Translations$editor$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$editor$toolbar$en toolbar = Translations$editor$toolbar$en.internal(_root);
	late final Translations$editor$pens$en pens = Translations$editor$pens$en.internal(_root);
	late final Translations$editor$penOptions$en penOptions = Translations$editor$penOptions$en.internal(_root);
	late final Translations$editor$eraserOptions$en eraserOptions = Translations$editor$eraserOptions$en.internal(_root);
	late final Translations$editor$colors$en colors = Translations$editor$colors$en.internal(_root);
	late final Translations$editor$imageOptions$en imageOptions = Translations$editor$imageOptions$en.internal(_root);
	late final Translations$editor$selectionBar$en selectionBar = Translations$editor$selectionBar$en.internal(_root);
	late final Translations$editor$menu$en menu = Translations$editor$menu$en.internal(_root);
	late final Translations$editor$readOnlyBanner$en readOnlyBanner = Translations$editor$readOnlyBanner$en.internal(_root);
	late final Translations$editor$versionTooNew$en versionTooNew = Translations$editor$versionTooNew$en.internal(_root);
	late final Translations$editor$quill$en quill = Translations$editor$quill$en.internal(_root);
	late final Translations$editor$hud$en hud = Translations$editor$hud$en.internal(_root);
	late final Translations$editor$customizeToolbar$en customizeToolbar = Translations$editor$customizeToolbar$en.internal(_root);
	late final Translations$editor$floatingBar$en floatingBar = Translations$editor$floatingBar$en.internal(_root);
	late final Translations$editor$otherTools$en otherTools = Translations$editor$otherTools$en.internal(_root);
	late final Translations$editor$canvasTools$en canvasTools = Translations$editor$canvasTools$en.internal(_root);
	late final Translations$editor$mouse$en mouse = Translations$editor$mouse$en.internal(_root);

	/// en: 'Pages'
	String get pages => 'Pages';

	/// en: 'Untitled'
	String get untitled => 'Untitled';

	/// en: 'Saving your changes… You can safely exit the editor when it's done'
	String get needsToSaveBeforeExiting => 'Saving your changes… You can safely exit the editor when it\'s done';
}

// Path: higan
class Translations$higan$en {
	Translations$higan$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Recent'
	String get recent => 'Recent';

	/// en: 'Folders'
	String get folders => 'Folders';

	/// en: 'Whiteboard'
	String get whiteboard => 'Whiteboard';

	/// en: 'Settings'
	String get settings => 'Settings';

	/// en: 'Library'
	String get library => 'Library';

	/// en: 'Gallery'
	String get gallery => 'Gallery';

	/// en: 'List'
	String get list => 'List';

	/// en: 'New note'
	String get newNote => 'New note';

	/// en: '(one) {$n note} (other) {$n notes}'
	String notesCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} note',
		other: '${n} notes',
	);

	/// en: '(one) {$n page} (other) {$n pages}'
	String pagesCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} page',
		other: '${n} pages',
	);

	/// en: '(one) {$n folder} (other) {$n folders}'
	String foldersCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} folder',
		other: '${n} folders',
	);

	/// en: 'Notes'
	String get looseNotes => 'Notes';

	/// en: 'Saved'
	String get saved => 'Saved';

	/// en: 'Saving'
	String get saving => 'Saving';

	/// en: 'page $n / $total'
	String pageOf({required Object n, required Object total}) => 'page ${n} / ${total}';

	/// en: 'Appearance'
	String get appearance => 'Appearance';

	late final Translations$higan$theme$en theme = Translations$higan$theme$en.internal(_root);
	late final Translations$higan$pages$en pages = Translations$higan$pages$en.internal(_root);
	late final Translations$higan$gallerySize$en gallerySize = Translations$higan$gallerySize$en.internal(_root);
	late final Translations$higan$emptyFolder$en emptyFolder = Translations$higan$emptyFolder$en.internal(_root);

	/// en: 'Back'
	String get back => 'Back';

	late final Translations$higan$time$en time = Translations$higan$time$en.internal(_root);
	late final Translations$higan$sync$en sync = Translations$higan$sync$en.internal(_root);
}

// Path: ai
class Translations$ai$en {
	Translations$ai$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Ask AI'
	String get askAi => 'Ask AI';

	/// en: 'Ask about this note'
	String get menuTitle => 'Ask about this note';

	late final Translations$ai$actions$en actions = Translations$ai$actions$en.internal(_root);

	/// en: 'Sign in to an AI account in Settings → AI accounts to use AI.'
	String get signInToUse => 'Sign in to an AI account in Settings → AI accounts to use AI.';

	/// en: 'No AI account yet'
	String get noAccount => 'No AI account yet';

	/// en: 'An AI account has a problem'
	String get accountProblem => 'An AI account has a problem';

	/// en: 'Open Settings'
	String get openSettings => 'Open Settings';

	/// en: 'Nothing I can read here.'
	String get nothingToRead => 'Nothing I can read here.';

	/// en: 'Your note'
	String get yourNote => 'Your note';

	/// en: 'You wrote'
	String get youWrote => 'You wrote';

	/// en: 'Type what you wrote'
	String get typeReading => 'Type what you wrote';

	/// en: 'Fix what it read'
	String get editReading => 'Fix what it read';

	/// en: 'Ask again'
	String get askAgain => 'Ask again';

	/// en: 'Re-reading…'
	String get rereading => 'Re-reading…';

	/// en: 'Thinking…'
	String get working => 'Thinking…';

	/// en: 'Drawing…'
	String get drawing => 'Drawing…';

	/// en: 'Searching…'
	String get searching => 'Searching…';

	/// en: 'Made by $provider · $model. It can be wrong.'
	String madeBy({required Object provider, required Object model}) => 'Made by ${provider} · ${model}. It can be wrong.';

	/// en: 'Found by $provider · $model'
	String foundBy({required Object provider, required Object model}) => 'Found by ${provider} · ${model}';

	/// en: 'Suggested by $provider · $model'
	String suggestedBy({required Object provider, required Object model}) => 'Suggested by ${provider} · ${model}';

	/// en: 'Copy'
	String get copy => 'Copy';

	/// en: 'Copied'
	String get copied => 'Copied';

	/// en: 'Add to page'
	String get addToPage => 'Add to page';

	/// en: 'Close'
	String get close => 'Close';

	/// en: 'Try again'
	String get tryAgain => 'Try again';

	/// en: 'Nothing to graph here.'
	String get nothingToGraph => 'Nothing to graph here.';

	/// en: 'Couldn't graph this.'
	String get couldNotGraph => 'Couldn\'t graph this.';

	/// en: 'Couldn't draw this. Try again.'
	String get couldNotDraw => 'Couldn\'t draw this. Try again.';

	/// en: 'Something went wrong.'
	String get failed => 'Something went wrong.';

	late final Translations$ai$route$en route = Translations$ai$route$en.internal(_root);
	late final Translations$ai$web$en web = Translations$ai$web$en.internal(_root);
	late final Translations$ai$accounts$en accounts = Translations$ai$accounts$en.internal(_root);
	late final Translations$ai$google$en google = Translations$ai$google$en.internal(_root);
	late final Translations$ai$actionsSettings$en actionsSettings = Translations$ai$actionsSettings$en.internal(_root);
}

// Path: home.titles
class Translations$home$titles$en {
	Translations$home$titles$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Recent notes'
	String get home => 'Recent notes';

	/// en: 'Browse'
	String get browse => 'Browse';

	/// en: 'Whiteboard'
	String get whiteboard => 'Whiteboard';

	/// en: 'Settings'
	String get settings => 'Settings';
}

// Path: home.tooltips
class Translations$home$tooltips$en {
	Translations$home$tooltips$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'New note'
	String get newNote => 'New note';

	/// en: 'Show update dialog'
	String get showUpdateDialog => 'Show update dialog';

	/// en: 'Export note'
	String get exportNote => 'Export note';
}

// Path: home.create
class Translations$home$create$en {
	Translations$home$create$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'New note'
	String get newNote => 'New note';

	/// en: 'Import note'
	String get importNote => 'Import note';
}

// Path: home.newFolder
class Translations$home$newFolder$en {
	Translations$home$newFolder$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'New folder'
	String get newFolder => 'New folder';

	/// en: 'Folder name'
	String get folderName => 'Folder name';

	/// en: 'Create'
	String get create => 'Create';

	/// en: 'Folder name can't be empty'
	String get folderNameEmpty => 'Folder name can\'t be empty';

	/// en: 'Folder name can't contain a slash'
	String get folderNameContainsSlash => 'Folder name can\'t contain a slash';

	/// en: 'Folder already exists'
	String get folderNameExists => 'Folder already exists';
}

// Path: home.renameNote
class Translations$home$renameNote$en {
	Translations$home$renameNote$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Rename note'
	String get renameNote => 'Rename note';

	/// en: 'Note name'
	String get noteName => 'Note name';

	/// en: 'Rename'
	String get rename => 'Rename';

	/// en: 'Note name can't be empty'
	String get noteNameEmpty => 'Note name can\'t be empty';

	/// en: 'A note with this name already exists'
	String get noteNameExists => 'A note with this name already exists';

	/// en: 'Note name contains forbidden characters'
	String get noteNameForbiddenCharacters => 'Note name contains forbidden characters';

	/// en: 'Note name reserved'
	String get noteNameReserved => 'Note name reserved';
}

// Path: home.moveNote
class Translations$home$moveNote$en {
	Translations$home$moveNote$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Move note'
	String get moveNote => 'Move note';

	/// en: 'Move $n notes'
	String moveNotes({required Object n}) => 'Move ${n} notes';

	/// en: 'Move $f'
	String moveName({required Object f}) => 'Move ${f}';

	/// en: 'Move'
	String get move => 'Move';

	/// en: 'Note will be renamed to $newName'
	String renamedTo({required Object newName}) => 'Note will be renamed to ${newName}';

	/// en: 'The following notes will be renamed:'
	String get multipleRenamedTo => 'The following notes will be renamed:';

	/// en: '$n notes will be renamed to avoid conflicts'
	String numberRenamedTo({required Object n}) => '${n} notes will be renamed to avoid conflicts';
}

// Path: home.deleteNoteDialog
class Translations$home$deleteNoteDialog$en {
	Translations$home$deleteNoteDialog$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Delete $n notes'
	String deleteNotes({required Object n}) => 'Delete ${n} notes';

	/// en: 'Delete $f'
	String deleteName({required Object f}) => 'Delete ${f}';

	/// en: '(one) {Permanently delete the selected note?} (other) {Permanently delete the selected notes?}'
	String confirmDelete({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Permanently delete the selected note?',
		other: 'Permanently delete the selected notes?',
	);

	/// en: 'Delete'
	String get delete => 'Delete';
}

// Path: home.renameFolder
class Translations$home$renameFolder$en {
	Translations$home$renameFolder$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Rename folder'
	String get renameFolder => 'Rename folder';

	/// en: 'Folder name'
	String get folderName => 'Folder name';

	/// en: 'Rename'
	String get rename => 'Rename';

	/// en: 'Folder name can't be empty'
	String get folderNameEmpty => 'Folder name can\'t be empty';

	/// en: 'Folder name can't contain a slash'
	String get folderNameContainsSlash => 'Folder name can\'t contain a slash';

	/// en: 'A folder with this name already exists'
	String get folderNameExists => 'A folder with this name already exists';
}

// Path: home.deleteFolder
class Translations$home$deleteFolder$en {
	Translations$home$deleteFolder$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Delete folder'
	String get deleteFolder => 'Delete folder';

	/// en: 'Delete $f'
	String deleteName({required Object f}) => 'Delete ${f}';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Also delete all notes inside this folder'
	String get alsoDeleteContents => 'Also delete all notes inside this folder';
}

// Path: home.sort
class Translations$home$sort$en {
	Translations$home$sort$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Sort by'
	String get sortBy => 'Sort by';

	/// en: 'Name (A-Z)'
	String get nameAToZ => 'Name (A-Z)';

	/// en: 'Name (Z-A)'
	String get nameZToA => 'Name (Z-A)';

	/// en: 'Edited (Newest first)'
	String get lastModifiedNewToOld => 'Edited (Newest first)';

	/// en: 'Edited (Oldest first)'
	String get lastModifiedOldToNew => 'Edited (Oldest first)';
}

// Path: home.menu
class Translations$home$menu$en {
	Translations$home$menu$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Open'
	String get open => 'Open';

	/// en: 'Select'
	String get select => 'Select';

	/// en: 'Deselect'
	String get deselect => 'Deselect';

	/// en: 'Export as PDF'
	String get exportPdf => 'Export as PDF';

	/// en: 'Export as SBA'
	String get exportSba => 'Export as SBA';
}

// Path: sentry.consent
class Translations$sentry$consent$en {
	Translations$sentry$consent$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Help improve nts?'
	String get title => 'Help improve nts?';

	late final Translations$sentry$consent$description$en description = Translations$sentry$consent$description$en.internal(_root);
	late final Translations$sentry$consent$answers$en answers = Translations$sentry$consent$answers$en.internal(_root);
}

// Path: settings.prefCategories
class Translations$settings$prefCategories$en {
	Translations$settings$prefCategories$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'General'
	String get general => 'General';

	/// en: 'Writing'
	String get writing => 'Writing';

	/// en: 'Editor'
	String get editor => 'Editor';

	/// en: 'Performance'
	String get performance => 'Performance';

	/// en: 'Advanced'
	String get advanced => 'Advanced';
}

// Path: settings.prefLabels
class Translations$settings$prefLabels$en {
	Translations$settings$prefLabels$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Language'
	String get locale => 'Language';

	/// en: 'App theme'
	String get appTheme => 'App theme';

	/// en: 'Theme type'
	String get platform => 'Theme type';

	/// en: 'Layout type'
	String get layoutSize => 'Layout type';

	/// en: 'Custom accent color'
	String get customAccentColor => 'Custom accent color';

	/// en: 'Atkinson Hyperlegible font'
	String get hyperlegibleFont => 'Atkinson Hyperlegible font';

	/// en: 'Check for nts updates'
	String get shouldCheckForUpdates => 'Check for nts updates';

	/// en: 'Faster updates'
	String get shouldAlwaysAlertForUpdates => 'Faster updates';

	/// en: 'Allow insecure connections'
	String get allowInsecureConnections => 'Allow insecure connections';

	/// en: 'Toolbar position'
	String get editorToolbarAlignment => 'Toolbar position';

	/// en: 'Show the toolbar in fullscreen mode'
	String get editorToolbarShowInFullscreen => 'Show the toolbar in fullscreen mode';

	/// en: 'Invert notes in dark mode'
	String get editorAutoInvert => 'Invert notes in dark mode';

	/// en: 'Prefer greyscale colors'
	String get preferGreyscale => 'Prefer greyscale colors';

	/// en: 'Maximum image size'
	String get maxImageSize => 'Maximum image size';

	/// en: 'Auto-clear the whiteboard'
	String get autoClearWhiteboardOnExit => 'Auto-clear the whiteboard';

	/// en: 'Auto-disable the eraser'
	String get disableEraserAfterUse => 'Auto-disable the eraser';

	/// en: 'Hide the finger drawing toggle'
	String get hideFingerDrawingToggle => 'Hide the finger drawing toggle';

	/// en: 'Auto-disable finger drawing'
	String get autoDisableFingerDrawingWhenStylusDetected => 'Auto-disable finger drawing';

	/// en: 'Prompt you to rename new notes'
	String get editorPromptRename => 'Prompt you to rename new notes';

	/// en: 'Don't save preset colors in recent colors'
	String get recentColorsDontSavePresets => 'Don\'t save preset colors in recent colors';

	/// en: 'How many recent colors to store'
	String get recentColorsLength => 'How many recent colors to store';

	/// en: 'Print page indicators'
	String get printPageIndicators => 'Print page indicators';

	/// en: 'Auto-save'
	String get autosave => 'Auto-save';

	/// en: 'Shape recognition delay'
	String get shapeRecognitionDelay => 'Shape recognition delay';

	/// en: 'Auto straighten lines'
	String get autoStraightenLines => 'Auto straighten lines';

	/// en: 'Custom nts folder'
	String get customDataDir => 'Custom nts folder';

	/// en: 'Error reporting'
	String get sentry => 'Error reporting';
}

// Path: settings.prefDescriptions
class Translations$settings$prefDescriptions$en {
	Translations$settings$prefDescriptions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Increases legibility for users with low vision'
	String get hyperlegibleFont => 'Increases legibility for users with low vision';

	/// en: '(Not recommended) Allow nts to connect to servers with self-signed/untrusted certificates'
	String get allowInsecureConnections => '(Not recommended) Allow nts to connect to servers with self-signed/untrusted certificates';

	/// en: 'For e-ink displays'
	String get preferGreyscale => 'For e-ink displays';

	/// en: 'Clears the whiteboard after you exit the app'
	String get autoClearWhiteboardOnExit => 'Clears the whiteboard after you exit the app';

	/// en: 'Automatically switches back to the pen after using the eraser'
	String get disableEraserAfterUse => 'Automatically switches back to the pen after using the eraser';

	/// en: 'Pause at the end of a stroke to turn it into a line, circle or other shape'
	String get holdToSnapShape => 'Pause at the end of a stroke to turn it into a line, circle or other shape';

	/// en: 'Scribble over ink with a pen to erase it'
	String get scribbleToErase => 'Scribble over ink with a pen to erase it';

	/// en: 'Larger images will be compressed'
	String get maxImageSize => 'Larger images will be compressed';

	late final Translations$settings$prefDescriptions$hideFingerDrawing$en hideFingerDrawing = Translations$settings$prefDescriptions$hideFingerDrawing$en.internal(_root);

	/// en: 'Turn off finger drawing when a stylus is detected'
	String get autoDisableFingerDrawingWhenStylusDetected => 'Turn off finger drawing when a stylus is detected';

	/// en: 'You can always rename notes later'
	String get editorPromptRename => 'You can always rename notes later';

	/// en: 'Show page indicators in exports'
	String get printPageIndicators => 'Show page indicators in exports';

	/// en: 'Auto-save after a short delay, or never'
	String get autosave => 'Auto-save after a short delay, or never';

	/// en: 'How often to update the shape preview'
	String get shapeRecognitionDelay => 'How often to update the shape preview';

	/// en: 'Straightens long lines without having to use the shape pen'
	String get autoStraightenLines => 'Straightens long lines without having to use the shape pen';

	/// en: 'Tell me about updates as soon as they're available'
	String get shouldAlwaysAlertForUpdates => 'Tell me about updates as soon as they\'re available';

	late final Translations$settings$prefDescriptions$sentry$en sentry = Translations$settings$prefDescriptions$sentry$en.internal(_root);
}

// Path: settings.themeModes
class Translations$settings$themeModes$en {
	Translations$settings$themeModes$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'System'
	String get system => 'System';

	/// en: 'Light'
	String get light => 'Light';

	/// en: 'Dark'
	String get dark => 'Dark';
}

// Path: settings.layoutSizes
class Translations$settings$layoutSizes$en {
	Translations$settings$layoutSizes$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Auto'
	String get auto => 'Auto';

	/// en: 'Phone'
	String get phone => 'Phone';

	/// en: 'Tablet'
	String get tablet => 'Tablet';
}

// Path: settings.accentColorPicker
class Translations$settings$accentColorPicker$en {
	Translations$settings$accentColorPicker$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Pick a color'
	String get pickAColor => 'Pick a color';
}

// Path: settings.reset
class Translations$settings$reset$en {
	Translations$settings$reset$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Reset this setting?'
	String get title => 'Reset this setting?';

	/// en: 'Reset'
	String get button => 'Reset';
}

// Path: settings.customDataDir
class Translations$settings$customDataDir$en {
	Translations$settings$customDataDir$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Select'
	String get select => 'Select';

	/// en: 'Selected folder must be empty'
	String get mustBeEmpty => 'Selected folder must be empty';

	/// en: 'Make sure syncing is complete before changing the folder'
	String get mustBeDoneSyncing => 'Make sure syncing is complete before changing the folder';

	/// en: 'This feature is currently only for developers. Using it will likely result in data loss.'
	String get unsupported => 'This feature is currently only for developers. Using it will likely result in data loss.';
}

// Path: login.form
class Translations$login$form$en {
	Translations$login$form$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'By logging in, you agree to the ${linkToPrivacyPolicy(Privacy Policy)}.'
	TextSpan agreeToPrivacyPolicy({required InlineSpanBuilder linkToPrivacyPolicy}) => TextSpan(children: [
		const TextSpan(text: 'By logging in, you agree to the '),
		linkToPrivacyPolicy('Privacy Policy'),
		const TextSpan(text: '.'),
	]);
}

// Path: login.status
class Translations$login$status$en {
	Translations$login$status$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Logged out'
	String get loggedOut => 'Logged out';

	/// en: 'Tap to log in with Nextcloud'
	String get tapToLogin => 'Tap to log in with Nextcloud';

	/// en: 'Hi, $u!'
	String hi({required Object u}) => 'Hi, ${u}!';

	/// en: 'Almost ready for syncing, tap to finish logging in'
	String get almostDone => 'Almost ready for syncing, tap to finish logging in';

	/// en: 'Logged in with Nextcloud'
	String get loggedIn => 'Logged in with Nextcloud';
}

// Path: login.ncLoginStep
class Translations$login$ncLoginStep$en {
	Translations$login$ncLoginStep$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Choose where you want to store your data:'
	String get whereToStoreData => 'Choose where you want to store your data:';

	/// en: 'nts's Nextcloud server'
	String get saberNcServer => 'nts\'s Nextcloud server';

	/// en: 'Other Nextcloud server'
	String get otherNcServer => 'Other Nextcloud server';

	/// en: 'Server URL'
	String get serverUrl => 'Server URL';

	/// en: 'Login with nts'
	String get loginWithSaber => 'Login with nts';

	/// en: 'Login with Nextcloud'
	String get loginWithNextcloud => 'Login with Nextcloud';

	late final Translations$login$ncLoginStep$loginFlow$en loginFlow = Translations$login$ncLoginStep$loginFlow$en.internal(_root);
}

// Path: login.encLoginStep
class Translations$login$encLoginStep$en {
	Translations$login$encLoginStep$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'To protect your data, please enter your encryption password:'
	String get enterEncPassword => 'To protect your data, please enter your encryption password:';

	/// en: 'New to nts? Just enter a new encryption password.'
	String get newToSaber => 'New to nts? Just enter a new encryption password.';

	/// en: 'Encryption password'
	String get encPassword => 'Encryption password';

	/// en: 'Frequently asked questions'
	String get encFaqTitle => 'Frequently asked questions';

	/// en: 'Decryption failed with the provided password. Please try entering it again.'
	String get wrongEncPassword => 'Decryption failed with the provided password. Please try entering it again.';

	/// en: 'Something went wrong connecting to the server. Please try again later.'
	String get connectionFailed => 'Something went wrong connecting to the server. Please try again later.';

	List<dynamic> get encFaq => [
		Translations$login$encLoginStep$encFaq$0$en.internal(_root),
		Translations$login$encLoginStep$encFaq$1$en.internal(_root),
		Translations$login$encLoginStep$encFaq$2$en.internal(_root),
	];
}

// Path: profile.quickLinks
class Translations$profile$quickLinks$en {
	Translations$profile$quickLinks$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Server homepage'
	String get serverHomepage => 'Server homepage';

	/// en: 'Delete account'
	String get deleteAccount => 'Delete account';
}

// Path: profile.faq.0
class Translations$profile$faq$0$en {
	Translations$profile$faq$0$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Will I lose my notes if I log out?'
	String get q => 'Will I lose my notes if I log out?';

	/// en: 'No. Your notes will remain both on your device and on the server. They won't be synced with the server until you log back in. Make sure syncing is complete before logging out so you don't lose any data (see the sync progress on the home screen).'
	String get a => 'No. Your notes will remain both on your device and on the server. They won\'t be synced with the server until you log back in. Make sure syncing is complete before logging out so you don\'t lose any data (see the sync progress on the home screen).';
}

// Path: profile.faq.1
class Translations$profile$faq$1$en {
	Translations$profile$faq$1$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'How do I change my Nextcloud password?'
	String get q => 'How do I change my Nextcloud password?';

	/// en: 'Go to your server website and log in. Then go to Settings > Security > Change password. You'll need to log out and log back in to nts after changing your password.'
	String get a => 'Go to your server website and log in. Then go to Settings > Security > Change password. You\'ll need to log out and log back in to nts after changing your password.';
}

// Path: profile.faq.2
class Translations$profile$faq$2$en {
	Translations$profile$faq$2$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'How do I change my encryption password?'
	String get q => 'How do I change my encryption password?';

	/// en: '0. Make sure syncing is complete (see the sync progress on the home screen). 1. Log out of nts. 2. Go to your server website and delete your 'Saber' folder. This will delete all your notes from the server. 3. Log back in to nts. You can choose a new encryption password when logging in. 4. Don't forget to log out and log back in to nts on your other devices too.'
	String get a => '0. Make sure syncing is complete (see the sync progress on the home screen).\n1. Log out of nts.\n2. Go to your server website and delete your \'Saber\' folder. This will delete all your notes from the server.\n3. Log back in to nts. You can choose a new encryption password when logging in.\n4. Don\'t forget to log out and log back in to nts on your other devices too.';
}

// Path: profile.faq.3
class Translations$profile$faq$3$en {
	Translations$profile$faq$3$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'How can I delete my account?'
	String get q => 'How can I delete my account?';

	/// en: 'Tap on the "Delete account" button above, and login if needed. If you are using the official nts server, your account will be deleted after a 1 week grace period. You can contact me at adilhanney@disroot.org during this period to cancel the deletion. If you are using a third party server, there might not be an option to delete your account: you'll need to consult the server's privacy policy for more information.'
	String get a => 'Tap on the "${_root.profile.quickLinks.deleteAccount}" button above, and login if needed.\nIf you are using the official nts server, your account will be deleted after a 1 week grace period. You can contact me at adilhanney@disroot.org during this period to cancel the deletion.\nIf you are using a third party server, there might not be an option to delete your account: you\'ll need to consult the server\'s privacy policy for more information.';
}

// Path: editor.toolbar
class Translations$editor$toolbar$en {
	Translations$editor$toolbar$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Toggle colors (Ctrl C)'
	String get toggleColors => 'Toggle colors (Ctrl C)';

	/// en: 'Select'
	String get select => 'Select';

	/// en: 'Toggle eraser (Ctrl E)'
	String get toggleEraser => 'Toggle eraser (Ctrl E)';

	/// en: 'Images'
	String get photo => 'Images';

	/// en: 'Text'
	String get text => 'Text';

	/// en: 'Toggle finger drawing (Ctrl F)'
	String get toggleFingerDrawing => 'Toggle finger drawing (Ctrl F)';

	/// en: 'Undo'
	String get undo => 'Undo';

	/// en: 'Redo'
	String get redo => 'Redo';

	/// en: 'Export (Ctrl Shift S)'
	String get export => 'Export (Ctrl Shift S)';

	/// en: 'Export as:'
	String get exportAs => 'Export as:';

	/// en: 'Toggle fullscreen (F11)'
	String get fullscreen => 'Toggle fullscreen (F11)';
}

// Path: editor.pens
class Translations$editor$pens$en {
	Translations$editor$pens$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Fountain pen'
	String get fountainPen => 'Fountain pen';

	/// en: 'Ballpoint pen'
	String get ballpointPen => 'Ballpoint pen';

	/// en: 'Highlighter'
	String get highlighter => 'Highlighter';

	/// en: 'Pencil'
	String get pencil => 'Pencil';

	/// en: 'Shape pen'
	String get shapePen => 'Shape pen';

	/// en: 'Laser pointer'
	String get laserPointer => 'Laser pointer';
}

// Path: editor.penOptions
class Translations$editor$penOptions$en {
	Translations$editor$penOptions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Size'
	String get size => 'Size';
}

// Path: editor.eraserOptions
class Translations$editor$eraserOptions$en {
	Translations$editor$eraserOptions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Whole line'
	String get wholeLine => 'Whole line';

	/// en: 'Partial'
	String get partial => 'Partial';

	/// en: 'Eraser size'
	String get size => 'Eraser size';
}

// Path: editor.colors
class Translations$editor$colors$en {
	Translations$editor$colors$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Color picker'
	String get colorPicker => 'Color picker';

	/// en: 'Custom $b $h'
	String customBrightnessHue({required Object b, required Object h}) => 'Custom ${b} ${h}';

	/// en: 'Custom $h'
	String customHue({required Object h}) => 'Custom ${h}';

	/// en: 'dark'
	String get dark => 'dark';

	/// en: 'light'
	String get light => 'light';

	/// en: 'Black'
	String get black => 'Black';

	/// en: 'Dark grey'
	String get darkGrey => 'Dark grey';

	/// en: 'Grey'
	String get grey => 'Grey';

	/// en: 'Light grey'
	String get lightGrey => 'Light grey';

	/// en: 'White'
	String get white => 'White';

	/// en: 'Red'
	String get red => 'Red';

	/// en: 'Green'
	String get green => 'Green';

	/// en: 'Cyan'
	String get cyan => 'Cyan';

	/// en: 'Blue'
	String get blue => 'Blue';

	/// en: 'Yellow'
	String get yellow => 'Yellow';

	/// en: 'Purple'
	String get purple => 'Purple';

	/// en: 'Pink'
	String get pink => 'Pink';

	/// en: 'Orange'
	String get orange => 'Orange';

	/// en: 'Pastel red'
	String get pastelRed => 'Pastel red';

	/// en: 'Pastel orange'
	String get pastelOrange => 'Pastel orange';

	/// en: 'Pastel yellow'
	String get pastelYellow => 'Pastel yellow';

	/// en: 'Pastel green'
	String get pastelGreen => 'Pastel green';

	/// en: 'Pastel cyan'
	String get pastelCyan => 'Pastel cyan';

	/// en: 'Pastel blue'
	String get pastelBlue => 'Pastel blue';

	/// en: 'Pastel purple'
	String get pastelPurple => 'Pastel purple';

	/// en: 'Pastel pink'
	String get pastelPink => 'Pastel pink';
}

// Path: editor.imageOptions
class Translations$editor$imageOptions$en {
	Translations$editor$imageOptions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Image options'
	String get title => 'Image options';

	/// en: 'Invertible'
	String get invertible => 'Invertible';

	/// en: 'Download'
	String get download => 'Download';

	/// en: 'Set as background'
	String get setAsBackground => 'Set as background';

	/// en: 'Remove as background'
	String get removeAsBackground => 'Remove as background';

	/// en: 'Delete'
	String get delete => 'Delete';
}

// Path: editor.selectionBar
class Translations$editor$selectionBar$en {
	Translations$editor$selectionBar$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Duplicate'
	String get duplicate => 'Duplicate';
}

// Path: editor.menu
class Translations$editor$menu$en {
	Translations$editor$menu$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Clear page $page/$totalPages'
	String clearPage({required Object page, required Object totalPages}) => 'Clear page ${page}/${totalPages}';

	/// en: 'Clear all pages'
	String get clearAllPages => 'Clear all pages';

	/// en: 'Insert page below'
	String get insertPage => 'Insert page below';

	/// en: 'Duplicate page'
	String get duplicatePage => 'Duplicate page';

	/// en: 'Delete page'
	String get deletePage => 'Delete page';

	/// en: 'Line height'
	String get lineHeight => 'Line height';

	/// en: 'Also controls the text size for typed notes'
	String get lineHeightDescription => 'Also controls the text size for typed notes';

	/// en: 'Line thickness'
	String get lineThickness => 'Line thickness';

	/// en: 'Background line thickness'
	String get lineThicknessDescription => 'Background line thickness';

	/// en: 'Background image fit'
	String get backgroundImageFit => 'Background image fit';

	/// en: 'Background pattern'
	String get backgroundPattern => 'Background pattern';

	/// en: 'Import'
	String get import => 'Import';

	/// en: 'Watch for updates on the server'
	String get watchServer => 'Watch for updates on the server';

	/// en: 'Editing is disabled while watching the server'
	String get watchServerReadOnly => 'Editing is disabled while watching the server';

	late final Translations$editor$menu$boxFits$en boxFits = Translations$editor$menu$boxFits$en.internal(_root);
	late final Translations$editor$menu$bgPatterns$en bgPatterns = Translations$editor$menu$bgPatterns$en.internal(_root);
}

// Path: editor.readOnlyBanner
class Translations$editor$readOnlyBanner$en {
	Translations$editor$readOnlyBanner$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Read-only mode'
	String get title => 'Read-only mode';

	/// en: 'You are currently watching for updates on the server. Editing is disabled in this mode.'
	String get watchingServer => 'You are currently watching for updates on the server. Editing is disabled in this mode.';

	/// en: 'Failed to load note. It may be corrupted or still being downloaded.'
	String get corrupted => 'Failed to load note. It may be corrupted or still being downloaded.';
}

// Path: editor.versionTooNew
class Translations$editor$versionTooNew$en {
	Translations$editor$versionTooNew$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'This note was edited using a newer version of nts'
	String get title => 'This note was edited using a newer version of nts';

	/// en: 'Editing this note may result in some information being lost. Do you want to ignore this and edit it anyway?'
	String get subtitle => 'Editing this note may result in some information being lost. Do you want to ignore this and edit it anyway?';

	/// en: 'Allow editing'
	String get allowEditing => 'Allow editing';
}

// Path: editor.quill
class Translations$editor$quill$en {
	Translations$editor$quill$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Type something here…'
	String get typeSomething => 'Type something here…';
}

// Path: editor.hud
class Translations$editor$hud$en {
	Translations$editor$hud$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Unlock zoom'
	String get unlockZoom => 'Unlock zoom';

	/// en: 'Lock zoom'
	String get lockZoom => 'Lock zoom';

	/// en: 'Enable single-finger panning'
	String get unlockSingleFingerPan => 'Enable single-finger panning';

	/// en: 'Disable single-finger panning'
	String get lockSingleFingerPan => 'Disable single-finger panning';

	/// en: 'Unlock panning to horizontal or vertical'
	String get unlockAxisAlignedPan => 'Unlock panning to horizontal or vertical';

	/// en: 'Lock panning to horizontal or vertical'
	String get lockAxisAlignedPan => 'Lock panning to horizontal or vertical';
}

// Path: editor.customizeToolbar
class Translations$editor$customizeToolbar$en {
	Translations$editor$customizeToolbar$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Customize toolbar'
	String get customize => 'Customize toolbar';

	/// en: 'Toolbar'
	String get title => 'Toolbar';

	/// en: 'In the toolbar'
	String get inToolbar => 'In the toolbar';

	/// en: 'Drag to reorder'
	String get reorder => 'Drag to reorder';

	/// en: 'Reset to basics'
	String get resetToBasics => 'Reset to basics';

	/// en: 'Switch a button on to add it to the toolbar.'
	String get hint => 'Switch a button on to add it to the toolbar.';

	/// en: 'Remove from toolbar'
	String get removeFromToolbar => 'Remove from toolbar';

	late final Translations$editor$customizeToolbar$categories$en categories = Translations$editor$customizeToolbar$categories$en.internal(_root);
	late final Translations$editor$customizeToolbar$tools$en tools = Translations$editor$customizeToolbar$tools$en.internal(_root);
}

// Path: editor.floatingBar
class Translations$editor$floatingBar$en {
	Translations$editor$floatingBar$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Drag to move, double-tap to reset'
	String get move => 'Drag to move, double-tap to reset';

	/// en: 'Minimize'
	String get minimize => 'Minimize';

	/// en: 'Restore'
	String get restore => 'Restore';

	/// en: 'Reset position'
	String get resetPosition => 'Reset position';
}

// Path: editor.otherTools
class Translations$editor$otherTools$en {
	Translations$editor$otherTools$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Copy'
	String get copy => 'Copy';

	/// en: 'Cut'
	String get cut => 'Cut';

	/// en: 'Paste'
	String get paste => 'Paste';

	/// en: 'Screenshot selection'
	String get screenshot => 'Screenshot selection';

	/// en: 'Copy image'
	String get copyImage => 'Copy image';

	/// en: 'Save image'
	String get saveImage => 'Save image';

	/// en: 'Image copied'
	String get imageCopied => 'Image copied';

	/// en: 'Handwriting to text'
	String get handwriting => 'Handwriting to text';

	/// en: 'Copy as text'
	String get copyAsText => 'Copy as text';

	/// en: 'Convert to text'
	String get convertToText => 'Convert to text';

	/// en: 'Copied “$text”'
	String textCopied({required Object text}) => 'Copied “${text}”';

	/// en: 'No handwriting found'
	String get noHandwriting => 'No handwriting found';

	/// en: 'Couldn't open the camera. Allow nts to use it in Settings.'
	String get cameraFailed => 'Couldn\'t open the camera. Allow nts to use it in Settings.';

	/// en: 'Couldn't read the handwriting'
	String get handwritingFailed => 'Couldn\'t read the handwriting';

	/// en: 'Pen favorites'
	String get penFavorites => 'Pen favorites';

	/// en: 'Save pen as favorite'
	String get saveFavorite => 'Save pen as favorite';

	/// en: 'Remove favorite'
	String get removeFavorite => 'Remove favorite';

	/// en: 'Camera'
	String get camera => 'Camera';
}

// Path: editor.canvasTools
class Translations$editor$canvasTools$en {
	Translations$editor$canvasTools$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Tape'
	String get tape => 'Tape';

	/// en: 'Fill'
	String get fill => 'Fill';

	/// en: 'Brush pen'
	String get brushPen => 'Brush pen';

	/// en: 'Calligraphy pen'
	String get calligraphyPen => 'Calligraphy pen';

	/// en: 'Nib angle $angle°'
	String nibAngle({required Object angle}) => 'Nib angle ${angle}°';

	/// en: 'Hold to snap shapes'
	String get holdToSnapShape => 'Hold to snap shapes';

	/// en: 'Scribble to erase'
	String get scribbleToErase => 'Scribble to erase';

	/// en: 'Insert space'
	String get insertSpace => 'Insert space';

	/// en: 'Ruler'
	String get ruler => 'Ruler';

	/// en: 'Freehand'
	String get lassoFreehand => 'Freehand';

	/// en: 'Rectangle'
	String get lassoRectangle => 'Rectangle';

	/// en: 'Add link'
	String get addLink => 'Add link';

	/// en: 'Edit link'
	String get editLink => 'Edit link';

	/// en: 'example.com, name@example.com or'
	String get linkHint => 'example.com, name@example.com or';

	/// en: 'Enter a web address, an email address, or'
	String get invalidLink => 'Enter a web address, an email address, or';

	/// en: 'Remove link'
	String get removeLink => 'Remove link';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Couldn't open $url'
	String couldNotOpenLink({required Object url}) => 'Couldn\'t open ${url}';
}

// Path: editor.mouse
class Translations$editor$mouse$en {
	Translations$editor$mouse$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Select all on this page'
	String get selectAll => 'Select all on this page';
}

// Path: higan.theme
class Translations$higan$theme$en {
	Translations$higan$theme$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Theme'
	String get label => 'Theme';

	/// en: 'Night'
	String get night => 'Night';

	/// en: 'Paper'
	String get paper => 'Paper';

	/// en: 'System'
	String get system => 'System';
}

// Path: higan.pages
class Translations$higan$pages$en {
	Translations$higan$pages$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Pages'
	String get label => 'Pages';

	/// en: 'Paper'
	String get paper => 'Paper';

	/// en: 'Black'
	String get black => 'Black';

	/// en: 'Black turns pages dark and adjusts your ink so it stays readable'
	String get description => 'Black turns pages dark and adjusts your ink so it stays readable';
}

// Path: higan.gallerySize
class Translations$higan$gallerySize$en {
	Translations$higan$gallerySize$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Gallery size'
	String get label => 'Gallery size';

	/// en: 'How big notes and folders are in Recent and Folders'
	String get description => 'How big notes and folders are in Recent and Folders';

	/// en: 'XS'
	String get xs => 'XS';

	/// en: 'S'
	String get s => 'S';

	/// en: 'M'
	String get m => 'M';

	/// en: 'L'
	String get l => 'L';

	/// en: 'XL'
	String get xl => 'XL';
}

// Path: higan.emptyFolder
class Translations$higan$emptyFolder$en {
	Translations$higan$emptyFolder$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'This folder is empty'
	String get title => 'This folder is empty';

	/// en: 'Add a note or a folder to begin.'
	String get body => 'Add a note or a folder to begin.';
}

// Path: higan.time
class Translations$higan$time$en {
	Translations$higan$time$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Just now'
	String get justNow => 'Just now';

	/// en: '${n}m ago'
	String minutesAgo({required Object n}) => '${n}m ago';

	/// en: '${n}h ago'
	String hoursAgo({required Object n}) => '${n}h ago';

	/// en: 'Yesterday'
	String get yesterday => 'Yesterday';
}

// Path: higan.sync
class Translations$higan$sync$en {
	Translations$higan$sync$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'iCloud · synced'
	String get synced => 'iCloud · synced';

	/// en: 'On this device'
	String get localOnly => 'On this device';

	/// en: 'iCloud · reconnect'
	String get reconnect => 'iCloud · reconnect';
}

// Path: ai.actions
class Translations$ai$actions$en {
	Translations$ai$actions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$ai$actions$explainExample$en explainExample = Translations$ai$actions$explainExample$en.internal(_root);
	late final Translations$ai$actions$paragraph$en paragraph = Translations$ai$actions$paragraph$en.internal(_root);
	late final Translations$ai$actions$graph$en graph = Translations$ai$actions$graph$en.internal(_root);
	late final Translations$ai$actions$illustration$en illustration = Translations$ai$actions$illustration$en.internal(_root);
	late final Translations$ai$actions$video$en video = Translations$ai$actions$video$en.internal(_root);
	late final Translations$ai$actions$source$en source = Translations$ai$actions$source$en.internal(_root);
}

// Path: ai.route
class Translations$ai$route$en {
	Translations$ai$route$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '$provider is signed out.'
	String signedOut({required Object provider}) => '${provider} is signed out.';

	/// en: '$provider isn't available here.'
	String unavailable({required Object provider}) => '${provider} isn\'t available here.';

	/// en: 'This account isn't available.'
	String get noAccount => 'This account isn\'t available.';

	/// en: '$provider has no model for this.'
	String noModel({required Object provider}) => '${provider} has no model for this.';
}

// Path: ai.web
class Translations$ai$web$en {
	Translations$ai$web$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Search'
	String get search => 'Search';

	/// en: 'Search for'
	String get query => 'Search for';

	/// en: 'Open'
	String get open => 'Open';

	/// en: 'Nothing found. Try other words.'
	String get noResults => 'Nothing found. Try other words.';

	/// en: 'Links open in your browser.'
	String get opensOutside => 'Links open in your browser.';

	/// en: 'Found with YouTube search'
	String get foundWithYouTube => 'Found with YouTube search';

	/// en: 'From memory, not a web search, so some links may not exist.'
	String get fromMemory => 'From memory, not a web search, so some links may not exist.';
}

// Path: ai.accounts
class Translations$ai$accounts$en {
	Translations$ai$accounts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'AI accounts'
	String get title => 'AI accounts';

	/// en: 'The circled part of a page goes to the account an action uses, only when you pick that action. nts never sees your passwords.'
	String get help => 'The circled part of a page goes to the account an action uses, only when you pick that action. nts never sees your passwords.';

	/// en: 'Sign in'
	String get signIn => 'Sign in';

	/// en: 'Sign out'
	String get signOut => 'Sign out';

	/// en: 'Signing in…'
	String get signingIn => 'Signing in…';

	/// en: 'Signed in'
	String get signedIn => 'Signed in';

	/// en: 'Signed in · $who'
	String signedInAs({required Object who}) => 'Signed in · ${who}';

	/// en: 'Not signed in'
	String get notSignedIn => 'Not signed in';

	/// en: 'Check again'
	String get checkAgain => 'Check again';

	/// en: 'Mac only'
	String get macOnly => 'Mac only';

	/// en: 'Your ChatGPT account and plan. Pictures need Plus or higher.'
	String get chatgptHint => 'Your ChatGPT account and plan. Pictures need Plus or higher.';

	/// en: 'Your own Claude Code on this Mac, with your Claude plan.'
	String get claudeHint => 'Your own Claude Code on this Mac, with your Claude plan.';

	/// en: 'Not available'
	String get unavailable => 'Not available';

	/// en: 'Problem'
	String get problem => 'Problem';

	/// en: 'Sign out of Claude Code?'
	String get claudeSignOutTitle => 'Sign out of Claude Code?';

	/// en: 'This signs Claude Code out on this Mac, also in Terminal.'
	String get claudeSignOutBody => 'This signs Claude Code out on this Mac, also in Terminal.';

	/// en: 'Gemini and YouTube search through your own Google Cloud project, on its free tier.'
	String get googleHint => 'Gemini and YouTube search through your own Google Cloud project, on its free tier.';

	/// en: 'Use a code instead'
	String get useCode => 'Use a code instead';

	late final Translations$ai$accounts$deviceCode$en deviceCode = Translations$ai$accounts$deviceCode$en.internal(_root);
}

// Path: ai.google
class Translations$ai$google$en {
	Translations$ai$google$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Set up Google'
	String get title => 'Set up Google';

	/// en: 'Not set up'
	String get notSetUp => 'Not set up';

	/// en: 'Google sign-in goes through your own Google Cloud project, so it stays free. It takes about 15 minutes, once.'
	String get body => 'Google sign-in goes through your own Google Cloud project, so it stays free. It takes about 15 minutes, once.';

	/// en: 'At console.cloud.google.com, create a project.'
	String get step1 => 'At console.cloud.google.com, create a project.';

	/// en: 'In APIs & Services, enable "Generative Language API" and "YouTube Data API v3".'
	String get step2 => 'In APIs & Services, enable "Generative Language API" and "YouTube Data API v3".';

	/// en: 'In Google Auth platform, set the audience to External, then publish the app so its status is In production. When you sign in, Google will say it hasn't verified this app. It's your own project, so tap Advanced, then Continue.'
	String get step3 => 'In Google Auth platform, set the audience to External, then publish the app so its status is In production. When you sign in, Google will say it hasn\'t verified this app. It\'s your own project, so tap Advanced, then Continue.';

	/// en: 'In Clients, create an OAuth client of type iOS with the bundle ID com.mehmetbisen.nts.'
	String get step4 => 'In Clients, create an OAuth client of type iOS with the bundle ID com.mehmetbisen.nts.';

	/// en: 'Copy the client ID and the project ID below. Leave billing off to stay on the free tier.'
	String get step5 => 'Copy the client ID and the project ID below. Leave billing off to stay on the free tier.';

	/// en: 'Open Google Cloud Console'
	String get openConsole => 'Open Google Cloud Console';

	/// en: 'OAuth client ID'
	String get clientId => 'OAuth client ID';

	/// en: 'Project ID'
	String get projectId => 'Project ID';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Change setup'
	String get change => 'Change setup';

	/// en: 'This doesn't look like an OAuth client ID. It ends in .apps.googleusercontent.com.'
	String get invalidClientId => 'This doesn\'t look like an OAuth client ID. It ends in .apps.googleusercontent.com.';

	/// en: 'A project ID has 6 to 30 lowercase letters, digits and hyphens.'
	String get invalidProjectId => 'A project ID has 6 to 30 lowercase letters, digits and hyphens.';

	/// en: 'Saving a different client ID signs Google out.'
	String get changeSignsOut => 'Saving a different client ID signs Google out.';
}

// Path: ai.actionsSettings
class Translations$ai$actionsSettings$en {
	Translations$ai$actionsSettings$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'AI actions'
	String get title => 'AI actions';

	/// en: 'Which account and model each action uses. Automatic uses the first signed-in account that can do it.'
	String get help => 'Which account and model each action uses. Automatic uses the first signed-in account that can do it.';

	/// en: 'Automatic'
	String get automatic => 'Automatic';

	/// en: 'Now uses $provider'
	String automaticUses({required Object provider}) => 'Now uses ${provider}';

	/// en: 'No account signed in yet'
	String get automaticNone => 'No account signed in yet';

	/// en: 'may cost extra'
	String get mayCostExtra => 'may cost extra';

	/// en: 'picture'
	String get picture => 'picture';
}

// Path: sentry.consent.description
class Translations$sentry$consent$description$en {
	Translations$sentry$consent$description$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Would you like to automatically report unexpected errors? This helps me identify and fix issues faster.'
	String get question => 'Would you like to automatically report unexpected errors? This helps me identify and fix issues faster.';

	/// en: 'The reports may contain information about the error and your device. I've made every effort to filter out personal data but some may remain.'
	String get scope => 'The reports may contain information about the error and your device. I\'ve made every effort to filter out personal data but some may remain.';

	/// en: 'If you grant consent, error reporting will be enabled after you restart the app.'
	String get currentlyOff => 'If you grant consent, error reporting will be enabled after you restart the app.';

	/// en: 'If you revoke consent, please restart the app to disable error reporting.'
	String get currentlyOn => 'If you revoke consent, please restart the app to disable error reporting.';

	/// en: 'Learn more in the ${link(privacy policy)}.'
	TextSpan learnMoreInPrivacyPolicy({required InlineSpanBuilder link}) => TextSpan(children: [
		const TextSpan(text: 'Learn more in the '),
		link('privacy policy'),
		const TextSpan(text: '.'),
	]);
}

// Path: sentry.consent.answers
class Translations$sentry$consent$answers$en {
	Translations$sentry$consent$answers$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Yes'
	String get yes => 'Yes';

	/// en: 'No'
	String get no => 'No';

	/// en: 'Ask me later'
	String get later => 'Ask me later';
}

// Path: settings.prefDescriptions.hideFingerDrawing
class Translations$settings$prefDescriptions$hideFingerDrawing$en {
	Translations$settings$prefDescriptions$hideFingerDrawing$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Prevents accidental toggling'
	String get shown => 'Prevents accidental toggling';

	/// en: 'Finger drawing is fixed as enabled'
	String get fixedOn => 'Finger drawing is fixed as enabled';

	/// en: 'Finger drawing is fixed as disabled'
	String get fixedOff => 'Finger drawing is fixed as disabled';
}

// Path: settings.prefDescriptions.sentry
class Translations$settings$prefDescriptions$sentry$en {
	Translations$settings$prefDescriptions$sentry$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Active'
	String get active => 'Active';

	/// en: 'Inactive'
	String get inactive => 'Inactive';

	/// en: 'Active until you restart the app'
	String get activeUntilRestart => 'Active until you restart the app';

	/// en: 'Inactive until you restart the app'
	String get inactiveUntilRestart => 'Inactive until you restart the app';
}

// Path: login.ncLoginStep.loginFlow
class Translations$login$ncLoginStep$loginFlow$en {
	Translations$login$ncLoginStep$loginFlow$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Please authorize nts to access your Nextcloud account'
	String get pleaseAuthorize => 'Please authorize nts to access your Nextcloud account';

	/// en: 'Please follow the prompts in the Nextcloud interface'
	String get followPrompts => 'Please follow the prompts in the Nextcloud interface';

	/// en: 'Login page didn't open? Click here'
	String get browserDidntOpen => 'Login page didn\'t open? Click here';
}

// Path: login.encLoginStep.encFaq.0
class Translations$login$encLoginStep$encFaq$0$en {
	Translations$login$encLoginStep$encFaq$0$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'What is an encryption password? Why use two passwords?'
	String get q => 'What is an encryption password? Why use two passwords?';

	/// en: 'The Nextcloud password is used to access the cloud. The encryption password "scrambles" your data before it ever reaches the cloud. Even if someone gains access to your Nextcloud account, your notes will remain safe and encrypted with a separate password. This provides you a second layer of security to protect your data. No-one can access your notes on the server without your encryption password, but this also means that if you forget your encryption password, you will lose access to your data.'
	String get a => 'The Nextcloud password is used to access the cloud. The encryption password "scrambles" your data before it ever reaches the cloud.\nEven if someone gains access to your Nextcloud account, your notes will remain safe and encrypted with a separate password. This provides you a second layer of security to protect your data.\nNo-one can access your notes on the server without your encryption password, but this also means that if you forget your encryption password, you will lose access to your data.';
}

// Path: login.encLoginStep.encFaq.1
class Translations$login$encLoginStep$encFaq$1$en {
	Translations$login$encLoginStep$encFaq$1$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'I haven't set an encryption password yet. Where do I get it?'
	String get q => 'I haven\'t set an encryption password yet. Where do I get it?';

	/// en: 'Choose a new encryption password and enter it above. nts will generate your encryption keys from this password automatically.'
	String get a => 'Choose a new encryption password and enter it above.\nnts will generate your encryption keys from this password automatically.';
}

// Path: login.encLoginStep.encFaq.2
class Translations$login$encLoginStep$encFaq$2$en {
	Translations$login$encLoginStep$encFaq$2$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Can I use the same password as my Nextcloud account?'
	String get q => 'Can I use the same password as my Nextcloud account?';

	/// en: 'Yes, but keep in mind that it would be easier for the server administrator or someone else to access your notes if they gain access to your Nextcloud account.'
	String get a => 'Yes, but keep in mind that it would be easier for the server administrator or someone else to access your notes if they gain access to your Nextcloud account.';
}

// Path: editor.menu.boxFits
class Translations$editor$menu$boxFits$en {
	Translations$editor$menu$boxFits$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Stretch'
	String get fill => 'Stretch';

	/// en: 'Cover'
	String get cover => 'Cover';

	/// en: 'Contain'
	String get contain => 'Contain';
}

// Path: editor.menu.bgPatterns
class Translations$editor$menu$bgPatterns$en {
	Translations$editor$menu$bgPatterns$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Blank'
	String get none => 'Blank';

	/// en: 'College-ruled'
	String get college => 'College-ruled';

	/// en: 'College-ruled (Reverse)'
	String get collegeRtl => 'College-ruled (Reverse)';

	/// en: 'Lined'
	String get lined => 'Lined';

	/// en: 'Grid'
	String get grid => 'Grid';

	/// en: 'Dots'
	String get dots => 'Dots';

	/// en: 'Staffs'
	String get staffs => 'Staffs';

	/// en: 'Tablature'
	String get tablature => 'Tablature';

	/// en: 'Cornell'
	String get cornell => 'Cornell';
}

// Path: editor.customizeToolbar.categories
class Translations$editor$customizeToolbar$categories$en {
	Translations$editor$customizeToolbar$categories$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Write'
	String get write => 'Write';

	/// en: 'Erase and select'
	String get eraseAndSelect => 'Erase and select';

	/// en: 'Insert'
	String get insert => 'Insert';

	/// en: 'View'
	String get view => 'View';

	/// en: 'Actions'
	String get actions => 'Actions';
}

// Path: editor.customizeToolbar.tools
class Translations$editor$customizeToolbar$tools$en {
	Translations$editor$customizeToolbar$tools$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Pen'
	String get pen => 'Pen';

	/// en: 'Eraser'
	String get eraser => 'Eraser';

	/// en: 'Custom color'
	String get colorPicker => 'Custom color';

	/// en: 'Draw with finger'
	String get fingerDrawing => 'Draw with finger';

	/// en: 'Fullscreen'
	String get fullscreen => 'Fullscreen';

	/// en: 'Export'
	String get export => 'Export';

	/// en: 'Page options'
	String get pageOptions => 'Page options';
}

// Path: ai.actions.explainExample
class Translations$ai$actions$explainExample$en {
	Translations$ai$actions$explainExample$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Explain with an example'
	String get title => 'Explain with an example';

	/// en: 'A clearer explanation, with one example'
	String get description => 'A clearer explanation, with one example';
}

// Path: ai.actions.paragraph
class Translations$ai$actions$paragraph$en {
	Translations$ai$actions$paragraph$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Explain in a paragraph'
	String get title => 'Explain in a paragraph';

	/// en: 'What the note is actually saying'
	String get description => 'What the note is actually saying';
}

// Path: ai.actions.graph
class Translations$ai$actions$graph$en {
	Translations$ai$actions$graph$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Make a graph'
	String get title => 'Make a graph';

	/// en: 'Plot the formula or numbers in the note'
	String get description => 'Plot the formula or numbers in the note';
}

// Path: ai.actions.illustration
class Translations$ai$actions$illustration$en {
	Translations$ai$actions$illustration$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Make an illustration'
	String get title => 'Make an illustration';

	/// en: 'A drawing of the main idea'
	String get description => 'A drawing of the main idea';
}

// Path: ai.actions.video
class Translations$ai$actions$video$en {
	Translations$ai$actions$video$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Find a video'
	String get title => 'Find a video';

	/// en: 'A video that explains the same thing'
	String get description => 'A video that explains the same thing';
}

// Path: ai.actions.source
class Translations$ai$actions$source$en {
	Translations$ai$actions$source$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Find a source'
	String get title => 'Find a source';

	/// en: 'Web pages about the same thing'
	String get description => 'Web pages about the same thing';
}

// Path: ai.accounts.deviceCode
class Translations$ai$accounts$deviceCode$en {
	Translations$ai$accounts$deviceCode$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Sign in with a code'
	String get title => 'Sign in with a code';

	/// en: 'Open the page, sign in to ChatGPT, and enter this code. Code sign-in must be on in ChatGPT → Settings → Security.'
	String get body => 'Open the page, sign in to ChatGPT, and enter this code. Code sign-in must be on in ChatGPT → Settings → Security.';

	/// en: 'Open page'
	String get open => 'Open page';

	/// en: 'Copy code'
	String get copy => 'Copy code';

	/// en: 'Waiting for you…'
	String get waiting => 'Waiting for you…';
}
