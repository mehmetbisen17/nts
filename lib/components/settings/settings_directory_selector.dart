import 'dart:io';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nts/components/settings/settings_row.dart';
import 'package:nts/components/theming/adaptive_alert_dialog.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:sbn/font_fallbacks.dart';

class SettingsDirectorySelector extends StatelessWidget {
  const new({
    super.key,
    required this.title,
    this.afterChange,
    this.isUnsupported = true,
  });

  final String title;
  final ValueChanged<Color?>? afterChange;
  final bool isUnsupported;

  void onPressed(BuildContext context) async {
    final oldDir = Directory(FileManager.documentsDirectory);
    final oldDirIsEmpty = oldDir.existsSync()
        ? oldDir.listSync().isEmpty
        : true;
    await showAdaptiveDialog(
      context: context,
      builder: (context) => DirectorySelector(
        title: title,
        initialDirectory: FileManager.documentsDirectory,
        mustBeEmpty: !oldDirIsEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: stows.customDataDir,
      builder: (context, customDataDir, _) => SettingsRow(
        title: title,
        subtitle: FileManager.documentsDirectory,
        modified: customDataDir != stows.customDataDir.defaultValue,
        showChevron: true,
        onTap: () => onPressed(context),
      ),
    );
  }
}

class DirectorySelector extends StatefulWidget {
  const new({
    super.key,
    required this.title,
    required this.initialDirectory,
    this.mustBeEmpty = true,
  });

  final String title;
  final String initialDirectory;
  final bool mustBeEmpty;

  @override
  State<DirectorySelector> createState() => _DirectorySelectorState();
}

class _DirectorySelectorState extends State<DirectorySelector> {
  late String _directory = widget.initialDirectory;
  late var _isEmpty = true;

  Future<void> _pickDir() async {
    final directory = await FilePicker.getDirectoryPath(
      dialogTitle: widget.title,
      initialDirectory: _directory,
      androidOptions: defaultTargetPlatform == .android
          ? const FilePickerAndroidOptions(
              safOptions: .new(
                grant: .lifetime,
                accessMode: .readWrite,
                persistGrant: true,
              ),
            )
          : const .new(),
    );

    if (directory == null) return;
    if (directory == _directory) return;

    final dir = Directory(directory);
    _directory = directory;
    _isEmpty = dir.existsSync() ? dir.listSync().isEmpty : true;

    if (!mounted) return;

    setState(() {});
  }

  Future<void> _pickDefaultDir() async {
    final directory = await FileManager.getDefaultDocumentsDirectory();

    final dir = Directory(directory);
    _directory = directory;
    _isEmpty = dir.existsSync() ? dir.listSync().isEmpty : true;

    if (!mounted) return;
    setState(() {});
  }

  void _onConfirm() {
    stows.customDataDir.value = _directory;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);

    final emptyError = widget.mustBeEmpty && !_isEmpty;

    return AdaptiveAlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: .min,
        children: [
          Text(
            t.settings.customDataDir.unsupported,
            style: TextStyle(color: colorScheme.error),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _directory,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'FiraMono',
                    fontFamilyFallback: ntsMonoFontFallbacks,
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.folder), onPressed: _pickDir),
              if (stows.customDataDir.value != null)
                IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: _pickDefaultDir,
                ),
            ],
          ),
          if (emptyError)
            Text(
              t.settings.customDataDir.mustBeEmpty,
              style: TextStyle(color: colorScheme.error),
            ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => context.pop(),
          child: Text(t.settings.customDataDir.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: emptyError ? null : _onConfirm,
          child: Text(t.settings.customDataDir.select),
        ),
      ],
    );
  }
}
