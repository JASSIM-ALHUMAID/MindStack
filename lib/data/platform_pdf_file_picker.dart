import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/pdf_file_picker.dart';

/// [PdfFilePicker] backed by the file_picker package
final class PlatformPdfFilePicker implements PdfFilePicker {
  const PlatformPdfFilePicker();

  @override
  Future<PickedPdf?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    return file == null ? null : _PlatformPickedPdf(file);
  }
}

final class _PlatformPickedPdf implements PickedPdf {
  const _PlatformPickedPdf(this._file);

  final PlatformFile _file;

  @override
  Future<int?> length() => _file.length();

  @override
  Future<String> localPath() async {
    final path = _file.path;
    if (path != null) return path;
    // Android may hand over a content:// link, but PDFium needs a file
    final directory = await getTemporaryDirectory();
    final copy = File(
      '${directory.path}${Platform.pathSeparator}mindstack_import.pdf',
    );
    await copy.writeAsBytes(await _file.readAsBytes(), flush: true);
    return copy.path;
  }
}
