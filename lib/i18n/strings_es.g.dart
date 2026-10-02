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
class TranslationsEs extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEs({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.es,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <es>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	late final TranslationsEs _root = this; // ignore: unused_field

	@override 
	TranslationsEs $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEs(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$es common = _Translations$common$es._(_root);
	@override late final _Translations$home$es home = _Translations$home$es._(_root);
	@override late final _Translations$sentry$es sentry = _Translations$sentry$es._(_root);
	@override late final _Translations$settings$es settings = _Translations$settings$es._(_root);
	@override late final _Translations$logs$es logs = _Translations$logs$es._(_root);
	@override late final _Translations$appInfo$es appInfo = _Translations$appInfo$es._(_root);
	@override late final _Translations$editor$es editor = _Translations$editor$es._(_root);
}

// Path: common
class _Translations$common$es extends Translations$common$en {
	_Translations$common$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get done => 'Hecho';
	@override String get continueBtn => 'Continuar';
	@override String get cancel => 'Cancelar';
}

// Path: home
class _Translations$home$es extends Translations$home$en {
	_Translations$home$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$home$titles$es titles = _Translations$home$titles$es._(_root);
	@override late final _Translations$home$tooltips$es tooltips = _Translations$home$tooltips$es._(_root);
	@override late final _Translations$home$create$es create = _Translations$home$create$es._(_root);
	@override String get welcome => 'Te damos la bienvenida a nts';
	@override String get invalidFormat => 'El archivo que seleccionaste no es válido. Por favor, selecciona un archivo .sbn, .sbn2, .sba or .pdf.';
	@override String get createNewNote => 'Presiona el botón + para crear una nueva nota';
	@override String get backFolder => 'Volver a la carpeta anterior';
	@override late final _Translations$home$newFolder$es newFolder = _Translations$home$newFolder$es._(_root);
	@override late final _Translations$home$renameNote$es renameNote = _Translations$home$renameNote$es._(_root);
	@override late final _Translations$home$moveNote$es moveNote = _Translations$home$moveNote$es._(_root);
	@override String get deleteNote => 'Eliminar nota';
	@override late final _Translations$home$deleteNoteDialog$es deleteNoteDialog = _Translations$home$deleteNoteDialog$es._(_root);
	@override late final _Translations$home$renameFolder$es renameFolder = _Translations$home$renameFolder$es._(_root);
	@override late final _Translations$home$deleteFolder$es deleteFolder = _Translations$home$deleteFolder$es._(_root);
	@override late final _Translations$home$sort$es sort = _Translations$home$sort$es._(_root);
}

// Path: sentry
class _Translations$sentry$es extends Translations$sentry$en {
	_Translations$sentry$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$sentry$consent$es consent = _Translations$sentry$consent$es._(_root);
}

// Path: settings
class _Translations$settings$es extends Translations$settings$en {
	_Translations$settings$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$settings$prefCategories$es prefCategories = _Translations$settings$prefCategories$es._(_root);
	@override late final _Translations$settings$prefLabels$es prefLabels = _Translations$settings$prefLabels$es._(_root);
	@override late final _Translations$settings$prefDescriptions$es prefDescriptions = _Translations$settings$prefDescriptions$es._(_root);
	@override late final _Translations$settings$themeModes$es themeModes = _Translations$settings$themeModes$es._(_root);
	@override late final _Translations$settings$layoutSizes$es layoutSizes = _Translations$settings$layoutSizes$es._(_root);
	@override late final _Translations$settings$accentColorPicker$es accentColorPicker = _Translations$settings$accentColorPicker$es._(_root);
	@override String get systemLanguage => 'Idioma del sistema';
	@override List<String> get axisDirections => [
		'Arriba',
		'Derecha',
		'Abajo',
		'Izquierda',
	];
	@override late final _Translations$settings$reset$es reset = _Translations$settings$reset$es._(_root);
	@override late final _Translations$settings$customDataDir$es customDataDir = _Translations$settings$customDataDir$es._(_root);
	@override String get autosaveDisabled => 'Nunca';
	@override String get shapeRecognitionDisabled => 'Nunca';
	@override String get openDataDir => 'Abrir carpeta nts';
}

// Path: logs
class _Translations$logs$es extends Translations$logs$en {
	_Translations$logs$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get useTheApp => 'Los registros aparecerán aquí mientras usa la aplicación';
	@override String get logs => 'Registros';
	@override String get viewLogs => 'Ver registros';
	@override String get debuggingInfo => 'Los registros contienen información útil para la depuración y el desarrollo.';
	@override String get noLogs => '¡Aquí no hay registros!';
}

// Path: appInfo
class _Translations$appInfo$es extends Translations$appInfo$en {
	_Translations$appInfo$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String licenseNotice({required Object buildYear}) => 'nts (modified from Saber)  Copyright © 2022-${buildYear}  Adil Hanney\nEste programa no tiene ninguna garantía. Es un software libre, y se puede redistribuir bajo ciertas condiciones.';
	@override String get debug => 'DEBUG';
	@override String get licenseButton => 'Toca aquí para ver más información sobre la licencia';
	@override String get privacyPolicyButton => 'Toca aquí para ver nuestra política de privacidad';
}

// Path: editor
class _Translations$editor$es extends Translations$editor$en {
	_Translations$editor$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$editor$toolbar$es toolbar = _Translations$editor$toolbar$es._(_root);
	@override late final _Translations$editor$pens$es pens = _Translations$editor$pens$es._(_root);
	@override late final _Translations$editor$penOptions$es penOptions = _Translations$editor$penOptions$es._(_root);
	@override late final _Translations$editor$colors$es colors = _Translations$editor$colors$es._(_root);
	@override late final _Translations$editor$imageOptions$es imageOptions = _Translations$editor$imageOptions$es._(_root);
	@override late final _Translations$editor$selectionBar$es selectionBar = _Translations$editor$selectionBar$es._(_root);
	@override late final _Translations$editor$menu$es menu = _Translations$editor$menu$es._(_root);
	@override late final _Translations$editor$readOnlyBanner$es readOnlyBanner = _Translations$editor$readOnlyBanner$es._(_root);
	@override late final _Translations$editor$versionTooNew$es versionTooNew = _Translations$editor$versionTooNew$es._(_root);
	@override late final _Translations$editor$quill$es quill = _Translations$editor$quill$es._(_root);
	@override late final _Translations$editor$hud$es hud = _Translations$editor$hud$es._(_root);
	@override String get pages => 'Páginas';
	@override String get untitled => 'Sin título';
	@override String get needsToSaveBeforeExiting => 'Guardando los cambios… Puedes salir del editor de forma segura cuando se haya guardado todo';
}

// Path: home.titles
class _Translations$home$titles$es extends Translations$home$titles$en {
	_Translations$home$titles$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get home => 'Notas recientes';
	@override String get browse => 'Navegar';
	@override String get whiteboard => 'Pizarra';
	@override String get settings => 'Configuración';
}

// Path: home.tooltips
class _Translations$home$tooltips$es extends Translations$home$tooltips$en {
	_Translations$home$tooltips$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get newNote => 'Crear nota';
	@override String get exportNote => 'Exportar nota';
}

// Path: home.create
class _Translations$home$create$es extends Translations$home$create$en {
	_Translations$home$create$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get newNote => 'Nueva nota';
	@override String get importNote => 'Importar nota';
}

// Path: home.newFolder
class _Translations$home$newFolder$es extends Translations$home$newFolder$en {
	_Translations$home$newFolder$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get newFolder => 'Nueva carpeta';
	@override String get folderName => 'Nombre de la carpeta';
	@override String get create => 'Crear';
	@override String get folderNameEmpty => 'El nombre de la carpeta no puede estar vacío';
	@override String get folderNameContainsSlash => 'El nombre de la carpeta no puede contener una barra vertical';
	@override String get folderNameExists => 'Ya existe una carpeta con este nombre';
}

// Path: home.renameNote
class _Translations$home$renameNote$es extends Translations$home$renameNote$en {
	_Translations$home$renameNote$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get renameNote => 'Renombrar nota';
	@override String get noteName => 'Nombre de la nota';
	@override String get rename => 'Renombrar';
	@override String get noteNameEmpty => 'El nombre de la nota no puede estar vacío';
	@override String get noteNameExists => 'Ya existe una nota con este nombre';
	@override String get noteNameForbiddenCharacters => 'El nombre contiene caracteres no permitidos';
	@override String get noteNameReserved => 'Nombre reservado';
}

// Path: home.moveNote
class _Translations$home$moveNote$es extends Translations$home$moveNote$en {
	_Translations$home$moveNote$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get moveNote => 'Mover nota';
	@override String moveNotes({required Object n}) => 'Mover ${n} notas';
	@override String moveName({required Object f}) => 'Mover ${f}';
	@override String get move => 'Mover';
	@override String renamedTo({required Object newName}) => 'Se renombrará la nota a ${newName}';
	@override String get multipleRenamedTo => 'Renombrar las siguientes notas:';
	@override String numberRenamedTo({required Object n}) => '${n} notas serán renombradas para evitar conflictos';
}

// Path: home.deleteNoteDialog
class _Translations$home$deleteNoteDialog$es extends Translations$home$deleteNoteDialog$en {
	_Translations$home$deleteNoteDialog$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String confirmDelete({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		other: '¿Desea eliminar la nota seleccionada de forma permanente?',
	);
	@override String get delete => 'Eliminar';
	@override String deleteNotes({required Object n}) => 'Eliminar ${n} notas';
	@override String deleteName({required Object f}) => 'Borrar ${f}';
}

// Path: home.renameFolder
class _Translations$home$renameFolder$es extends Translations$home$renameFolder$en {
	_Translations$home$renameFolder$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get renameFolder => 'Renombrar carpeta';
	@override String get folderName => 'Nombre de la carpeta';
	@override String get rename => 'Renombrar';
	@override String get folderNameEmpty => 'El nombre de la carpeta no puede estar vacío';
	@override String get folderNameContainsSlash => 'El nombre de la carpeta no puede contener una barra (/)';
	@override String get folderNameExists => 'Ya existe una carpeta con este nombre';
}

// Path: home.deleteFolder
class _Translations$home$deleteFolder$es extends Translations$home$deleteFolder$en {
	_Translations$home$deleteFolder$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get deleteFolder => 'Eliminar carpeta';
	@override String deleteName({required Object f}) => 'Eliminar ${f}';
	@override String get delete => 'Eliminar';
	@override String get alsoDeleteContents => 'Eliminar también las notas guardadas dentro de la carpeta';
}

// Path: home.sort
class _Translations$home$sort$es extends Translations$home$sort$en {
	_Translations$home$sort$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get sortBy => 'Ordenar por';
	@override String get nameAToZ => 'Nombre (de la A a la Z)';
	@override String get nameZToA => 'Nombre (de la A a la Z)';
	@override String get lastModifiedNewToOld => 'Editado (Más reciente primero)';
	@override String get lastModifiedOldToNew => 'Editado (Más antiguo primero)';
}

// Path: sentry.consent
class _Translations$sentry$consent$es extends Translations$sentry$consent$en {
	_Translations$sentry$consent$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => '¿Quieres mejorar nts?';
	@override late final _Translations$sentry$consent$description$es description = _Translations$sentry$consent$description$es._(_root);
	@override late final _Translations$sentry$consent$answers$es answers = _Translations$sentry$consent$answers$es._(_root);
}

// Path: settings.prefCategories
class _Translations$settings$prefCategories$es extends Translations$settings$prefCategories$en {
	_Translations$settings$prefCategories$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get general => 'General';
	@override String get writing => 'Escritura';
	@override String get editor => 'Editor';
	@override String get performance => 'Desempeño';
	@override String get advanced => 'Avanzado';
}

// Path: settings.prefLabels
class _Translations$settings$prefLabels$es extends Translations$settings$prefLabels$en {
	_Translations$settings$prefLabels$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get locale => 'Idioma de la aplicación';
	@override String get appTheme => 'Tema de la aplicación';
	@override String get platform => 'Tipo de tema';
	@override String get layoutSize => 'Tipo de disposición';
	@override String get customAccentColor => 'Color de acento personalizado';
	@override String get hyperlegibleFont => 'Fuente hiperlegible';
	@override String get editorToolbarAlignment => 'Alineación de la barra de herramientas del editor';
	@override String get editorToolbarShowInFullscreen => 'Mostrar la barra de herramientas del editor en el modo de pantalla completa';
	@override String get editorAutoInvert => 'Invertir notas en el modo oscuro';
	@override String get preferGreyscale => 'Preferir colores en escala de grises';
	@override String get maxImageSize => 'Tamaño máximo de la imagen';
	@override String get autoClearWhiteboardOnExit => 'Borrar la pizarra después de salir de la aplicación';
	@override String get disableEraserAfterUse => 'Desactivar automáticamente la goma de borrar';
	@override String get hideFingerDrawingToggle => 'Ocultar la opción para activar/desactivar la escritura con el dedo';
	@override String get autoDisableFingerDrawingWhenStylusDetected => 'Desactivar dibujo con el dedo automáticamente';
	@override String get editorPromptRename => 'Solicitarte cambiar el nombre de nuevas notas';
	@override String get recentColorsDontSavePresets => 'No guardar colores preestablecidos en los colores recientes';
	@override String get recentColorsLength => 'Número de colores recientes a almacenar';
	@override String get printPageIndicators => 'Indicadores de página de impresión';
	@override String get autosave => 'Guardado automático';
	@override String get shapeRecognitionDelay => 'Retraso en el reconocimiento de formas';
	@override String get autoStraightenLines => 'Enderezar líneas automáticamente';
	@override String get customDataDir => 'Carpeta de nts personalizada';
	@override String get sentry => 'Informes de errores';
}

// Path: settings.prefDescriptions
class _Translations$settings$prefDescriptions$es extends Translations$settings$prefDescriptions$en {
	_Translations$settings$prefDescriptions$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get hyperlegibleFont => 'Atkinson Hyperlegible aumenta la legibilidad para lectores con poca visión';
	@override String get preferGreyscale => 'Para pantallas con tinta electrónica';
	@override String get autoClearWhiteboardOnExit => 'Aún se sincronizará con tus otros dispositivos';
	@override String get disableEraserAfterUse => 'Volver automáticamente al bolígrafo tras usar la goma';
	@override String get maxImageSize => 'Las imágenes más grandes que este valor serán comprimidas';
	@override late final _Translations$settings$prefDescriptions$hideFingerDrawing$es hideFingerDrawing = _Translations$settings$prefDescriptions$hideFingerDrawing$es._(_root);
	@override String get autoDisableFingerDrawingWhenStylusDetected => 'Desactivar dibujar con el dedo cuando hay un bolígrafo detectado';
	@override String get editorPromptRename => 'Siempre puedes cambiar el nombre de las notas más tarde';
	@override String get printPageIndicators => 'Mostrar indicadores de página en las exportaciones';
	@override String get shapeRecognitionDelay => 'Cuán a menudo se actualiza la previsualización de forma';
	@override String get autoStraightenLines => 'Enderezar líneas largas sin utilizar el bolígrafo de formas';
	@override late final _Translations$settings$prefDescriptions$sentry$es sentry = _Translations$settings$prefDescriptions$sentry$es._(_root);
	@override String get autosave => 'Auto-Save después de un breve retraso, o nunca';
}

// Path: settings.themeModes
class _Translations$settings$themeModes$es extends Translations$settings$themeModes$en {
	_Translations$settings$themeModes$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get system => 'Sistema';
	@override String get light => 'Claro';
	@override String get dark => 'Oscuro';
}

// Path: settings.layoutSizes
class _Translations$settings$layoutSizes$es extends Translations$settings$layoutSizes$en {
	_Translations$settings$layoutSizes$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Auto';
	@override String get phone => 'Teléfono';
	@override String get tablet => 'Tablet';
}

// Path: settings.accentColorPicker
class _Translations$settings$accentColorPicker$es extends Translations$settings$accentColorPicker$en {
	_Translations$settings$accentColorPicker$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get pickAColor => 'Elegir un color';
}

// Path: settings.reset
class _Translations$settings$reset$es extends Translations$settings$reset$en {
	_Translations$settings$reset$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => '¿Quieres restablecer esta configuración?';
	@override String get button => 'Restablecer';
}

// Path: settings.customDataDir
class _Translations$settings$customDataDir$es extends Translations$settings$customDataDir$en {
	_Translations$settings$customDataDir$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get unsupported => 'Esta característica es actualmente solo para desarrolladores. Usarlo probablemente dará como resultado la pérdida de datos.';
	@override String get cancel => 'Cancelar';
	@override String get select => 'Seleccionar';
	@override String get mustBeEmpty => 'El directorio seleccionado debe estar vacío.';
}

// Path: editor.toolbar
class _Translations$editor$toolbar$es extends Translations$editor$toolbar$en {
	_Translations$editor$toolbar$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get toggleColors => 'Paleta de colores (Ctrl C)';
	@override String get select => 'Seleccionar';
	@override String get toggleEraser => 'Borrar (Ctrl E)';
	@override String get photo => 'Foto';
	@override String get text => 'Texto';
	@override String get toggleFingerDrawing => 'Dibujar con el dedo (Ctrl F)';
	@override String get undo => 'Deshacer';
	@override String get redo => 'Rehacer';
	@override String get export => 'Exportar (Ctrl Shift S)';
	@override String get exportAs => 'Exportar cómo:';
	@override String get fullscreen => 'Pantalla completa (F11)';
}

// Path: editor.pens
class _Translations$editor$pens$es extends Translations$editor$pens$en {
	_Translations$editor$pens$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get ballpointPen => 'Bolígrafo';
	@override String get highlighter => 'Resaltador';
	@override String get shapePen => 'Bolígrafo con formas';
	@override String get laserPointer => 'Puntero láser';
	@override String get fountainPen => 'Estilográfica';
	@override String get pencil => 'Lápiz';
}

// Path: editor.penOptions
class _Translations$editor$penOptions$es extends Translations$editor$penOptions$en {
	_Translations$editor$penOptions$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get size => 'Tamaño';
}

// Path: editor.colors
class _Translations$editor$colors$es extends Translations$editor$colors$en {
	_Translations$editor$colors$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get colorPicker => 'Selector de color';
	@override String customHue({required Object h}) => '${h} personalizado';
	@override String get dark => 'oscuro';
	@override String get light => 'claro';
	@override String get black => 'Negro';
	@override String get darkGrey => 'Gris oscuro';
	@override String get grey => 'Gris';
	@override String get lightGrey => 'Gris claro';
	@override String get white => 'Blanco';
	@override String get red => 'Rojo';
	@override String get green => 'Verde';
	@override String get cyan => 'Cyan';
	@override String get blue => 'Azul';
	@override String get yellow => 'Amarillo';
	@override String get purple => 'Morado';
	@override String get pink => 'Rosa';
	@override String get orange => 'Naranja';
	@override String get pastelRed => 'Rojo pastel';
	@override String get pastelOrange => 'Naranja pastel';
	@override String get pastelYellow => 'Amarillo pastel';
	@override String get pastelGreen => 'Verde pastel';
	@override String get pastelCyan => 'Azul cyan pastel';
	@override String get pastelBlue => 'Azul pastel';
	@override String get pastelPurple => 'Morado pastel';
	@override String get pastelPink => 'Rosa pastel';
	@override String customBrightnessHue({required Object h, required Object b}) => '${h} ${b} personalizado';
}

// Path: editor.imageOptions
class _Translations$editor$imageOptions$es extends Translations$editor$imageOptions$en {
	_Translations$editor$imageOptions$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Opciones de imagen';
	@override String get invertible => 'Invertible';
	@override String get download => 'Descargar';
	@override String get setAsBackground => 'Usar como fondo';
	@override String get removeAsBackground => 'Eliminar como fondo';
	@override String get delete => 'Eliminar';
}

// Path: editor.selectionBar
class _Translations$editor$selectionBar$es extends Translations$editor$selectionBar$en {
	_Translations$editor$selectionBar$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get delete => 'Eliminar';
	@override String get duplicate => 'Duplicar';
}

// Path: editor.menu
class _Translations$editor$menu$es extends Translations$editor$menu$en {
	_Translations$editor$menu$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String clearPage({required Object page, required Object totalPages}) => 'Eliminar páginas ${page}/${totalPages}';
	@override String get clearAllPages => 'Borrar todas las páginas';
	@override String get insertPage => 'Insertar página debajo';
	@override String get duplicatePage => 'Duplicar página';
	@override String get deletePage => 'Eliminar página';
	@override String get lineHeight => 'Altura de la línea';
	@override String get backgroundImageFit => 'Ajuste de la imagen de fondo';
	@override String get backgroundPattern => 'Patrón de fondo';
	@override String get import => 'Importar';
	@override late final _Translations$editor$menu$boxFits$es boxFits = _Translations$editor$menu$boxFits$es._(_root);
	@override late final _Translations$editor$menu$bgPatterns$es bgPatterns = _Translations$editor$menu$bgPatterns$es._(_root);
	@override String get lineThickness => 'Espesor de línea';
	@override String get lineThicknessDescription => 'Grosor de la línea de fondo';
	@override String get lineHeightDescription => 'También controla el tamaño del texto de las notas escritas.';
}

// Path: editor.readOnlyBanner
class _Translations$editor$readOnlyBanner$es extends Translations$editor$readOnlyBanner$en {
	_Translations$editor$readOnlyBanner$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Modo de solo lectura';
	@override String get watchingServer => 'Actualmente estás buscando actualizaciones en el servidor. La edición está deshabilitada en este modo.';
	@override String get corrupted => 'No se pudo cargar la nota. Es posible que esté dañado o que aún se esté descargando.';
}

// Path: editor.versionTooNew
class _Translations$editor$versionTooNew$es extends Translations$editor$versionTooNew$en {
	_Translations$editor$versionTooNew$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Esta nota fue editada usando una versión más reciente de nts';
	@override String get subtitle => 'La edición de esta nota puede resultar en la pérdida de cierta información. ¿Quieres ignorar esto y editarlo de todos modos?';
	@override String get allowEditing => 'Editar';
}

// Path: editor.quill
class _Translations$editor$quill$es extends Translations$editor$quill$en {
	_Translations$editor$quill$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get typeSomething => 'Escribe algo aquí…';
}

// Path: editor.hud
class _Translations$editor$hud$es extends Translations$editor$hud$en {
	_Translations$editor$hud$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get unlockZoom => 'Desbloquear zoom';
	@override String get lockZoom => 'Bloquear zoom';
	@override String get unlockSingleFingerPan => 'Habilitar la panorámica con un solo dedo';
	@override String get lockSingleFingerPan => 'Deshabilitar la panorámica con un solo dedo';
	@override String get unlockAxisAlignedPan => 'Desbloquear el desplazamiento a horizontal o vertical';
	@override String get lockAxisAlignedPan => 'Bloquear el desplazamiento a horizontal o vertical';
}

// Path: sentry.consent.description
class _Translations$sentry$consent$description$es extends Translations$sentry$consent$description$en {
	_Translations$sentry$consent$description$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get question => '¿Quieres enviar informes de errores de forma automática? Esto permite identificar y corregir fallos más rápido.';
	@override String get scope => 'Los reportes pueden contener información acerca del error y su dispositivo. Me he esforzado por filtrar la información personal, pero es posible que queden restos.';
	@override String get currentlyOff => 'Si aceptas, los informes de error se activarán al reiniciar la app.';
	@override String get currentlyOn => 'En caso de retirar su consentimiento, reinicie la aplicación para desactivar el reporte de errores.';
	@override TextSpan learnMoreInPrivacyPolicy({required InlineSpanBuilder link}) => TextSpan(children: [
		const TextSpan(text: 'Aprenda más en '),
		link('privacy policy'),
		const TextSpan(text: '.'),
	]);
}

// Path: sentry.consent.answers
class _Translations$sentry$consent$answers$es extends Translations$sentry$consent$answers$en {
	_Translations$sentry$consent$answers$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get yes => 'Si';
	@override String get no => 'No';
	@override String get later => 'Perguntar después';
}

// Path: settings.prefDescriptions.hideFingerDrawing
class _Translations$settings$prefDescriptions$hideFingerDrawing$es extends Translations$settings$prefDescriptions$hideFingerDrawing$en {
	_Translations$settings$prefDescriptions$hideFingerDrawing$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get shown => 'Evita cambios accidentales';
	@override String get fixedOn => 'Dibujar o escribir con el dedo está activado';
	@override String get fixedOff => 'Dibujar o escribir con el dedo está desactivado';
}

// Path: settings.prefDescriptions.sentry
class _Translations$settings$prefDescriptions$sentry$es extends Translations$settings$prefDescriptions$sentry$en {
	_Translations$settings$prefDescriptions$sentry$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get active => 'Activo';
	@override String get inactive => 'Inactivo';
	@override String get activeUntilRestart => 'Activo hasta que reinicie la aplicación';
	@override String get inactiveUntilRestart => 'Inactivo hasta que reinicie la aplicación';
}

// Path: editor.menu.boxFits
class _Translations$editor$menu$boxFits$es extends Translations$editor$menu$boxFits$en {
	_Translations$editor$menu$boxFits$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get fill => 'Llenar';
	@override String get cover => 'Cubrir';
	@override String get contain => 'Contener';
}

// Path: editor.menu.bgPatterns
class _Translations$editor$menu$bgPatterns$es extends Translations$editor$menu$bgPatterns$en {
	_Translations$editor$menu$bgPatterns$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get none => 'En blanco';
	@override String get college => 'Rayado universitario';
	@override String get collegeRtl => 'Rayado universitario (inverso)';
	@override String get lined => 'Rayado';
	@override String get grid => 'Cuadrículado';
	@override String get dots => 'Punteado';
	@override String get staffs => 'Pentagrama';
	@override String get tablature => 'Tablatura';
	@override String get cornell => 'Método Cornell';
}
