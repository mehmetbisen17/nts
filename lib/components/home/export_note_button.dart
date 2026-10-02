import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/theming/adaptive_circular_progress_indicator.dart';
import 'package:nts/data/editor/editor_core_info.dart';
import 'package:nts/data/editor/editor_exporter.dart';
import 'package:nts/data/file_manager/file_manager.dart';
import 'package:nts/i18n/strings.g.dart';

class ExportNoteButton extends StatefulWidget {
  const new({super.key, required this.selectedFiles});

  final List<String> selectedFiles;

  @override
  State<ExportNoteButton> createState() => _ExportNoteButtonState();
}

class _ExportNoteButtonState extends State<ExportNoteButton> {
  final ValueNotifier<bool> isDialOpen = ValueNotifier(false);
  var _currentlyExporting = false;

  Future<void> exportFile(List<String> selectedFiles, bool exportPdf) async {
    setState(() => _currentlyExporting = true);
    await exportNotes(context, selectedFiles, pdf: exportPdf);
    if (mounted) setState(() => _currentlyExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      spacing: 3,
      mini: true,
      openCloseDial: isDialOpen,
      childPadding: const .all(5),
      spaceBetweenChildren: 4,
      switchLabelPosition: Directionality.of(context) == .rtl,
      dialRoot: (context, open, toggleChildren) {
        return _currentlyExporting
            ? AdaptiveCircularProgressIndicator.textStyled()
            : IconButton(
                padding: .zero,
                tooltip: t.home.tooltips.exportNote,
                onPressed: toggleChildren,
                icon: const Icon(Symbols.ios_share, weight: 300),
              );
      },
      children: [
        SpeedDialChild(
          child: const Icon(Symbols.picture_as_pdf, weight: 300),
          label: 'PDF',
          onTap: () => exportFile(widget.selectedFiles, true),
        ),
        SpeedDialChild(
          child: const Icon(Symbols.note, weight: 300),
          label: 'SBA',
          onTap: () => exportFile(widget.selectedFiles, false),
        ),
      ],
    );
  }
}

/// Exports the notes [selectedFiles] as PDFs or SBAs
/// (in a zip if there's more than one).
Future<void> exportNotes(
  BuildContext context,
  List<String> selectedFiles, {
  required bool pdf,
}) async {
  final files = <ArchiveFile>[];
  for (final filePath in selectedFiles) {
    final coreInfo = await EditorCoreInfo.loadFromFilePath(filePath);
    if (!context.mounted) return;

    final fileNameWithoutExtension = coreInfo.filePath.substring(
      coreInfo.filePath.lastIndexOf('/') + 1,
    );

    if (pdf) {
      final pdfDoc = await EditorExporter.generatePdf(coreInfo, context);
      final pdfBytes = await pdfDoc.save();
      files.add(
        ArchiveFile('$fileNameWithoutExtension.pdf', pdfBytes.length, pdfBytes),
      );
    } else {
      final sba = await coreInfo.saveToSba(currentPageIndex: null);
      files.add(ArchiveFile('$fileNameWithoutExtension.sba', sba.length, sba));
    }
  }

  if (!context.mounted) return;
  if (selectedFiles.length == 1) {
    await FileManager.exportFile(
      files.single.name,
      files.single.content,
      context: context,
    );
  } else if (selectedFiles.length > 1) {
    final archive = Archive();
    for (final archiveFile in files) {
      archive.addFile(archiveFile);
    }
    await FileManager.exportFile(
      '${files.first.name}.zip',
      Uint8List.fromList(ZipEncoder().encode(archive)),
      context: context,
    );
  }
}
